#!/usr/bin/env bash
# Simple helper to stress the rewrite endpoint and trigger HPA scaling.
set -euo pipefail

TARGET_URL="${1:-http://localhost:32080/rewrite}"
CONCURRENCY="${CONCURRENCY:-50}"
REQUESTS="${REQUESTS:-5000}"
PAYLOAD='{"text":"Please enhance this prompt to sound more confident and executive."}'

echo "Running hey with $CONCURRENCY concurrent users and $REQUESTS total requests against $TARGET_URL"
hey -n "$REQUESTS" -c "$CONCURRENCY" -m POST -T "application/json" -d "$PAYLOAD" "$TARGET_URL"
