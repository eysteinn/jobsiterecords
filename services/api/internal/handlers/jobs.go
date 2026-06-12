package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/eysteinn/jobsiterecords/services/api/internal/billing"
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
	if bundle.MediaFiles == nil {
		bundle.MediaFiles = []jobs.MediaFile{}
	}
	if bundle.Tags == nil {
		bundle.Tags = []jobs.Tag{}
	}
	if bundle.ItemTags == nil {
		bundle.ItemTags = []jobs.ItemTag{}
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

type upsertItemRequest struct {
	jobs.Item
	TagIDs *[]string `json:"tag_ids,omitempty"`
}

func (h *JobsHandler) ListWorkspaceTags(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")
	tags, err := h.jobs.ListWorkspaceTags(r.Context(), userID, workspaceID)
	if err != nil {
		writeJobsError(w, err)
		return
	}
	if tags == nil {
		tags = []jobs.Tag{}
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"tags": tags})
}

func (h *JobsHandler) UpsertTag(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")
	tagID := r.PathValue("tagID")
	var in jobs.Tag
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	in.ID = tagID
	out, err := h.jobs.UpsertTag(r.Context(), userID, workspaceID, in)
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
	var in upsertItemRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	in.Item.ID = itemID
	in.Item.JobID = jobID
	out, err := h.jobs.UpsertItem(r.Context(), userID, jobID, in.Item, in.TagIDs)
	if err != nil {
		writeJobsError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, out)
}

func (h *JobsHandler) GetJobCursor(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	jobID := r.PathValue("jobID")
	cursor, err := h.jobs.GetJobCursor(r.Context(), userID, jobID)
	if err != nil {
		writeJobsError(w, err)
		return
	}
	writeCursorResponse(w, r, cursor)
}

func (h *JobsHandler) GetWorkspaceCursor(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	workspaceID := r.PathValue("workspaceID")
	cursor, err := h.jobs.GetWorkspaceCursor(r.Context(), userID, workspaceID)
	if err != nil {
		writeJobsError(w, err)
		return
	}
	writeCursorResponse(w, r, cursor)
}

func writeCursorResponse(w http.ResponseWriter, r *http.Request, cursor time.Time) {
	tag := cursor.UTC().Format(time.RFC3339Nano)
	etag := `"` + tag + `"`
	if match := r.Header.Get("If-None-Match"); match == etag || match == tag {
		w.WriteHeader(http.StatusNotModified)
		return
	}
	w.Header().Set("ETag", etag)
	httpx.JSON(w, http.StatusOK, map[string]string{"cursor": tag})
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
	switch {
	case errors.Is(err, billing.ErrTrialJobLimit):
		httpx.Error(w, http.StatusForbidden, "trial_limit", "Trial allows up to 3 jobs. Upgrade to add more.", nil)
	case errors.Is(err, billing.ErrTrialItemLimit):
		httpx.Error(w, http.StatusForbidden, "trial_limit", "Trial allows up to 50 items per job. Upgrade to add more.", nil)
	case err.Error() == "not a workspace member", err.Error() == "no access":
		httpx.Error(w, http.StatusForbidden, "forbidden", err.Error(), nil)
	case err.Error() == "not assigned to job":
		httpx.Error(w, http.StatusForbidden, "read_only", "Job is read-only", nil)
	case err.Error() == "read_only", err.Error() == "subscription_lapsed":
		httpx.Error(w, http.StatusForbidden, "read_only", "Job is read-only", nil)
	default:
		httpx.Error(w, http.StatusBadRequest, "bad_request", err.Error(), nil)
	}
}
