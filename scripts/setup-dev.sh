#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

echo "==> Installing required Python package for services..."
# pip package name vs module name difference:
MODULE_NAME="prometheus_fastapi_instrumentator"
PIP_NAME="prometheus-fastapi-instrumentator"

if python -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('$MODULE_NAME') else 1)"; then
  echo " - $MODULE_NAME already available"
else
  echo " - Installing $PIP_NAME (will try --user, fallback to global)"
  if python -m pip install --user "$PIP_NAME"; then
    echo " - Installed $PIP_NAME (--user)"
  else
    echo " - --user install failed, trying global install (may require sudo)"
    python -m pip install "$PIP_NAME"
  fi
fi

echo
echo "==> Installing frontend Node dependencies (if frontend/package.json exists)..."
if [ -f frontend/package.json ]; then
  if command -v npm >/dev/null 2>&1; then
    (cd frontend && npm install)
    echo " - frontend dependencies installed"
  else
    echo "ERROR: npm not found. Install Node.js/npm and re-run this script."
    exit 1
  fi
else
  echo " - No frontend/package.json found; skipping npm install"
fi

echo
echo "Setup complete. Now run: ./stop-dev.sh && ./start-dev.sh"
