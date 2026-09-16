#!/usr/bin/env bash
# List a show's episodes, newest first.
# Usage: episodes.sh <show_id> <feed_url> [itunes_id|-] [limit] [cursor]
# Pass "-" for itunes_id when the show has none (itunes_id was null).
set -euo pipefail

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ]; then
  echo "usage: episodes.sh <show_id> <feed_url> [itunes_id|-] [limit] [cursor]" >&2
  exit 2
fi
if [ "${AUDIVO_API_KEY:-}" = "" ]; then
  echo "AUDIVO_API_KEY is not set; create a key at https://audivo.dev and export it" >&2
  exit 1
fi

BASE="${AUDIVO_API_BASE_URL:-https://api.audivo.dev}"
SHOW_ID="$1"
FEED_URL="$2"
ITUNES_ID="${3:--}"
LIMIT="${4:-20}"
CURSOR="${5:-}"

ARGS=(--data-urlencode "feed_url=$FEED_URL" --data-urlencode "limit=$LIMIT")
if [ "$ITUNES_ID" != "-" ]; then
  ARGS+=(--data-urlencode "itunes_id=$ITUNES_ID")
fi
if [ "$CURSOR" != "" ]; then
  ARGS+=(--data-urlencode "cursor=$CURSOR")
fi

curl -sS --fail-with-body -G "$BASE/v1/shows/$SHOW_ID/episodes" \
  "${ARGS[@]}" \
  -H "Authorization: Bearer $AUDIVO_API_KEY" \
  -H "Accept: application/json"
echo
