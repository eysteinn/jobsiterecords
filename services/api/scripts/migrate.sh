#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

: "${DATABASE_URL:=postgres://jobsiterecords:jobsiterecords@localhost:5432/jobsiterecords?sslmode=disable}"
export DATABASE_URL

exec go run ./cmd/migrate "$@"
