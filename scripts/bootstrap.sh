#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# Load .env simple (ignore comments)
if [ -f .env ]; then
  set -o allexport
  # shellcheck disable=SC2046
  eval $(grep -v '^\s*#' .env | sed -n 's/^\s*//p' | xargs -I{} echo "export {}" 2>/dev/null) || true
  set +o allexport
fi

echo "Bootstrap: installing Python packages and frontend deps (local user scope where possible)."

# Python packages
PY_PKGS="${BOOTSTRAP_PY_PACKAGES:-prometheus-fastapi-instrumentator}"
if [ -n "$PY_PKGS" ]; then
  echo "Installing Python packages: $PY_PKGS"
  for p in $PY_PKGS; do
    # try to install into user site to avoid sudo
    python3 -m pip install --user "$p" || {
      echo "Failed to install $p with --user, retrying without --user (may require sudo)..."
      python3 -m pip install "$p"
    }
  done
fi

# If the repo has service requirements files, try to install them too
for svc in rewrite-service summarize-service email-service; do
  req="$ROOT/$svc/requirements.txt"
  if [ -f "$req" ]; then
    echo "Installing $svc requirements from $req"
    python3 -m pip install --user -r "$req" || python3 -m pip install -r "$req"
  fi
done

# Frontend: look for common directories with package.json and run npm ci
FRONTEND_DIRS=("frontend" "genai-prompt-enhancer-frontend" "ui" "web")
FOUND_FRONTEND=false
for d in "${FRONTEND_DIRS[@]}"; do
  if [ -f "$ROOT/$d/package.json" ]; then
    FOUND_FRONTEND=true
    echo "Running npm ci in $d"
    (cd "$ROOT/$d" && if command -v npm >/dev/null 2>&1; then npm ci || npm install; else echo "npm not found; please install Node.js/npm and run 'npm ci' in $d"; fi)
  fi
done

if ! $FOUND_FRONTEND; then
  echo "No frontend package.json found in common locations. If your frontend lives elsewhere, run npm ci there."
fi

echo
echo "Bootstrap completed. Re-run ./start-dev.sh (or the service start commands). If services still fail, run ./scripts/diagnose.sh and paste the output."
