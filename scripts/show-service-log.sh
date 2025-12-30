#!/usr/bin/env bash
# Quick helper: show logs for a named service.
# Usage: ./scripts/show-service-log.sh email [lines]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COUNT=${2:-200}
case "${1:-}" in
  email) LOG="$ROOT/logs/email.log" ;;
  rewrite) LOG="$ROOT/logs/rewrite.log" ;;
  summarize) LOG="$ROOT/logs/summarize.log" ;;
  all)
    for f in "$ROOT"/logs/*.log; do
      [ -f "$f" ] || continue
      echo "---- $f (last $COUNT lines) ----"
      tail -n "$COUNT" "$f" || true
      echo
    done
    exit 0
    ;;
  *)
    echo "Usage: $0 {email|rewrite|summarize|all} [lines]"
    exit 2
    ;;
esac

if [ -f "$LOG" ]; then
  echo "---- $LOG (last $COUNT lines) ----"
  tail -n "$COUNT" "$LOG" || true
else
  echo "Log not found: $LOG"
fi
