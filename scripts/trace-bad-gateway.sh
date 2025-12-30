#!/usr/bin/env bash
# Simple tracer: POST a sample rewrite request to the gateway and, on non-2xx, dump response and tail logs.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GW="http://localhost:8088/rewrite"
SAMPLE_PAYLOAD='{"prompt":"Hello world","options":{}}'
LINES=${1:-200}

echo "POST $GW"
RESP=$(curl -sS -w "\nHTTP_STATUS:%{http_code}\n" -X POST -H 'Content-Type: application/json' -d "$SAMPLE_PAYLOAD" "$GW" || true)
BODY=$(echo "$RESP" | sed -n '1,/HTTP_STATUS:/p' | sed '$d')
STATUS=$(echo "$RESP" | sed -n 's/.*HTTP_STATUS://p' | tr -d '\r\n')

echo "Status: ${STATUS}"
echo "Response body:"
echo "$BODY"
echo

if [[ "$STATUS" != "200" && "$STATUS" != "201" && "$STATUS" != "204" ]]; then
  echo "Non-2xx response; tailing service logs (last $LINES lines)..."
  for f in "$ROOT"/logs/rewrite.log "$ROOT"/logs/email.log "$ROOT"/logs/frontend.log "$ROOT"/logs/docker-build.log "$ROOT"/logs/gateway.log "$ROOT"/logs/nginx.log; do
    [ -f "$f" ] || continue
    echo "---- $f (last $LINES lines) ----"
    tail -n "$LINES" "$f" || true
    echo
  done
  echo "Recommendation: check the upstream service logs above for Python tracebacks or authentication errors (missing/invalid GENAI_API_KEY, network issues, or timeout)."
else
  echo "Request succeeded."
fi
