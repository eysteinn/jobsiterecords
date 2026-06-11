package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/riverqueue/river"

	"github.com/eysteinn/jobsiterecords/services/api/internal/httpx"
	"github.com/eysteinn/jobsiterecords/services/api/internal/middleware"
	"github.com/eysteinn/jobsiterecords/services/api/internal/reports"
	"github.com/eysteinn/jobsiterecords/services/api/internal/storage"
)

type ReportsHandler struct {
	svc         *reports.Service
	riverClient *river.Client[pgx.Tx]
	store       *storage.Client
}

func NewReportsHandler(svc *reports.Service, riverClient *river.Client[pgx.Tx], store *storage.Client) *ReportsHandler {
	return &ReportsHandler{svc: svc, riverClient: riverClient, store: store}
}

type createReportRequest struct {
	JobID         string  `json:"job_id"`
	Title         string  `json:"title"`
	DateFrom      *string `json:"date_from"` // YYYY-MM-DD
	DateTo        *string `json:"date_to"`
	IncludePhotos *bool   `json:"include_photos"`
	IncludeNotes  *bool   `json:"include_notes"`
	IncludeVoice  *bool   `json:"include_voice"`
	IncludeFiles  *bool   `json:"include_files"`
}

func (h *ReportsHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")

	var req createReportRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpx.Error(w, http.StatusBadRequest, "bad_request", "invalid JSON", nil)
		return
	}
	if req.JobID == "" || req.Title == "" {
		httpx.Error(w, http.StatusBadRequest, "bad_request", "job_id and title are required", nil)
		return
	}

	in := reports.CreateInput{
		WorkspaceID:     workspaceID,
		JobID:           req.JobID,
		CreatedByUserID: userID,
		Title:           req.Title,
		IncludePhotos:   boolOrDefault(req.IncludePhotos, true),
		IncludeNotes:    boolOrDefault(req.IncludeNotes, true),
		IncludeVoice:    boolOrDefault(req.IncludeVoice, true),
		IncludeFiles:    boolOrDefault(req.IncludeFiles, true),
	}

	if req.DateFrom != nil {
		t, err := time.Parse("2006-01-02", *req.DateFrom)
		if err != nil {
			httpx.Error(w, http.StatusBadRequest, "bad_request", "date_from must be YYYY-MM-DD", nil)
			return
		}
		in.DateFrom = &t
	}
	if req.DateTo != nil {
		t, err := time.Parse("2006-01-02", *req.DateTo)
		if err != nil {
			httpx.Error(w, http.StatusBadRequest, "bad_request", "date_to must be YYYY-MM-DD", nil)
			return
		}
		in.DateTo = &t
	}

	report, err := h.svc.Create(r.Context(), h.riverClient, in)
	if err != nil {
		writeReportsError(w, err)
		return
	}

	httpx.JSON(w, http.StatusAccepted, map[string]any{"report": reportJSON(report)})
}

func (h *ReportsHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")

	list, err := h.svc.List(r.Context(), userID, workspaceID)
	if err != nil {
		writeReportsError(w, err)
		return
	}

	out := make([]map[string]any, len(list))
	for i, rep := range list {
		out[i] = reportJSON(rep)
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"reports": out})
}

func (h *ReportsHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	reportID := r.PathValue("reportID")

	report, err := h.svc.Get(r.Context(), userID, reportID)
	if err != nil {
		writeReportsError(w, err)
		return
	}

	httpx.JSON(w, http.StatusOK, map[string]any{"report": reportJSON(report)})
}

func (h *ReportsHandler) Download(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	reportID := r.PathValue("reportID")

	report, err := h.svc.Get(r.Context(), userID, reportID)
	if err != nil {
		writeReportsError(w, err)
		return
	}
	if report.Status != "ready" || report.StorageKey == nil {
		httpx.Error(w, http.StatusConflict, "not_ready", "report is not ready", nil)
		return
	}

	url, err := h.store.PresignedGet(r.Context(), *report.StorageKey, 15*time.Minute)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "storage_error", "could not generate download URL", nil)
		return
	}

	http.Redirect(w, r, url, http.StatusFound)
}

func reportJSON(r reports.Report) map[string]any {
	out := map[string]any{
		"id":             r.ID,
		"workspace_id":   r.WorkspaceID,
		"job_id":         r.JobID,
		"created_by":     r.CreatedByUserID,
		"title":          r.Title,
		"include_photos": r.IncludePhotos,
		"include_notes":  r.IncludeNotes,
		"include_voice":  r.IncludeVoice,
		"include_files":  r.IncludeFiles,
		"status":         r.Status,
		"created_at":     r.CreatedAt,
		"updated_at":     r.UpdatedAt,
	}
	if r.DateFrom != nil {
		out["date_from"] = r.DateFrom.Format("2006-01-02")
	}
	if r.DateTo != nil {
		out["date_to"] = r.DateTo.Format("2006-01-02")
	}
	if r.StorageKey != nil {
		out["storage_key"] = *r.StorageKey
	}
	if r.SizeBytes != nil {
		out["size_bytes"] = *r.SizeBytes
	}
	if r.PageCount != nil {
		out["page_count"] = *r.PageCount
	}
	if r.ErrorMsg != nil {
		out["error_msg"] = *r.ErrorMsg
	}
	return out
}

func writeReportsError(w http.ResponseWriter, err error) {
	switch err.Error() {
	case "not a workspace member", "job not in workspace":
		httpx.Error(w, http.StatusForbidden, "forbidden", err.Error(), nil)
	case "job not found":
		httpx.Error(w, http.StatusNotFound, "not_found", err.Error(), nil)
	default:
		httpx.Error(w, http.StatusInternalServerError, "internal_error", err.Error(), nil)
	}
}

func boolOrDefault(b *bool, def bool) bool {
	if b == nil {
		return def
	}
	return *b
}
