package jobs

import (
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"html/template"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"mime/multipart"
	"net/http"
	"sort"
	"strings"
	"time"

	// embed the HTML template alongside this file
	_ "embed"

	"github.com/disintegration/imaging"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"

	"github.com/eysteinn/jobsiterecords/services/api/internal/reports"
	"github.com/eysteinn/jobsiterecords/services/api/internal/storage"
)

//go:embed pdf_report.html
var reportTemplate string

// PDFReportWorker renders a PDF for a queued report, uploads it to S3, and marks it ready.
type PDFReportWorker struct {
	river.WorkerDefaults[reports.PDFReportArgs]
	Pool         *pgxpool.Pool
	Reports      *reports.Service
	Store        *storage.Client
	GotenbergURL string
}

func (w *PDFReportWorker) Work(ctx context.Context, job *river.Job[reports.PDFReportArgs]) error {
	report, err := w.Reports.LoadForWorker(ctx, job.Args.ReportID)
	if err != nil {
		return fmt.Errorf("load report: %w", err)
	}

	if err := w.Reports.SetRendering(ctx, report.ID); err != nil {
		return fmt.Errorf("set rendering: %w", err)
	}

	data, err := w.buildTemplateData(ctx, report)
	if err != nil {
		_ = w.Reports.SetFailed(ctx, report.ID, err.Error())
		return fmt.Errorf("build template data: %w", err)
	}

	html, err := renderHTML(data)
	if err != nil {
		_ = w.Reports.SetFailed(ctx, report.ID, err.Error())
		return fmt.Errorf("render html: %w", err)
	}

	pdfBytes, err := w.callGotenberg(ctx, html)
	if err != nil {
		_ = w.Reports.SetFailed(ctx, report.ID, err.Error())
		return fmt.Errorf("gotenberg: %w", err)
	}

	storageKey := fmt.Sprintf("reports/%s/report.pdf", report.ID)
	if err := w.Store.Put(ctx, storageKey, "application/pdf", bytes.NewReader(pdfBytes), int64(len(pdfBytes))); err != nil {
		_ = w.Reports.SetFailed(ctx, report.ID, err.Error())
		return fmt.Errorf("upload pdf: %w", err)
	}

	return w.Reports.SetReady(ctx, report.ID, storageKey, int64(len(pdfBytes)), 0)
}

// — template data types —

type templateData struct {
	Title         string
	WorkspaceName string
	Job           templateJob
	DateRange     string
	TotalItems    int
	GeneratedAt   string
	Groups        []templateGroup
}

type templateJob struct {
	Name        string
	ClientName  string
	Address     string
	JobNumber   string
	StatusLabel string
}

type templateGroup struct {
	Date  string
	Items []templateItem
}

type templateItem struct {
	Kind      string
	KindLabel string
	CSSClass  string
	TimeStr   string
	AuthorName string
	Caption   string
	Body      string
	Tags      []string
	PhotoSrc  template.URL // data URI for inline images
}

// — DB row types used only during data loading —

type dbItem struct {
	ID              string
	Kind            string
	Caption         *string
	Body            *string
	CapturedAt      time.Time
	CreatedByUserID string
}

type dbMedia struct {
	ItemID     string
	Role       string
	StorageKey string
	MimeType   string
	DurationMs *int
	Filename   *string
}

