#!/usr/bin/env bash
# Find podcast shows by name.
# Usage: search.sh "<query>" [limit]
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "usage: search.sh \"<query>\" [limit]" >&2
  exit 2
fi
if [ "${AUDIVO_API_KEY:-}" = "" ]; then
  echo "AUDIVO_API_KEY is not set; create a key at https://audivo.dev and export it" >&2
  exit 1
fi

BASE="${AUDIVO_API_BASE_URL:-https://api.audivo.dev}"
QUERY="$1"
LIMIT="${2:-20}"

curl -sS --fail-with-body -G "$BASE/v1/search/shows" \
  --data-urlencode "q=$QUERY" \
  --data-urlencode "limit=$LIMIT" \
  -H "Authorization: Bearer $AUDIVO_API_KEY" \
  -H "Accept: application/json"
echo
