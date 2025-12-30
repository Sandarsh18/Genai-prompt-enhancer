#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# Load .env (robust, avoids eval/xargs quoting issues)
if [ -f .env ]; then
  set -o allexport
  # read .env line by line, skip comments and blank lines, trim leading spaces
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"   # ltrim
    [ -z "$line" ] && continue
    case "$line" in
      \#*) continue ;;                        # skip comments
      *) export "$line" ;;                    # export KEY=VALUE
    esac
  done < <(sed -e 's/^[[:space:]]*//' .env | sed '/^\s*#/d')
  set +o allexport
fi

: "${GENAI_GEMINI_BASE_URL:?"GENAI_GEMINI_BASE_URL must be set in .env"}"
: "${GENAI_API_KEY:?'GENAI_API_KEY must be set in .env (use a placeholder locally if you don't want to call the provider)'}"
: "${GENAI_MODEL:?'GENAI_MODEL must be set in .env'}"

echo "Using GENAI_GEMINI_BASE_URL=${GENAI_GEMINI_BASE_URL}"
echo "Using GENAI_MODEL=${GENAI_MODEL}"
echo

CURL_OPTS=(-sS -H "Authorization: Bearer ${GENAI_API_KEY}" -H "Content-Type: application/json" --max-time 10)

# 1) Try listing models
echo "==> GET ${GENAI_GEMINI_BASE_URL}/models (list models)"
http_status=$(curl -w "%{http_code}" "${CURL_OPTS[@]}" -o /tmp/genai_list_models.json "${GENAI_GEMINI_BASE_URL}/models" 2>/dev/null || true)
echo "HTTP status: ${http_status}"
echo "Response body:"
cat /tmp/genai_list_models.json || true
echo
rm -f /tmp/genai_list_models.json

# 2) Candidate model endpoints to try (some providers use :predict or :generate)
CANDIDATES=(
  "${GENAI_GEMINI_BASE_URL}/models/${GENAI_MODEL}:predict"
  "${GENAI_GEMINI_BASE_URL}/models/${GENAI_MODEL}:generate"
  "${GENAI_GEMINI_BASE_URL}/models/${GENAI_MODEL}/predict"
  "${GENAI_GEMINI_BASE_URL}/models/${GENAI_MODEL}"
)

# Small safe payload for POST tests (may be rejected but will show provider error)
PAYLOAD='{"instances":["Test request"], "parameters": {"maxOutputTokens":16}}'

echo "==> Attempting POST to candidate model endpoints will show status + body"
for url in "${CANDIDATES[@]}"; do
  echo "---- POST $url ----"
  tmpfile="$(mktemp)"
  status=$(curl -w "%{http_code}" "${CURL_OPTS[@]}" -o "$tmpfile" -X POST -d "${PAYLOAD}" "$url" 2>/dev/null || true)
  echo "HTTP status: ${status}"
  echo "Response body:"
  cat "$tmpfile" || true
  echo
  rm -f "$tmpfile"
done

echo "==> Done. If all candidates return 404, double-check GENAI_GEMINI_BASE_URL and GENAI_MODEL."
echo "Hint: try the 'list models' response above to see available model IDs."
echo "Example (use your API key):"
echo "  curl -sS -H \"Authorization: Bearer \$GENAI_API_KEY\" \"${GENAI_GEMINI_BASE_URL}/models\" | jq ."