func (w *PDFReportWorker) buildTemplateData(ctx context.Context, report reports.Report) (templateData, error) {
	// Load workspace name
	var workspaceName string
	if err := w.Pool.QueryRow(ctx, `SELECT name FROM workspaces WHERE id = $1`, report.WorkspaceID).Scan(&workspaceName); err != nil {
		return templateData{}, fmt.Errorf("workspace: %w", err)
	}

	// Load job
	var job struct {
		Name       string
		ClientName *string
		Address    *string
		JobNumber  *string
		Status     string
	}
	err := w.Pool.QueryRow(ctx, `
		SELECT name, client_name, address, job_number, status
		FROM jobs WHERE id = $1
	`, report.JobID).Scan(&job.Name, &job.ClientName, &job.Address, &job.JobNumber, &job.Status)
	if err != nil {
		return templateData{}, fmt.Errorf("job: %w", err)
	}

	// Load items (ordered oldest-first for date grouping)
	itemRows, err := w.Pool.Query(ctx, `
		SELECT id, kind, caption, body, captured_at, created_by_user_id
		FROM items
		WHERE job_id = $1 AND deleted_at IS NULL
		ORDER BY captured_at ASC
	`, report.JobID)
	if err != nil {
		return templateData{}, fmt.Errorf("items: %w", err)
	}
	defer itemRows.Close()

	var items []dbItem
	userIDs := map[string]struct{}{}
	for itemRows.Next() {
		var it dbItem
		if err := itemRows.Scan(&it.ID, &it.Kind, &it.Caption, &it.Body, &it.CapturedAt, &it.CreatedByUserID); err != nil {
			return templateData{}, err
		}
		items = append(items, it)
		userIDs[it.CreatedByUserID] = struct{}{}
	}
	if err := itemRows.Err(); err != nil {
		return templateData{}, err
	}

	// Filter by date range and include flags
	items = filterItems(items, report)

	// Load media for included items
	if len(items) == 0 {
		return w.assembleData(workspaceName, job.Name, derefStr(job.ClientName), derefStr(job.Address), derefStr(job.JobNumber), job.Status, report, nil, nil, nil, nil), nil
	}

	itemIDs := make([]string, len(items))
	for i, it := range items {
		itemIDs[i] = it.ID
	}

	mediaRows, err := w.Pool.Query(ctx, `
		SELECT item_id, role, storage_key, mime_type, duration_ms, original_filename
		FROM media_files
		WHERE item_id = ANY($1) AND deleted_at IS NULL
		  AND status = 'uploaded'
		  AND role IN ('primary_photo', 'annotated_render', 'voice_note', 'attachment', 'file')
	`, itemIDs)
	if err != nil {
		return templateData{}, fmt.Errorf("media: %w", err)
	}
	defer mediaRows.Close()

	mediaByItem := map[string][]dbMedia{}
	for mediaRows.Next() {
		var m dbMedia
		if err := mediaRows.Scan(&m.ItemID, &m.Role, &m.StorageKey, &m.MimeType, &m.DurationMs, &m.Filename); err != nil {
			return templateData{}, err
		}
		mediaByItem[m.ItemID] = append(mediaByItem[m.ItemID], m)
	}
	if err := mediaRows.Err(); err != nil {
		return templateData{}, err
	}

	// Load tags per item
	tagRows, err := w.Pool.Query(ctx, `
		SELECT it.item_id, t.name
		FROM item_tags it
		JOIN tags t ON t.id = it.tag_id
		WHERE it.item_id = ANY($1)
		  AND it.deleted_at IS NULL
		  AND t.deleted_at IS NULL
		ORDER BY t.name
	`, itemIDs)
	if err != nil {
		return templateData{}, fmt.Errorf("tags: %w", err)
	}
	defer tagRows.Close()

	tagsByItem := map[string][]string{}
	for tagRows.Next() {
		var itemID, tagName string
		if err := tagRows.Scan(&itemID, &tagName); err != nil {
			return templateData{}, err
		}
		tagsByItem[itemID] = append(tagsByItem[itemID], tagName)
	}
	if err := tagRows.Err(); err != nil {
		return templateData{}, err
	}

	// Load user names
	for _, it := range items {
		userIDs[it.CreatedByUserID] = struct{}{}
	}
	ids := make([]string, 0, len(userIDs))
	for id := range userIDs {
		ids = append(ids, id)
	}
	nameRows, err := w.Pool.Query(ctx, `SELECT id, name FROM users WHERE id = ANY($1)`, ids)
	if err != nil {
		return templateData{}, fmt.Errorf("users: %w", err)
	}
	defer nameRows.Close()
	userNames := map[string]string{}
	for nameRows.Next() {
		var uid, name string
		if err := nameRows.Scan(&uid, &name); err != nil {
			return templateData{}, err
		}
		userNames[uid] = name
	}
	if err := nameRows.Err(); err != nil {
		return templateData{}, err
	}

	return w.assembleData(workspaceName, job.Name, derefStr(job.ClientName), derefStr(job.Address), derefStr(job.JobNumber), job.Status, report, items, mediaByItem, tagsByItem, userNames), nil
}

func (w *PDFReportWorker) assembleData(
	workspaceName, jobName, clientName, address, jobNumber, status string,
	report reports.Report,
	items []dbItem,
	mediaByItem map[string][]dbMedia,
	tagsByItem map[string][]string,
	userNames map[string]string,
) templateData {
	dateRange := ""
	if report.DateFrom != nil && report.DateTo != nil {
		dateRange = report.DateFrom.Format("Jan 2, 2006") + " – " + report.DateTo.Format("Jan 2, 2006")
	} else if report.DateFrom != nil {
		dateRange = "From " + report.DateFrom.Format("Jan 2, 2006")
	} else if report.DateTo != nil {
		dateRange = "Until " + report.DateTo.Format("Jan 2, 2006")
	}

	// Group items by date
	type dayKey = string
	groupOrder := []dayKey{}
	groupItems := map[dayKey][]templateItem{}

	ctx := context.Background()

	for _, it := range items {
		day := it.CapturedAt.Format("Monday, January 2, 2006")
		if _, exists := groupItems[day]; !exists {
			groupOrder = append(groupOrder, day)
		}

		ti := templateItem{
			Kind:       it.Kind,
			KindLabel:  kindLabel(it.Kind),
			CSSClass:   kindCSSClass(it.Kind),
			TimeStr:    it.CapturedAt.Format("3:04 PM"),
			AuthorName: userNames[it.CreatedByUserID],
			Caption:    derefStr(it.Caption),
			Body:       derefStr(it.Body),
			Tags:       tagsByItem[it.ID],
		}

		if it.Kind == "photo" {
			if media := primaryPhoto(mediaByItem[it.ID]); media != nil {
				if dataURI := w.photoDataURI(ctx, media.StorageKey, media.MimeType); dataURI != "" {
					ti.PhotoSrc = template.URL(dataURI)
				}
			}
		}

		groupItems[day] = append(groupItems[day], ti)
	}

	// Sort groups chronologically (they were inserted in order so groupOrder is already sorted)
	groups := make([]templateGroup, 0, len(groupOrder))
	for _, day := range groupOrder {
		groups = append(groups, templateGroup{Date: day, Items: groupItems[day]})
	}
	sort.Slice(groups, func(i, j int) bool { return groups[i].Date < groups[j].Date })

	return templateData{
		Title:         report.Title,
		WorkspaceName: workspaceName,
		Job: templateJob{
			Name:        jobName,
			ClientName:  clientName,
			Address:     address,
			JobNumber:   jobNumber,
			StatusLabel: statusLabel(status),
		},
		DateRange:   dateRange,
		TotalItems:  len(items),
		GeneratedAt: time.Now().Format("Jan 2, 2006"),
		Groups:      groups,
	}
}

