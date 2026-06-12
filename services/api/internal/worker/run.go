package worker

import (
	"context"
	"fmt"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"

	"github.com/eysteinn/jobsiterecords/services/api/internal/config"
	"github.com/eysteinn/jobsiterecords/services/api/internal/email"
	"github.com/eysteinn/jobsiterecords/services/api/internal/jobqueue"
	"github.com/eysteinn/jobsiterecords/services/api/internal/reports"
	"github.com/eysteinn/jobsiterecords/services/api/internal/storage"
	workerjobs "github.com/eysteinn/jobsiterecords/services/api/internal/worker/jobs"
)

// Run starts a River worker client for the configured role and blocks until ctx is cancelled.
func Run(ctx context.Context, cfg config.Config, pool *pgxpool.Pool) error {
	role := ParseRole(cfg.WorkerRole)

	workers := river.NewWorkers()
	queueCfg := map[string]river.QueueConfig{}

	runsMail := role == RoleAll || role == RoleMail
	runsReports := role == RoleAll || role == RoleReports

	if runsMail {
		river.AddWorker(workers, &workerjobs.SendEmailWorker{
			SMTP: email.SMTPFromConfig(cfg),
		})
		queueCfg[jobqueue.Email] = river.QueueConfig{MaxWorkers: cfg.WorkerConcurrency}
	}

	if runsReports {
		store, err := storage.New(ctx, storage.Config{
			Endpoint:       cfg.S3Endpoint,
			PublicEndpoint: cfg.S3PublicEndpoint,
			AccessKey:      cfg.S3AccessKey,
			SecretKey:      cfg.S3SecretKey,
			Bucket:         cfg.S3Bucket,
			UseSSL:         cfg.S3UseSSL,
			PublicUseSSL:   cfg.S3PublicUseSSL,
		})
		if err != nil {
			return fmt.Errorf("storage: %w", err)
		}

		reportsSvc := reports.NewService(pool)
		river.AddWorker(workers, &workerjobs.PDFReportWorker{
			Pool:         pool,
			Reports:      reportsSvc,
			Store:        store,
			GotenbergURL: cfg.GotenbergURL,
		})
		queueCfg[jobqueue.Reports] = river.QueueConfig{MaxWorkers: cfg.WorkerConcurrency}
	}

	if len(queueCfg) == 0 {
		return fmt.Errorf("invalid WORKER_ROLE %q: no queues configured", cfg.WorkerRole)
	}

	riverClient, err := river.NewClient(riverpgxv5.New(pool), &river.Config{
		Queues:  queueCfg,
		Workers: workers,
	})
	if err != nil {
		return fmt.Errorf("river client: %w", err)
	}

	if err := riverClient.Start(ctx); err != nil {
		return fmt.Errorf("river start: %w", err)
	}

	log.Printf(
		"worker started role=%s concurrency=%d queues=%v smtp=%t gotenberg=%s",
		role,
		cfg.WorkerConcurrency,
		queueNames(queueCfg),
		email.SMTPFromConfig(cfg).Enabled(),
		cfg.GotenbergURL,
	)

	<-ctx.Done()

	log.Println("worker shutting down...")
	if err := riverClient.Stop(context.Background()); err != nil {
		return fmt.Errorf("river stop: %w", err)
	}
	return nil
}

func queueNames(queues map[string]river.QueueConfig) []string {
	names := make([]string, 0, len(queues))
	for name := range queues {
		names = append(names, name)
	}
	return names
}
