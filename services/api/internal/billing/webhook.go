package billing

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5"
)

type webhookEnvelope struct {
	EventID   string          `json:"event_id"`
	EventType string          `json:"event_type"`
	Data      json.RawMessage `json:"data"`
}

type subscriptionData struct {
	ID         string         `json:"id"`
	Status     string         `json:"status"`
	CustomerID string         `json:"customer_id"`
	CustomData map[string]any `json:"custom_data"`
	Items      []struct {
		PriceID string `json:"price_id"`
		Price   struct {
			ID string `json:"id"`
		} `json:"price"`
	} `json:"items"`
}

func (s *Service) HandleWebhook(w http.ResponseWriter, r *http.Request) {
	if s.webhookVerify == nil {
		http.Error(w, "billing not configured", http.StatusServiceUnavailable)
		return
	}
	ok, err := s.webhookVerify.Verify(r)
	if err != nil || !ok {
		http.Error(w, "invalid signature", http.StatusBadRequest)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}

	var env webhookEnvelope
	if err := json.Unmarshal(body, &env); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	if env.EventID == "" {
		http.Error(w, "missing event_id", http.StatusBadRequest)
		return
	}

	ctx := r.Context()
	processed, err := s.recordEvent(ctx, env.EventID, env.EventType, body)
	if err != nil {
		http.Error(w, "storage error", http.StatusInternalServerError)
		return
	}
	if !processed {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"duplicate"}`))
		return
	}

	workspaceID, err := s.applyEvent(ctx, env.EventType, env.Data)
	if err != nil {
		http.Error(w, "processing error", http.StatusInternalServerError)
		return
	}

	if workspaceID != "" {
		_, _ = s.pool.Exec(ctx, `
			UPDATE paddle_events SET workspace_id = $2 WHERE paddle_event_id = $1
		`, env.EventID, workspaceID)
	}

	if err := s.markEventProcessed(ctx, env.EventID); err != nil {
		http.Error(w, "storage error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}

func (s *Service) recordEvent(ctx context.Context, eventID, eventType string, payload []byte) (bool, error) {
	tag, err := s.pool.Exec(ctx, `
		INSERT INTO paddle_events (paddle_event_id, event_type, payload)
		VALUES ($1, $2, $3::jsonb)
		ON CONFLICT (paddle_event_id) DO NOTHING
	`, eventID, eventType, string(payload))
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

func (s *Service) markEventProcessed(ctx context.Context, eventID string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE paddle_events
		SET processed_at = now()
		WHERE paddle_event_id = $1
	`, eventID)
	return err
}

func (s *Service) applyEvent(ctx context.Context, eventType string, raw json.RawMessage) (string, error) {
	switch eventType {
	case "subscription.created",
		"subscription.activated",
		"subscription.updated",
		"subscription.resumed":
		var data subscriptionData
		if err := json.Unmarshal(raw, &data); err != nil {
			return "", err
		}
		return s.applyActiveSubscription(ctx, data)
	case "subscription.past_due":
		var data subscriptionData
		if err := json.Unmarshal(raw, &data); err != nil {
			return "", err
		}
		return s.applySubscriptionStatus(ctx, data, "past_due", true)
	case "subscription.canceled":
		var data subscriptionData
		if err := json.Unmarshal(raw, &data); err != nil {
			return "", err
		}
		return s.applySubscriptionStatus(ctx, data, "canceled", false)
	default:
		return "", nil
	}
}

func (s *Service) applyActiveSubscription(ctx context.Context, data subscriptionData) (string, error) {
	workspaceID, err := s.resolveWorkspaceID(ctx, data)
	if err != nil {
		return "", err
	}
	if workspaceID == "" {
		return "", fmt.Errorf("workspace not found for subscription %s", data.ID)
	}

	priceID := subscriptionPriceID(data)
	plan, ok := PlanByPriceID(s.catalog, priceID)
	if !ok {
		return "", fmt.Errorf("unknown paddle price id %q", priceID)
	}

	status := strings.TrimSpace(data.Status)
	if status == "" {
		status = "active"
	}

	_, err = s.pool.Exec(ctx, `
		UPDATE workspaces
		SET plan_sku = $2,
		    member_limit = $3,
		    paddle_customer_id = $4,
		    paddle_subscription_id = $5,
		    subscription_status = $6,
		    subscription_past_due_at = NULL
		WHERE id = $1
	`, workspaceID, plan.SKU, plan.MemberLimit, nullIfEmpty(data.CustomerID), nullIfEmpty(data.ID), status)
	return workspaceID, err
}

func (s *Service) applySubscriptionStatus(ctx context.Context, data subscriptionData, status string, setPastDueAt bool) (string, error) {
	workspaceID, err := s.resolveWorkspaceID(ctx, data)
	if err != nil {
		return "", err
	}
	if workspaceID == "" {
		workspaceID, err = s.workspaceIDBySubscription(ctx, data.ID)
		if err != nil {
			return "", err
		}
	}
	if workspaceID == "" {
		return "", fmt.Errorf("workspace not found for subscription %s", data.ID)
	}

	if setPastDueAt {
		_, err = s.pool.Exec(ctx, `
			UPDATE workspaces
			SET subscription_status = $2,
			    subscription_past_due_at = COALESCE(subscription_past_due_at, now()),
			    paddle_subscription_id = COALESCE(paddle_subscription_id, $3),
			    paddle_customer_id = COALESCE(paddle_customer_id, $4)
			WHERE id = $1
		`, workspaceID, status, nullIfEmpty(data.ID), nullIfEmpty(data.CustomerID))
		return workspaceID, err
	}

	_, err = s.pool.Exec(ctx, `
		UPDATE workspaces
		SET subscription_status = $2,
		    paddle_subscription_id = COALESCE(paddle_subscription_id, $3),
		    paddle_customer_id = COALESCE(paddle_customer_id, $4)
		WHERE id = $1
	`, workspaceID, status, nullIfEmpty(data.ID), nullIfEmpty(data.CustomerID))
	return workspaceID, err
}

func (s *Service) resolveWorkspaceID(ctx context.Context, data subscriptionData) (string, error) {
	if data.CustomData != nil {
		if raw, ok := data.CustomData["workspace_id"]; ok {
			switch v := raw.(type) {
			case string:
				return strings.TrimSpace(v), nil
			case float64:
				return fmt.Sprintf("%.0f", v), nil
			}
		}
	}
	if data.ID != "" {
		return s.workspaceIDBySubscription(ctx, data.ID)
	}
	return "", nil
}

func (s *Service) workspaceIDBySubscription(ctx context.Context, subscriptionID string) (string, error) {
	var workspaceID string
	err := s.pool.QueryRow(ctx, `
		SELECT id::text FROM workspaces WHERE paddle_subscription_id = $1
	`, subscriptionID).Scan(&workspaceID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", nil
		}
		return "", err
	}
	return workspaceID, nil
}

func subscriptionPriceID(data subscriptionData) string {
	if len(data.Items) == 0 {
		return ""
	}
	item := data.Items[0]
	if item.PriceID != "" {
		return item.PriceID
	}
	return item.Price.ID
}

func nullIfEmpty(v string) any {
	if strings.TrimSpace(v) == "" {
		return nil
	}
	return v
}
