package billing

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

type portalSessionResponse struct {
	Data struct {
		URLs struct {
			General struct {
				Overview string `json:"overview"`
			} `json:"general"`
		} `json:"urls"`
	} `json:"data"`
}

// CreatePortalSession returns a hosted Paddle customer portal URL.
func (s *Service) CreatePortalSession(ctx context.Context, customerID, subscriptionID string) (string, error) {
	if s.apiKey == "" {
		return "", fmt.Errorf("paddle api key not configured")
	}
	customerID = strings.TrimSpace(customerID)
	subscriptionID = strings.TrimSpace(subscriptionID)
	if customerID == "" {
		return "", fmt.Errorf("missing paddle customer id")
	}

	body := map[string]any{}
	if subscriptionID != "" {
		body["subscription_ids"] = []string{subscriptionID}
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return "", err
	}

	url := strings.TrimRight(s.apiBaseURL, "/") + "/customers/" + customerID + "/portal-sessions"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(raw))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+s.apiKey)
	req.Header.Set("Content-Type", "application/json")

	res, err := s.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()

	respBody, err := io.ReadAll(res.Body)
	if err != nil {
		return "", err
	}
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return "", fmt.Errorf("paddle portal session: %s", strings.TrimSpace(string(respBody)))
	}

	var parsed portalSessionResponse
	if err := json.Unmarshal(respBody, &parsed); err != nil {
		return "", err
	}
	portalURL := strings.TrimSpace(parsed.Data.URLs.General.Overview)
	if portalURL == "" {
		return "", fmt.Errorf("paddle portal session missing overview url")
	}
	return portalURL, nil
}
