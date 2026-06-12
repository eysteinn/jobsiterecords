package handlers

import (
	"bytes"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/disintegration/imaging"

	"github.com/eysteinn/jobsiterecords/services/api/internal/httpx"
	"github.com/eysteinn/jobsiterecords/services/api/internal/jobs"
	"github.com/eysteinn/jobsiterecords/services/api/internal/middleware"
	"github.com/eysteinn/jobsiterecords/services/api/internal/storage"
)

type MediaHandler struct {
	jobs    *jobs.Service
	storage *storage.Client
}

func NewMediaHandler(jobsSvc *jobs.Service, store *storage.Client) *MediaHandler {
	return &MediaHandler{jobs: jobsSvc, storage: store}
}

type createMediaBody struct {
	ID               string  `json:"id"`
	Role             string  `json:"role"`
	MimeType         string  `json:"mime_type"`
	SizeBytes        int64   `json:"size_bytes"`
	OriginalFilename *string `json:"original_filename"`
	Width            *int    `json:"width"`
	Height           *int    `json:"height"`
	DurationMs       *int    `json:"duration_ms"`
}

func (h *MediaHandler) CreateMedia(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	itemID := r.PathValue("itemID")
	var body createMediaBody
	if err := httpx.DecodeJSON(r, &body); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	out, err := h.jobs.CreateMediaUpload(r.Context(), userID, itemID, jobs.CreateMediaInput{
		ID:               body.ID,
		Role:             body.Role,
		MimeType:         body.MimeType,
		SizeBytes:        body.SizeBytes,
		OriginalFilename: body.OriginalFilename,
		Width:            body.Width,
		Height:           body.Height,
		DurationMs:       body.DurationMs,
	}, func(key, mime string) (string, error) {
		return h.storage.PresignedPut(r.Context(), key, mime, 15*time.Minute)
	})
	if err != nil {
		writeMediaError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, out)
}

type completeMediaBody struct {
	ETag      string `json:"etag"`
	SizeBytes int64  `json:"size_bytes"`
}

func (h *MediaHandler) CompleteMedia(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	mediaID := r.PathValue("mediaID")
	var body completeMediaBody
	if err := httpx.DecodeJSON(r, &body); err != nil {
		httpx.Error(w, http.StatusBadRequest, "invalid_request", "Invalid JSON body", nil)
		return
	}
	mf, err := h.jobs.CompleteMediaUpload(r.Context(), userID, mediaID, jobs.CompleteMediaInput{
		ETag:      body.ETag,
		SizeBytes: body.SizeBytes,
	}, func(key string) (int64, string, []byte, error) {
		meta, err := h.storage.Head(r.Context(), key)
		if err != nil {
			return 0, "", nil, err
		}
		raw, err := h.storage.Get(r.Context(), key)
		if err != nil {
			return 0, "", nil, err
		}
		head := raw
		if len(head) > 512 {
			head = head[:512]
		}
		return meta.Size, meta.ETag, head, nil
	})
	if err != nil {
		writeMediaError(w, err)
		return
	}
	httpx.JSON(w, http.StatusOK, map[string]any{"media_file": mf})
}

func (h *MediaHandler) DeleteMedia(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	mediaID := r.PathValue("mediaID")
	if err := h.jobs.DeleteMedia(r.Context(), userID, mediaID); err != nil {
		writeMediaError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *MediaHandler) DownloadMedia(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	mediaID := r.PathValue("mediaID")
	mf, err := h.jobs.GetMediaForDownload(r.Context(), userID, mediaID)
	if err != nil {
		writeMediaError(w, err)
		return
	}
	url, err := h.storage.PresignedGet(r.Context(), mf.StorageKey, 5*time.Minute)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "storage_error", "Could not create download URL", nil)
		return
	}
	if r.URL.Query().Get("inline") == "1" {
		w.Header().Set("Content-Type", mf.MimeType)
	}
	http.Redirect(w, r, url, http.StatusFound)
}

func (h *MediaHandler) ItemThumb(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserID(r.Context())
	itemID := r.PathValue("itemID")
	width := 512
	if raw := r.URL.Query().Get("w"); raw != "" {
		if n, err := strconv.Atoi(raw); err == nil && n > 0 && n <= 2048 {
			width = n
		}
	}

	mf, err := h.jobs.GetItemPrimaryMedia(r.Context(), userID, itemID)
	if err != nil {
		writeMediaError(w, err)
		return
	}
	if !strings.HasPrefix(mf.MimeType, "image/") {
		httpx.Error(w, http.StatusBadRequest, "not_image", "Item has no image thumbnail", nil)
		return
	}

	cacheKey := mf.StorageKey + "/thumb-" + strconv.Itoa(width) + ".jpg"
	if cached, err := h.storage.Head(r.Context(), cacheKey); err == nil && cached.Size > 0 {
		url, err := h.storage.PresignedGet(r.Context(), cacheKey, 5*time.Minute)
		if err == nil {
			http.Redirect(w, r, url, http.StatusFound)
			return
		}
	}

	raw, err := h.storage.Get(r.Context(), mf.StorageKey)
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "storage_error", "Could not read image", nil)
		return
	}
	img, _, err := image.Decode(bytes.NewReader(raw))
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, "decode_error", "Could not decode image", nil)
		return
	}
	thumb := imaging.Fit(img, width, width, imaging.Lanczos)
	var buf bytes.Buffer
	if err := imaging.Encode(&buf, thumb, imaging.JPEG, imaging.JPEGQuality(82)); err != nil {
		httpx.Error(w, http.StatusInternalServerError, "encode_error", "Could not encode thumbnail", nil)
		return
	}
	data := buf.Bytes()
	if err := h.storage.Put(r.Context(), cacheKey, "image/jpeg", bytes.NewReader(data), int64(len(data))); err == nil {
		if url, err := h.storage.PresignedGet(r.Context(), cacheKey, 5*time.Minute); err == nil {
			http.Redirect(w, r, url, http.StatusFound)
			return
		}
	}

	w.Header().Set("Content-Type", "image/jpeg")
	w.Header().Set("Cache-Control", "public, max-age=3600")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(data)
}

func writeMediaError(w http.ResponseWriter, err error) {
	switch err.Error() {
	case "not a workspace member", "no access", "not assigned to job":
		httpx.Error(w, http.StatusForbidden, "forbidden", err.Error(), nil)
	case "read_only", "subscription_lapsed":
		httpx.Error(w, http.StatusForbidden, "read_only", "Job is read-only", nil)
	case "missing required media fields":
		httpx.Error(w, http.StatusBadRequest, "invalid_request", err.Error(), nil)
	case "payload too large":
		httpx.Error(w, http.StatusRequestEntityTooLarge, "payload_too_large", "Blob exceeds 50 MB limit", nil)
	case "unsupported media", "voice too long", "mime mismatch", "object not found":
		httpx.Error(w, http.StatusUnsupportedMediaType, "unsupported_media", err.Error(), nil)
	case "not available":
		httpx.Error(w, http.StatusNotFound, "not_found", "Media not available", nil)
	default:
		if err.Error() == "no rows in result set" || strings.Contains(err.Error(), "no rows") {
			httpx.Error(w, http.StatusNotFound, "not_found", "Not found", nil)
			return
		}
		httpx.Error(w, http.StatusBadRequest, "bad_request", err.Error(), nil)
	}
}
