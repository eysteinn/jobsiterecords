package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/rivermigrate"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"

	"github.com/eysteinn/jobsiterecords/services/api/internal/config"
	"github.com/eysteinn/jobsiterecords/services/api/internal/db"
	"github.com/eysteinn/jobsiterecords/services/api/internal/email"
	"github.com/eysteinn/jobsiterecords/services/api/internal/reports"
	"github.com/eysteinn/jobsiterecords/services/api/internal/storage"
	workerjobs "github.com/eysteinn/jobsiterecords/services/api/internal/worker/jobs"
)

func main() {
	cfg := config.Load()

	ctx := context.Background()
	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	defer pool.Close()

	if err := db.RunMigrations(ctx, pool, "migrations"); err != nil {
		log.Fatalf("migrations: %v", err)
	}

	// River manages its own schema separately from our app migrations.
	if err := runRiverMigrations(ctx, pool); err != nil {
		log.Fatalf("river migrations: %v", err)
	}

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
		log.Fatalf("storage: %v", err)
	}

	reportsSvc := reports.NewService(pool)

	workers := river.NewWorkers()
	river.AddWorker(workers, &workerjobs.PDFReportWorker{
		Pool:         pool,
		Reports:      reportsSvc,
		Store:        store,
		GotenbergURL: cfg.GotenbergURL,
	})
	river.AddWorker(workers, &workerjobs.SendEmailWorker{
		SMTP: email.SMTPFromConfig(cfg),
	})

	riverClient, err := river.NewClient(riverpgxv5.New(pool), &river.Config{
		Queues: map[string]river.QueueConfig{
			river.QueueDefault: {MaxWorkers: cfg.WorkerConcurrency},
		},
		Workers: workers,
	})
	if err != nil {
		log.Fatalf("river client: %v", err)
	}

	if err := riverClient.Start(ctx); err != nil {
		log.Fatalf("river start: %v", err)
	}
	log.Printf("worker started (concurrency=%d, gotenberg=%s, smtp=%t)", cfg.WorkerConcurrency, cfg.GotenbergURL, email.SMTPFromConfig(cfg).Enabled())

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	log.Println("worker shutting down...")
	if err := riverClient.Stop(ctx); err != nil {
		log.Printf("river stop: %v", err)
	}
}

func runRiverMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	migrator, err := rivermigrate.New(riverpgxv5.New(pool), nil)
	if err != nil {
		return err
	}
	_, err = migrator.Migrate(ctx, rivermigrate.DirectionUp, nil)
	return err
}
