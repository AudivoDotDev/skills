#!/usr/bin/env bash
# Announce a local audio file, PUT it to the presigned URL, and print a
# ready quote body. Spends no credits; a quote and confirm still follow.
# Usage: upload.sh <file> [title]
#   AUDIVO_DURATION_SECONDS: required if ffprobe is not on PATH. Seconds,
#     for example 1807.4.
#   AUDIVO_UPLOAD_DRY_RUN=1: print the announcement body and exit 0; no
#     API call is made.
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "usage: upload.sh <file> [title]" >&2
  echo "  AUDIVO_DURATION_SECONDS is required if ffprobe is not on PATH." >&2
  echo "  AUDIVO_UPLOAD_DRY_RUN=1 prints the announcement body and exits; no API call is made." >&2
  exit 2
fi
if [ "${AUDIVO_API_KEY:-}" = "" ]; then
  echo "AUDIVO_API_KEY is not set; create a key at https://audivo.dev and export it" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to parse the API response" >&2
  exit 1
fi

BASE="${AUDIVO_API_BASE_URL:-https://api.audivo.dev}"
FILE="$1"
TITLE="${2:-}"

if [ ! -f "$FILE" ]; then
  echo "no such file: $FILE" >&2
  exit 2
fi

# content_type from the extension, checked first since it is the cheapest
# way to reject an unsupported file before hashing or probing it. See
# references/uploads.md for the full accepted list; these are the common ones.
EXT="${FILE##*.}"
EXT="$(printf '%s' "$EXT" | tr '[:upper:]' '[:lower:]')"
case "$EXT" in
  mp3) CONTENT_TYPE=audio/mpeg ;;
  m4a) CONTENT_TYPE=audio/mp4 ;;
  mp4) CONTENT_TYPE=audio/mp4 ;;
  aac) CONTENT_TYPE=audio/aac ;;
  ogg|oga) CONTENT_TYPE=audio/ogg ;;
  opus) CONTENT_TYPE=audio/opus ;;
  flac) CONTENT_TYPE=audio/flac ;;
  wav) CONTENT_TYPE=audio/wav ;;
  webm) CONTENT_TYPE=audio/webm ;;
  *)
    echo "unrecognized file extension: .$EXT; accepted: mp3, m4a, mp4, aac, ogg, oga, opus, flac, wav, webm" >&2
    exit 2
    ;;
esac

# bytes: macOS stat, then Linux stat.
BYTES=$(stat -f %z "$FILE" 2>/dev/null || stat -c %s "$FILE")

# sha256: BSD/macOS shasum, then GNU coreutils sha256sum.
if command -v shasum >/dev/null 2>&1; then
  SHA256=$(shasum -a 256 "$FILE" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
  SHA256=$(sha256sum "$FILE" | awk '{print $1}')
else
  echo "need shasum or sha256sum on PATH to hash the file" >&2
  exit 1
fi

# duration: ffprobe when present, else the caller must declare it.
if command -v ffprobe >/dev/null 2>&1; then
  DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$FILE")
elif [ "${AUDIVO_DURATION_SECONDS:-}" != "" ]; then
  DURATION="$AUDIVO_DURATION_SECONDS"
else
  echo "ffprobe is not on PATH; set AUDIVO_DURATION_SECONDS (seconds, for example 1807.4) and try again" >&2
  exit 1
fi

TITLE_JSON=""
if [ "$TITLE" != "" ]; then
  TITLE_JSON=", \"title\": \"$TITLE\""
fi

BODY=$(cat <<JSON
{
  "sha256": "$SHA256",
  "bytes": $BYTES,
  "content_type": "$CONTENT_TYPE",
  "declared_duration_seconds": $DURATION$TITLE_JSON
}
JSON
)

if [ "${AUDIVO_UPLOAD_DRY_RUN:-}" = "1" ]; then
  echo "$BODY"
  exit 0
fi

RESPONSE=$(curl -sS --fail-with-body -X POST "$BASE/v1/uploads" \
  -H "Authorization: Bearer $AUDIVO_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "$BODY")

UPLOAD_ID=$(printf '%s' "$RESPONSE" | python3 -c '
import json, sys
print(json.load(sys.stdin)["upload_id"])
')
PUT_URL=$(printf '%s' "$RESPONSE" | python3 -c '
import json, sys
print(json.load(sys.stdin)["put_url"])
')

PUT_HEADER_ARGS=()
while IFS= read -r header_line; do
  PUT_HEADER_ARGS+=(-H "$header_line")
done < <(printf '%s' "$RESPONSE" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for key, value in data["put_headers"].items():
    print(f"{key}: {value}")
')

# Send exactly the returned headers, nothing else. They are part of the
# signature; a body whose hash differs from the announced sha256 is
# refused by S3 with BadDigest.
curl -sS --fail-with-body -X PUT -T "$FILE" \
  "${PUT_HEADER_ARGS[@]+"${PUT_HEADER_ARGS[@]}"}" \
  "$PUT_URL"

echo "upload_id: $UPLOAD_ID" >&2
cat <<JSON
{"uploads":[{"upload_id":"$UPLOAD_ID"}]}
JSON
