#!/usr/bin/env bash
# One episode, one call: submit it, wait for the job, print the transcript.
# Usage: transcribe.sh <apple-podcasts-url|episode_id|upload_id> [max_credits]
#   An ep_ id comes from episodes.sh; an upl_ id from upload.sh.
#   max_credits refuses the call, before anything is spent, if it could cost
#     more than that many credits.
#   AUDIVO_FORMAT: text (default), json, srt, vtt or md.
#   AUDIVO_WAIT_SECONDS: how long to wait for a fresh job (default 600).
# Spends credits: about one per audio minute, less for an episode already
# transcribed. The same arguments within 24 hours return the same job and
# charge nothing further.
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "usage: transcribe.sh <apple-podcasts-url|episode_id|upload_id> [max_credits]" >&2
  exit 2
fi
if [ "${AUDIVO_API_KEY:-}" = "" ]; then
  echo "AUDIVO_API_KEY is not set; create a key at https://dash.audivo.dev and export it" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to build the request and read the answer" >&2
  exit 1
fi

BASE="${AUDIVO_API_BASE_URL:-https://api.audivo.dev}"
POINTER="$1"
MAX="${2:-}"
FORMAT="${AUDIVO_FORMAT:-text}"
WAIT="${AUDIVO_WAIT_SECONDS:-600}"

case "$FORMAT" in
  json|text|srt|vtt|md) ;;
  *)
    echo "AUDIVO_FORMAT must be one of json, text, srt, vtt, md; got: $FORMAT" >&2
    exit 2
    ;;
esac
if [ "$MAX" != "" ] && ! printf '%s' "$MAX" | grep -Eq '^[0-9]+$'; then
  echo "max_credits must be a whole number; got: $MAX" >&2
  exit 2
fi

# The body, by what the pointer is, and an idempotency key derived from it:
# the same request twice is the same job, never a second charge.
BODY=$(POINTER="$POINTER" MAX="$MAX" python3 -c '
import json, os, re, sys
p, m = os.environ["POINTER"], os.environ["MAX"]
if re.fullmatch(r"ep_[a-z2-7]{16}", p):
    body = {"episode_id": p}
elif re.fullmatch(r"upl_[A-Za-z0-9]{16,32}", p):
    body = {"upload_id": p}
elif re.match(r"https?://", p):
    body = {"url": p}
else:
    sys.exit("expected an Apple Podcasts URL, an ep_ id, or an upl_ id; got: " + p)
if m:
    body["max_credits"] = int(m)
print(json.dumps(body, sort_keys=True, separators=(",", ":")))
')
KEY="skill-transcribe-$(printf '%s' "$BODY" | python3 -c 'import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest()[:40])')"

RESPONSE=$(curl -sS -w '\n%{http_code}' -X POST "$BASE/v1/transcripts" \
  -H "Authorization: Bearer $AUDIVO_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: $KEY" \
  -d "$BODY")
STATUS=$(printf '%s' "$RESPONSE" | tail -n 1)
ANSWER=$(printf '%s' "$RESPONSE" | sed '$d')

if [ "$STATUS" = "200" ]; then
  # Already transcribed: the transcript is in the answer.
  if [ "$FORMAT" = "json" ]; then
    printf '%s\n' "$ANSWER"
  else
    printf '%s' "$ANSWER" | python3 -c '
import json, sys
body = json.load(sys.stdin)
if "transcript" not in body:
    print(json.dumps(body))
    sys.exit(0)
charged = body.get("credits_charged")
print(f"# credits charged: {charged}", file=sys.stderr)
for segment in body["transcript"]["segments"]:
    print(segment["text"])
'
  fi
  exit 0
fi
if [ "$STATUS" != "202" ]; then
  printf '%s\n' "$ANSWER" >&2
  exit 1
fi

JOB_ID=$(printf '%s' "$ANSWER" | python3 -c 'import json,sys; print(json.load(sys.stdin)["job_id"])')
echo "job $JOB_ID accepted; waiting up to ${WAIT}s" >&2

DEADLINE=$(( $(date +%s) + WAIT ))
while :; do
  JOB=$(curl -sS --fail-with-body "$BASE/v1/transcripts/$JOB_ID" \
    -H "Authorization: Bearer $AUDIVO_API_KEY")
  STATE=$(printf '%s' "$JOB" | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])')
  case "$STATE" in
    completed) break ;;
    failed|cancelled)
      printf '%s\n' "$JOB" >&2
      exit 1
      ;;
  esac
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    echo "job $JOB_ID is still $STATE; run: poll.sh $JOB_ID, then read.sh $JOB_ID $FORMAT" >&2
    exit 3
  fi
  sleep 10
done

SETTLED=$(printf '%s' "$JOB" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("settled_credits"))')
echo "# job $JOB_ID completed; credits settled: $SETTLED" >&2
curl -sS --fail-with-body -G "$BASE/v1/transcripts/$JOB_ID" \
  --data-urlencode "format=$FORMAT" \
  -H "Authorization: Bearer $AUDIVO_API_KEY"
echo
