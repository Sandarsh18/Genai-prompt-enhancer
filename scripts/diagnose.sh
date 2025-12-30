#!/usr/bin/env bash
# Quick diagnostic for local dev: ports, endpoints, and recent logs.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# Load .env simple (ignore comments)
if [ -f .env ]; then
  set -o allexport
  # shellcheck disable=SC2046
  eval $(grep -v '^\s*#' .env | sed -n 's/^\s*//p' | xargs -I{} echo "export {}" 2>/dev/null)
  set +o allexport
fi

LINES="${DIAG_LOG_LINES:-200}"
echo "=== Diagnostic: $(date) ==="
echo

echo "1) Listening TCP ports (filter for expected ports):"
ss -ltnp 2>/dev/null | egrep ':8000|:8001|:8002|:8088|:5173' || ss -ltnp 2>/dev/null || true
echo

echo "2) Basic process list for likely service binaries (uvicorn/node/python):"
ps aux | egrep 'uvicorn|gunicorn|node|python' | egrep -v 'egrep' || true
echo

echo "3) HTTP checks (tries / and /docs):"
for p in 8000 8001 8002 8088 5173; do
  echo "---- port $p ----"
  curl -sS --max-time 5 "http://localhost:$p/" && echo || {
    curl -sS --max-time 5 "http://localhost:$p/docs" && echo || echo "no HTTP response on port $p"
  }
done
echo

echo "4) Recent logs (last $LINES lines per file) from logs/ if present:"
if [ -d logs ]; then
  for f in logs/*.log; do
    [ -f "$f" ] || continue
    echo "---- $f (tail $LINES) ----"
    tail -n "$LINES" "$f" || true
    echo
  done
else
  echo "No logs/ directory found."
fi

# New: quick dependency checks
echo "5) Dependency checks:"
# check python package importability
PY_PKGS="${BOOTSTRAP_PY_PACKAGES:-prometheus-fastapi-instrumentator}"
for pkg in $PY_PKGS; do
  python3 - <<PYCODE 2>/dev/null
import importlib,sys
try:
    importlib.import_module("$pkg")
    print("$pkg: installed")
except Exception as e:
    print("$pkg: missing ($e)")
PYCODE
done

# check npm/vite
if command -v npm >/dev/null 2>&1; then
  echo "npm: found ($(npm --version 2>/dev/null || echo 'version unknown'))"
else
  echo "npm: NOT FOUND"
fi

if command -v vite >/dev/null 2>&1; then
  echo "vite: found ($(vite --version 2>/dev/null || echo 'version unknown'))"
else
  echo "vite: NOT FOUND (frontend will fail to start)"
fi

echo
echo "Recommendation: If packages are missing, run ./scripts/bootstrap.sh (it will try to pip install the Python packages and run npm ci in the frontend)."
echo "=== End diagnostic ==="
