package main

import (
	"context"
	"flag"
	"log"

	"github.com/eysteinn/jobsiterecords/services/api/internal/config"
	"github.com/eysteinn/jobsiterecords/services/api/internal/db"
)

func main() {
	migrationsDir := flag.String("dir", "migrations", "path to SQL migration files")
	flag.Parse()

	cfg := config.Load()
	ctx := context.Background()

	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database: %v", err)
	}
	defer pool.Close()

	if err := db.RunMigrations(ctx, pool, *migrationsDir); err != nil {
		log.Fatalf("migrations: %v", err)
	}
	log.Println("migrations complete")
}
