#!/usr/bin/env bash
# Confirm a quote. THIS SPENDS CREDITS.
# Usage: confirm.sh <quote_id> <expected_total_credits> [idempotency_key]
# expected_total_credits must be the quote's total_ceiling_credits, exactly.
# The idempotency key is printed to stderr; reuse it to retry this same confirm.
set -euo pipefail

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ]; then
  echo "usage: confirm.sh <quote_id> <expected_total_credits> [idempotency_key]" >&2
  exit 2
fi
if [ "${AUDIVO_API_KEY:-}" = "" ]; then
  echo "AUDIVO_API_KEY is not set; create a key at https://audivo.dev and export it" >&2
  exit 1
fi

BASE="${AUDIVO_API_BASE_URL:-https://api.audivo.dev}"
QUOTE_ID="$1"
EXPECTED="$2"
KEY="${3:-}"

if [ "$KEY" = "" ]; then
  if command -v uuidgen >/dev/null 2>&1; then
    KEY="$(uuidgen)"
  else
    KEY="confirm-$(date +%s)-$RANDOM$RANDOM"
  fi
fi
echo "Idempotency-Key: $KEY" >&2

BODY=$(cat <<JSON
{ "expected_total_credits": $EXPECTED }
JSON
)

curl -sS --fail-with-body -X POST "$BASE/v1/quotes/$QUOTE_ID/confirm" \
  -H "Authorization: Bearer $AUDIVO_API_KEY" \
  -H "Idempotency-Key: $KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "$BODY"
echo
