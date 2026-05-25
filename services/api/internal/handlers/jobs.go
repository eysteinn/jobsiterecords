package handlers

import (
	"net/http"
	"time"

	"github.com/eysteinn/jobsiterecords/services/api/internal/httpx"
	"github.com/eysteinn/jobsiterecords/services/api/internal/jobs"
	"github.com/eysteinn/jobsiterecords/services/api/internal/middleware"
)

type JobsHandler struct {
	jobs *jobs.Service
}

func NewJobsHandler(svc *jobs.Service) *JobsHandler {
	return &JobsHandler{jobs: svc}
}

func (h *JobsHandler) ListWorkspaceJobs(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")
	items, err := h.jobs.ListWorkspaceJobs(r.Context(), userID, workspaceID)
	if err != nil {
		writeJobsError(w, err)
		return
	}
	if items == nil {
		items = []jobs.Job{}
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"jobs": items})
}

func (h *JobsHandler) GetJob(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	jobID := r.PathValue("jobID")
	var since *time.Time
	if raw := r.URL.Query().Get("since"); raw != "" {
		if t, err := time.Parse(time.RFC3339Nano, raw); err == nil {
			since = &t
		}
	}
	bundle, err := h.jobs.GetJobBundle(r.Context(), userID, jobID, since)
	if err != nil {
		writeJobsError(w, err)
		return
	}
	if bundle.Items == nil {
		bundle.Items = []jobs.Item{}
	}
	httpx.JSON(w, http.StatusOK, bundle)
}

func (h *JobsHandler) UpsertJob(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	jobID := r.PathValue("jobID")
	var in jobs.Job
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	in.ID = jobID
	out, err := h.jobs.UpsertJob(r.Context(), userID, in)
	if err != nil {
		writeJobsError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *JobsHandler) UpsertItem(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	jobID := r.PathValue("jobID")
	itemID := r.PathValue("itemID")
	var in jobs.Item
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	in.ID = itemID
	in.JobID = jobID
	out, err := h.jobs.UpsertItem(r.Context(), userID, jobID, in)
	if err != nil {
		writeJobsError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *JobsHandler) AssignedJobIDs(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")
	ids, err := h.jobs.ListAssignedJobIDs(r.Context(), userID, workspaceID)
	if err != nil {
		writeJobsError(w, err)
		return
	}
	if ids == nil {
		ids = []string{}
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"job_ids": ids})
}

func writeJobsError(w http.ResponseWriter, err error) {
	switch err.Error() {
	case "not a workspace member", "no access", "not assigned to job":
		httpx.Error(w, http.StatusForbidden, "forbidden", err.Error(), nil)
	case "read_only":
		httpx.Error(w, http.StatusForbidden, "read_only", "Job is read-only", nil)
	default:
		httpx.Error(w, http.StatusBadRequest, "bad_request", err.Error(), nil)
	}
}
