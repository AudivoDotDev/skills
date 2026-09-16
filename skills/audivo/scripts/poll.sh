#!/usr/bin/env bash
# Read a job group, or one job's status.
# Usage: poll.sh <group_id|job_id>
#   grp_... reads GET /v1/groups/{group_id}
#   job_... reads GET /v1/transcripts/{job_id} with no format (status only)
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "usage: poll.sh <group_id|job_id>" >&2
  exit 2
fi
if [ "${AUDIVO_API_KEY:-}" = "" ]; then
  echo "AUDIVO_API_KEY is not set; create a key at https://audivo.dev and export it" >&2
  exit 1
fi

BASE="${AUDIVO_API_BASE_URL:-https://api.audivo.dev}"
ID="$1"

case "$ID" in
  grp_*) URL="$BASE/v1/groups/$ID" ;;
  job_*) URL="$BASE/v1/transcripts/$ID" ;;
  *)
    echo "expected an id starting with grp_ or job_, got: $ID" >&2
    exit 2
    ;;
esac

curl -sS --fail-with-body "$URL" \
  -H "Authorization: Bearer $AUDIVO_API_KEY" \
  -H "Accept: application/json"
echo
