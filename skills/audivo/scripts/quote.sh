#!/usr/bin/env bash
# Price episodes of one show. Reserves nothing.
# Usage: quote.sh <feed_url> [itunes_id|-] [episode_id ...]
# With no episode ids, the newest EPISODES_PER_SHOW episodes (default 1) are priced.
# Pass "-" for itunes_id when the show has none (itunes_id was null).
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "usage: quote.sh <feed_url> [itunes_id|-] [episode_id ...]" >&2
  exit 2
fi
if [ "${AUDIVO_API_KEY:-}" = "" ]; then
  echo "AUDIVO_API_KEY is not set; create a key at https://audivo.dev and export it" >&2
  exit 1
fi

BASE="${AUDIVO_API_BASE_URL:-https://api.audivo.dev}"
FEED_URL="$1"
ITUNES_ID="${2:--}"
shift $(( $# >= 2 ? 2 : 1 ))
PER_SHOW="${EPISODES_PER_SHOW:-1}"

ITUNES_JSON=null
if [ "$ITUNES_ID" != "-" ]; then
  ITUNES_JSON="$ITUNES_ID"
fi

EPISODES_JSON=""
if [ "$#" -gt 0 ]; then
  IDS=""
  for id in "$@"; do
    IDS="$IDS\"$id\","
  done
  EPISODES_JSON=", \"episode_ids\": [${IDS%,}]"
fi

BODY=$(cat <<JSON
{
  "shows": [
    { "feed_url": "$FEED_URL", "itunes_id": $ITUNES_JSON$EPISODES_JSON }
  ],
  "episodes_per_show": $PER_SHOW
}
JSON
)

curl -sS --fail-with-body -X POST "$BASE/v1/quotes" \
  -H "Authorization: Bearer $AUDIVO_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "$BODY"
echo
