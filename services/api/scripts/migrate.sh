#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

: "${DATABASE_URL:=postgres://sitelog:sitelog@localhost:5432/sitelog?sslmode=disable}"
export DATABASE_URL

exec go run ./cmd/migrate "$@"