func (w *PDFReportWorker) photoDataURI(ctx context.Context, storageKey, mimeType string) string {
	data, err := w.Store.Get(ctx, storageKey)
	if err != nil {
		return ""
	}

	// Resize to max 1000px wide to keep PDF sizes reasonable
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		// If decoding fails (e.g. HEIC), embed raw bytes
		enc := base64.StdEncoding.EncodeToString(data)
		return "data:" + mimeType + ";base64," + enc
	}

	const maxWidth = 1000
	if img.Bounds().Dx() > maxWidth {
		img = imaging.Resize(img, maxWidth, 0, imaging.Lanczos)
	}

	var buf bytes.Buffer
	if err := imaging.Encode(&buf, img, imaging.JPEG, imaging.JPEGQuality(80)); err != nil {
		return ""
	}
	enc := base64.StdEncoding.EncodeToString(buf.Bytes())
	return "data:image/jpeg;base64," + enc
}

func (w *PDFReportWorker) callGotenberg(ctx context.Context, html []byte) ([]byte, error) {
	var body bytes.Buffer
	mw := multipart.NewWriter(&body)

	fw, err := mw.CreateFormFile("files", "index.html")
	if err != nil {
		return nil, err
	}
	if _, err := fw.Write(html); err != nil {
		return nil, err
	}

	// A4 with comfortable margins
	for k, v := range map[string]string{
		"paperWidth":    "8.27",
		"paperHeight":   "11.69",
		"marginTop":     "0",
		"marginBottom":  "0",
		"marginLeft":    "0",
		"marginRight":   "0",
	} {
		if err := mw.WriteField(k, v); err != nil {
			return nil, err
		}
	}
	mw.Close()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		w.GotenbergURL+"/forms/chromium/convert/html", &body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", mw.FormDataContentType())

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		msg, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("gotenberg returned %d: %s", resp.StatusCode, strings.TrimSpace(string(msg)))
	}

	return io.ReadAll(resp.Body)
}

// — helpers —

func renderHTML(data templateData) ([]byte, error) {
	tmpl, err := template.New("report").Parse(reportTemplate)
	if err != nil {
		return nil, err
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, data); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func filterItems(items []dbItem, report reports.Report) []dbItem {
	var out []dbItem
	for _, it := range items {
		switch it.Kind {
		case "photo":
			if !report.IncludePhotos {
				continue
			}
		case "note":
			if !report.IncludeNotes {
				continue
			}
		case "voice":
			if !report.IncludeVoice {
				continue
			}
		case "file":
			if !report.IncludeFiles {
				continue
			}
		}
		if report.DateFrom != nil && it.CapturedAt.Before(*report.DateFrom) {
			continue
		}
		if report.DateTo != nil {
			end := report.DateTo.Add(24 * time.Hour)
			if !it.CapturedAt.Before(end) {
				continue
			}
		}
		out = append(out, it)
	}
	return out
}

func primaryPhoto(media []dbMedia) *dbMedia {
	// Prefer annotated_render, fall back to primary_photo
	for i := range media {
		if media[i].Role == "annotated_render" {
			return &media[i]
		}
	}
	for i := range media {
		if media[i].Role == "primary_photo" {
			return &media[i]
		}
	}
	return nil
}

func kindLabel(kind string) string {
	switch kind {
	case "photo":
		return "Photo"
	case "note":
		return "Note"
	case "voice":
		return "Voice note"
	case "file":
		return "File"
	default:
		return kind
	}
}

func kindCSSClass(kind string) string {
	switch kind {
	case "note":
		return "item-note"
	case "voice":
		return "item-voice"
	case "file":
		return "item-file"
	default:
		return ""
	}
}

func statusLabel(s string) string {
	switch s {
	case "in_progress":
		return "In Progress"
	case "planning":
		return "Planning"
	case "completed":
		return "Completed"
	default:
		return s
	}
}

func derefStr(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
