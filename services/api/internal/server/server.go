package server

import (
	"context"
	"fmt"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"

	"github.com/eysteinn/jobsiterecords/services/api/internal/auth"
	"github.com/eysteinn/jobsiterecords/services/api/internal/billing"
	"github.com/eysteinn/jobsiterecords/services/api/internal/config"
	"github.com/eysteinn/jobsiterecords/services/api/internal/email"
	"github.com/eysteinn/jobsiterecords/services/api/internal/handlers"
	"github.com/eysteinn/jobsiterecords/services/api/internal/jobs"
	authmw "github.com/eysteinn/jobsiterecords/services/api/internal/middleware"
	"github.com/eysteinn/jobsiterecords/services/api/internal/ratelimit"
	"github.com/eysteinn/jobsiterecords/services/api/internal/reports"
	"github.com/eysteinn/jobsiterecords/services/api/internal/storage"
	"github.com/eysteinn/jobsiterecords/services/api/internal/workspace"
)

type Server struct {
	cfg    config.Config
	router chi.Router
}

func New(cfg config.Config, pool *pgxpool.Pool) (*Server, error) {
	googleVerifier, err := auth.NewGoogleVerifier(context.Background(), cfg.GoogleClientIDs)
	if err != nil {
		return nil, fmt.Errorf("google oauth: %w", err)
	}
	authSvc := auth.NewService(pool, cfg.JWTSecret, cfg.AccessTokenTTL, cfg.RefreshTokenDays, cfg.MagicLinkMinutes, cfg.ResetTokenMinutes, googleVerifier)
	wsSvc := workspace.NewService(pool)
	mail := email.New(cfg.DevLogEmailLinks)
	limiter := ratelimit.New()

	store, err := storage.New(context.Background(), storage.Config{
		Endpoint:       cfg.S3Endpoint,
		PublicEndpoint: cfg.S3PublicEndpoint,
		AccessKey:      cfg.S3AccessKey,
		SecretKey:      cfg.S3SecretKey,
		Bucket:         cfg.S3Bucket,
		UseSSL:         cfg.S3UseSSL,
		PublicUseSSL:   cfg.S3PublicUseSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("storage: %w", err)
	}

	// Insert-only River client: enqueues jobs but does not run workers.
	// The worker binary polls and processes them separately.
	riverClient, err := river.NewClient(riverpgxv5.New(pool), &river.Config{})
	if err != nil {
		return nil, fmt.Errorf("river client: %w", err)
	}

	authH := handlers.NewAuthHandler(cfg, authSvc, wsSvc, mail, limiter)
	wsH := handlers.NewWorkspaceHandler(wsSvc)
	teamH := handlers.NewTeamHandler(cfg, wsSvc, mail)
	jobsSvc := jobs.NewService(pool)
	jobsH := handlers.NewJobsHandler(jobsSvc)
	mediaH := handlers.NewMediaHandler(jobsSvc, store)
	reportsSvc := reports.NewService(pool)
	reportsH := handlers.NewReportsHandler(reportsSvc, riverClient, store)
	billingSvc := billing.NewService(pool, cfg.PaddleAPIKey, cfg.PaddleWebhookSecret, cfg.PaddleEnv, cfg.PaddlePriceIDs)
	billingH := handlers.NewBillingHandler(billingSvc)
	jobsSvc.SetBilling(billingSvc)

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   cfg.CORSOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Request-Id"},
		ExposedHeaders:   []string{"Retry-After"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	r.Post("/api/v1/webhooks/paddle", billingH.Webhook)

	r.Route("/api/v1", func(api chi.Router) {
		api.Get("/invites/preview", teamH.PreviewInvite)

		api.Route("/auth", func(auth chi.Router) {
			auth.Post("/signup", authH.SignUp)
			auth.Post("/login", authH.Login)
			auth.Post("/refresh", authH.Refresh)
			auth.Post("/magic-link", authH.MagicLink)
			auth.Get("/magic-link/verify", authH.VerifyMagicLink)
			auth.Post("/magic-link/verify", authH.VerifyMagicLink)
			auth.Post("/forgot-password", authH.ForgotPassword)
			auth.Post("/reset-password", authH.ResetPassword)
			auth.Post("/oauth/google", authH.OAuthGoogle)

			auth.Group(func(protected chi.Router) {
				protected.Use(authmw.RequireAuth(cfg.JWTSecret))
				protected.Get("/me", authH.Me)
				protected.Post("/logout", authH.Logout)
			})
		})

		api.Group(func(protected chi.Router) {
			protected.Use(authmw.RequireAuth(cfg.JWTSecret))
			protected.Get("/workspaces", wsH.List)
			protected.Get("/workspaces/{workspaceID}/billing", billingH.GetWorkspaceBilling)
			protected.Post("/workspaces/{workspaceID}/billing/portal", billingH.OpenPortal)
			protected.Post("/workspaces/{workspaceID}/leave", wsH.Leave)
			protected.Get("/workspaces/{workspaceID}/team", teamH.GetTeam)
			protected.Post("/workspaces/{workspaceID}/invites", teamH.CreateInvite)
			protected.Post("/workspaces/{workspaceID}/invites/{inviteID}/resend", teamH.ResendInvite)
			protected.Delete("/workspaces/{workspaceID}/invites/{inviteID}", teamH.RevokeInvite)
			protected.Delete("/workspaces/{workspaceID}/members/{memberUserID}", teamH.RemoveMember)
			protected.Post("/invites/accept", teamH.AcceptInvite)
			protected.Get("/workspaces/{workspaceID}/jobs", jobsH.ListWorkspaceJobs)
			protected.Get("/workspaces/{workspaceID}/tags", jobsH.ListWorkspaceTags)
			protected.Put("/workspaces/{workspaceID}/tags/{tagID}", jobsH.UpsertTag)
			protected.Get("/workspaces/{workspaceID}/cursor", jobsH.GetWorkspaceCursor)
			protected.Get("/workspaces/{workspaceID}/assignments", jobsH.AssignedJobIDs)
			protected.Post("/workspaces/{workspaceID}/reports", reportsH.Create)
			protected.Get("/workspaces/{workspaceID}/reports", reportsH.List)
			protected.Get("/jobs/{jobID}/cursor", jobsH.GetJobCursor)
			protected.Get("/jobs/{jobID}", jobsH.GetJob)
			protected.Put("/jobs/{jobID}", jobsH.UpsertJob)
			protected.Put("/jobs/{jobID}/items/{itemID}", jobsH.UpsertItem)
			protected.Post("/items/{itemID}/media-files", mediaH.CreateMedia)
			protected.Get("/items/{itemID}/thumb", mediaH.ItemThumb)
			protected.Post("/media-files/{mediaID}/complete", mediaH.CompleteMedia)
			protected.Delete("/media-files/{mediaID}", mediaH.DeleteMedia)
			protected.Get("/media-files/{mediaID}/download", mediaH.DownloadMedia)
			protected.Get("/reports/{reportID}", reportsH.Get)
			protected.Get("/reports/{reportID}/download", reportsH.Download)
		})
	})

	return &Server{cfg: cfg, router: r}, nil
}

func (s *Server) Router() http.Handler {
	return s.router
}
