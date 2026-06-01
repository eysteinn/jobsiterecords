package config

import (
	"os"
	"strings"
)

type Config struct {
	Port              string
	DatabaseURL       string
	JWTSecret         string
	AppURL            string
	CORSOrigins       []string
	DevLogEmailLinks  bool
	CookieSecure      bool
	AccessTokenTTL    int // minutes
	RefreshTokenDays  int
	MagicLinkMinutes  int
	ResetTokenMinutes int
	S3Endpoint        string
	S3PublicEndpoint  string
	S3AccessKey       string
	S3SecretKey       string
	S3Bucket          string
	S3UseSSL          bool
	S3PublicUseSSL    bool
}

func Load() Config {
	return Config{
		Port:              env("PORT", "8080"),
		DatabaseURL:       env("DATABASE_URL", "postgres://sitelog:sitelog@localhost:5432/sitelog?sslmode=disable"),
		JWTSecret:         env("JWT_SECRET", "dev-jwt-secret-change-me"),
		AppURL:            strings.TrimRight(env("APP_URL", "http://localhost:3000"), "/"),
		CORSOrigins:       splitCSV(env("CORS_ORIGINS", "http://localhost:3000")),
		DevLogEmailLinks:  env("DEV_LOG_EMAIL_LINKS", "true") == "true",
		CookieSecure:      env("COOKIE_SECURE", "false") == "true",
		AccessTokenTTL:    15,
		RefreshTokenDays:  30,
		MagicLinkMinutes:  15,
		ResetTokenMinutes: 30,
		S3Endpoint:        env("S3_ENDPOINT", "localhost:9000"),
		S3PublicEndpoint:  env("S3_PUBLIC_ENDPOINT", env("S3_ENDPOINT", "localhost:9000")),
		S3AccessKey:       env("S3_ACCESS_KEY", "minioadmin"),
		S3SecretKey:       env("S3_SECRET_KEY", "minioadmin"),
		S3Bucket:          env("S3_BUCKET", "sitelog"),
		S3UseSSL:          env("S3_USE_SSL", "false") == "true",
		S3PublicUseSSL:    env("S3_PUBLIC_USE_SSL", env("S3_USE_SSL", "false")) == "true",
	}
}

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func splitCSV(s string) []string {
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
