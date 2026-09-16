#!/usr/bin/env bash
#
# Quick spec-render probe: sends a handful of authenticated requests through
# wiretap at a live CF API and summarises the violations. Answers "do the
# response schemas render?" in ~30s instead of the ~1h full compliance run.
#
# Usage:
#   ./bin/render-check.sh [spec-file]
#
# Requires: cf CLI already targeted and logged in.

set -euo pipefail

SPEC="${1:-dist/latest/openapi.yaml}"
PORT=9490
REPORT=out/render-check.json
WT=./node_modules/@pb33f/wiretap/bin/wiretap

[ -f "$SPEC" ] || { echo "Spec not found: $SPEC (run 'yarn build' first)"; exit 1; }
[ -x "$WT" ]   || { echo "wiretap not found at $WT (run 'yarn install')"; exit 1; }

API="$(cf api | awk '/API endpoint/ {print $3}')"
[ -n "$API" ] || { echo "cf is not targeted — run 'cf api <url>' and 'cf login'"; exit 1; }

TOKEN="$(cf oauth-token)"
case "$TOKEN" in
  bearer*|Bearer*) ;;
  *) echo "Could not get a token from 'cf oauth-token' — are you logged in?"; exit 1 ;;
esac

mkdir -p out
rm -f "$REPORT"

echo "spec:   $SPEC"
echo "target: $API"

# Redirect all output: a background job writing to the tty gets SIGTTOU'd by zsh.
"$WT" -s "$SPEC" -u "$API" -p "$PORT" \
      --stream-report --report-filename "$REPORT" \
      > out/render-check-wiretap.log 2>&1 &
WT_PID=$!
trap 'kill "$WT_PID" 2>/dev/null || true' EXIT

for _ in $(seq 1 40); do
  nc -z 127.0.0.1 "$PORT" 2>/dev/null && break
  sleep 0.25
done
nc -z 127.0.0.1 "$PORT" 2>/dev/null || {
  echo "wiretap did not come up on $PORT; see out/render-check-wiretap.log"; exit 1
}

for p in "/v3/apps" "/v3/apps?include=space" "/v3/spaces" \
         "/v3/spaces?include=organization" "/v3/roles?include=user" "/v3/routes"; do
  code="$(curl -s -o /dev/null -w '%{http_code}' -m 30 \
            -H "Authorization: $TOKEN" "http://127.0.0.1:${PORT}${p}")"
  echo "  $code  $p"
done

sleep 2
kill "$WT_PID" 2>/dev/null || true
wait "$WT_PID" 2>/dev/null || true
trap - EXIT

if [ ! -s "$REPORT" ]; then
  echo
  echo "No violations reported — wiretap found nothing to complain about."
  exit 0
fi

echo
node bin/summarize-violations.js "$REPORT" --fields --top 15
