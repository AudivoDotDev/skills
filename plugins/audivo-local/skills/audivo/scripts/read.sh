#!/usr/bin/env bash
# Read a transcript this account already paid for. Charges nothing.
# Usage: read.sh <read_id|job_id> [format]
#   format is one of json, text, srt, vtt, md (default json).
#   Accepts a cached_read member's read_id or a completed job's job_id.
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "usage: read.sh <read_id|job_id> [json|text|srt|vtt|md]" >&2
  exit 2
fi
if [ "${AUDIVO_API_KEY:-}" = "" ]; then
  echo "AUDIVO_API_KEY is not set; create a key at https://audivo.dev and export it" >&2
  exit 1
fi

BASE="${AUDIVO_API_BASE_URL:-https://api.audivo.dev}"
ID="$1"
FORMAT="${2:-json}"

case "$FORMAT" in
  json|text|srt|vtt|md) ;;
  *)
    echo "format must be one of json, text, srt, vtt, md; got: $FORMAT" >&2
    exit 2
    ;;
esac

curl -sS --fail-with-body -G "$BASE/v1/reads/$ID" \
  --data-urlencode "format=$FORMAT" \
  -H "Authorization: Bearer $AUDIVO_API_KEY"
echo
