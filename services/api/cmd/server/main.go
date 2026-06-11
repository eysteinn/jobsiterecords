package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river/rivermigrate"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"

	"github.com/eysteinn/jobsiterecords/services/api/internal/config"
	"github.com/eysteinn/jobsiterecords/services/api/internal/db"
	"github.com/eysteinn/jobsiterecords/services/api/internal/server"
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

	// River tables must exist before the insert-only client in server.New can be used.
	if err := runRiverMigrations(ctx, pool); err != nil {
		log.Fatalf("river migrations: %v", err)
	}

	srv, err := server.New(cfg, pool)
	if err != nil {
		log.Fatalf("server: %v", err)
	}
	httpServer := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      srv.Router(),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("api listening on :%s", cfg.Port)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown: %v", err)
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
