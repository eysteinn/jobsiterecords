package ratelimit

import (
	"net/http"
	"strconv"
	"sync"
	"time"
)

type bucket struct {
	count     int
	resetAt   time.Time
}

type Limiter struct {
	mu      sync.Mutex
	buckets map[string]*bucket
}

func New() *Limiter {
	return &Limiter{buckets: make(map[string]*bucket)}
}

func (l *Limiter) Allow(key string, limit int, window time.Duration) (allowed bool, retryAfter time.Duration) {
	now := time.Now()
	l.mu.Lock()
	defer l.mu.Unlock()

	b, ok := l.buckets[key]
	if !ok || now.After(b.resetAt) {
		l.buckets[key] = &bucket{count: 1, resetAt: now.Add(window)}
		return true, 0
	}
	if b.count >= limit {
		return false, time.Until(b.resetAt)
	}
	b.count++
	return true, 0
}

func Write429(w http.ResponseWriter, retryAfter time.Duration) {
	secs := int(retryAfter.Seconds())
	if secs < 1 {
		secs = 1
	}
	w.Header().Set("Retry-After", strconv.Itoa(secs))
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusTooManyRequests)
	_, _ = w.Write([]byte(`{"error":"rate_limited","message":"Too many requests. Try again later."}`))
}
