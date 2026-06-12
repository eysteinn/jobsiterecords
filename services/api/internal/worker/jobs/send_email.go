package jobs

import (
	"context"
	"fmt"
	"log"

	"github.com/riverqueue/river"

	"github.com/eysteinn/jobsiterecords/services/api/internal/email"
)

// SendEmailWorker delivers queued transactional email via SMTP.
type SendEmailWorker struct {
	river.WorkerDefaults[email.SendEmailArgs]
	SMTP email.SMTPConfig
}

func (w *SendEmailWorker) Work(ctx context.Context, job *river.Job[email.SendEmailArgs]) error {
	if !w.SMTP.Enabled() {
		return fmt.Errorf("smtp not configured")
	}
	if err := w.SMTP.Send(ctx, job.Args.To, job.Args.Subject, job.Args.Body); err != nil {
		return fmt.Errorf("send email to %s: %w", job.Args.To, err)
	}
	log.Printf("[email] sent to=%s subject=%q", job.Args.To, job.Args.Subject)
	return nil
}
