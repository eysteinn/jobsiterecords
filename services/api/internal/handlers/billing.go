package handlers

import (
	"errors"
	"net/http"

	"github.com/eysteinn/jobsiterecords/services/api/internal/billing"
	"github.com/eysteinn/jobsiterecords/services/api/internal/httpx"
	"github.com/eysteinn/jobsiterecords/services/api/internal/middleware"
)

type BillingHandler struct {
	billing *billing.Service
}

func NewBillingHandler(svc *billing.Service) *BillingHandler {
	return &BillingHandler{billing: svc}
}

func (h *BillingHandler) GetWorkspaceBilling(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")

	info, err := h.billing.GetWorkspaceBilling(r.Context(), userID, workspaceID)
	if err != nil {
		writeBillingError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, info)
}

type portalRequest struct {
	TargetPlanSKU string `json:"target_plan_sku"`
}

func (h *BillingHandler) OpenPortal(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")

	var req portalRequest
	_ = httpx.DecodeJSON(r, &req)

	if req.TargetPlanSKU != "" {
		if err := h.billing.CanDowngradeTo(r.Context(), workspaceID, req.TargetPlanSKU); err != nil {
			writeBillingError(w, err)
			return
		}
	}

	url, err := h.billing.OpenPortal(r.Context(), userID, workspaceID)
	if err != nil {
		writeBillingError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]string{"url": url})
}

func (h *BillingHandler) Webhook(w http.ResponseWriter, r *http.Request) {
	h.billing.HandleWebhook(w, r)
}

func writeBillingError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, billing.ErrNotOwner):
		httpx.Error(w, http.StatusForbidden, "forbidden", "Owner access required", nil)
	case errors.Is(err, billing.ErrNoSubscription):
		httpx.Error(w, http.StatusBadRequest, "no_subscription", "No Paddle subscription on this workspace yet", nil)
	case errors.Is(err, billing.ErrTooManyMembers):
		httpx.Error(w, http.StatusConflict, "too_many_members", "Remove members before downgrading", nil)
	case errors.Is(err, billing.ErrBillingNotConfigured):
		httpx.Error(w, http.StatusServiceUnavailable, "billing_unavailable", "Billing is not configured", nil)
	case err.Error() == "not a workspace member":
		httpx.Error(w, http.StatusForbidden, "forbidden", err.Error(), nil)
	default:
		httpx.Error(w, http.StatusInternalServerError, "internal", "Billing request failed", nil)
	}
}
