# Errors

Every error from the API is one JSON envelope:

```json
{
  "error": {
    "type": "conflict",
    "code": "expected_total_mismatch",
    "message": "…for a person…",
    "doc_url": "https://docs.audivo.dev/errors#expected_total_mismatch",
    "request_id": "req_...",
    "retryable": false
  }
}
```

Branch on `code`. `type` is the coarser family. `retryable` says whether the
identical request can succeed later with no change on your side. `doc_url`
always points to `https://docs.audivo.dev/errors#<code>`, the heading for
that code on the docs site. Quote `request_id` when reporting a problem.

Two response headers matter for retries: `X-RateLimit-Limit` states the
plan's requests per minute, and `Retry-After` comes with a `429`.

## Every code

Status and type are the spec's. "Do" is what an agent should do next.

### Your request

| code                  | status | type              | retry | do                                                                                    |
| --------------------- | ------ | ----------------- | ----- | ------------------------------------------------------------------------------------- |
| `invalid_request`     | 400    | invalid_request   | no    | Fix the shape: a missing field, a value out of range, an unknown field, a missing required `Idempotency-Key`. |
| `invalid_url`         | 400    | invalid_request   | no    | The pointer is not an absolute http(s) URL of a supported form.                       |
| `unauthenticated`     | 401    | unauthenticated   | no    | The key is missing, malformed, revoked or expired. Check `AUDIVO_API_KEY`; ask the user for a fresh key. |
| `payment_required`    | 402    | payment_required  | no    | Balance cannot cover the ceiling. Shrink the selection or ask the user to add credits, then quote again. |
| `rate_limited`        | 429    | rate_limited      | yes   | Over requests per minute. Sleep for `Retry-After` seconds, then repeat the same request. |
| `concurrency_limited` | 429    | rate_limited      | yes   | The plan's open-job cap is reached. Wait for a job to finish, or confirm fewer episodes. |
| `upload_quota_exceeded` | 429  | rate_limited      | yes   | The account already holds its 10 GiB / 100-announcement upload allowance. No `PUT` URL was issued. The message names the earliest time enough capacity returns; there is no way to release an announcement early. See `references/uploads.md`. |

### Quotes, confirms and groups

| code                      | status | type      | retry | do                                                                                      |
| ------------------------- | ------ | --------- | ----- | --------------------------------------------------------------------------------------- |
| `quote_not_found`         | 404    | not_found | no    | The quote id is wrong or belongs to another account. Quote again.                        |
| `quote_expired`           | 409    | conflict  | no    | More than fifteen minutes passed. Quote again and show the user the new price.           |
| `quote_mismatch`          | 409    | conflict  | no    | An episode's audio changed since the quote. Quote again.                                 |
| `quote_unverified`        | 409    | conflict  | yes   | The confirm ran out of time re-checking entries. Send the same confirm with the same key. |
| `expected_total_mismatch` | 409    | conflict  | no    | Your `expected_total_credits` is not the quote's `total_ceiling_credits`. Re-read the quote and restate it exactly. Never adjust the number to force a match. Nothing was spent. |
| `group_not_found`         | 404    | not_found | no    | The group id is wrong or belongs to another account.                                     |
| `idempotency_conflict`    | 409    | conflict  | no    | The same `Idempotency-Key` was reused with a different body. Use a fresh key for a new intent. |
| `request_in_progress`     | 409    | conflict  | yes   | A request under this key is still running. Wait a moment and retry with the same key.    |
| `nothing_to_quote`        | 422    | unprocessable_input | no | Every episode was excluded. Read the message; it counts the reasons.                 |

### Jobs and transcripts

| code                 | status | type        | retry | do                                                                            |
| -------------------- | ------ | ----------- | ----- | ----------------------------------------------------------------------------- |
| `job_not_found`      | 404    | not_found   | no    | Wrong id, another account's, or a `read_id` with no receipt yet.               |
| `job_not_completed`  | 409    | conflict    | yes   | You asked for a rendering of a job that is not `completed`. Poll without `format` until it is. |
| `processing_failed`  | 500    | unavailable | yes   | The job failed; its reservation was released. Also appears inside a failed job's `error`. Submit again later. |
| `engine_unavailable` | 503    | unavailable | yes   | The transcription route is down. Audivo never switches engines silently. Retry later. |

### Resolving a show or episode

| code                   | status | type                | retry | do                                                                                 |
| ---------------------- | ------ | ------------------- | ----- | ---------------------------------------------------------------------------------- |
| `source_not_supported` | 422    | invalid_request     | no    | Direct audio, uploads, Spotify- or YouTube-only shows, or a feed with nothing stable to key on. Tell the user; there is no workaround. |
| `feed_dead`            | 422    | not_found           | yes   | The feed could not be fetched or parsed in time. Retry once; then tell the user.   |
| `episode_not_found`    | 422    | not_found           | no    | Not in the feed, or unknown when named by id. Re-list the episodes.                 |
| `show_not_found`       | 422    | not_found           | no    | The show could not be resolved. Search again.                                       |
| `unsafe_source`        | 422    | invalid_request     | no    | The fetch target or a redirect failed the outbound-security policy.                 |
| `unsupported_codec`    | 422    | unprocessable_input | no    | The audio is in a format the pipeline does not accept.                              |
| `unsupported_language` | 422    | unprocessable_input | no    | The requested language is outside published support. See `GET /v1/languages`.       |
| `duration_exceeded`    | 422    | unprocessable_input | no    | Over the 10-hour cap.                                                               |
| `size_exceeded`        | 422    | unprocessable_input | no    | Over the 5 GB cap.                                                                  |
| `content_blocked`      | 451    | content_blocked     | no    | A publisher or legal block is active. Tell the user.                                |
| `discovery_unavailable`| 503    | unavailable         | yes   | The show directory did not answer. Retry later.                                     |

### Quoting an upload

These three are not envelope errors, so nothing above applies to them.
Quoting an upload still answers `200`; a failing upload comes back inside
the quote's `excluded[]` with one of these reasons instead. Full detail in
`references/uploads.md`.

| reason                 | do                                                                                             |
| ------------------------ | -------------------------------------------------------------------------------------------------- |
| `upload_not_found`      | The `upload_id` is unknown, belongs to another account, or is past `retained_until`. Announce again. |
| `upload_not_received`   | Nothing has landed at the bucket key yet. Send the PUT, then quote again.                        |
| `upload_mismatch`       | What landed does not match the announced length or hash. Announce again with the correct file.   |

### Your account

| code                     | status | type                | retry | do                                                                           |
| ------------------------ | ------ | ------------------- | ----- | ---------------------------------------------------------------------------- |
| `account_suspended`      | 409    | conflict            | no    | The account is on hold; reads still work, writes do not. Tell the user.      |
| `account_closed`         | 409    | conflict            | no    | The account is closing or closed.                                             |
| `account_not_found`      | 409    | conflict            | no    | The key resolves to no account. Tell the user to check the dashboard.        |
| `tier_unchanged`         | 409    | conflict            | no    | Dashboard only: checkout for the plan already held.                           |
| `api_key_not_found`      | 404    | not_found           | no    | Dashboard only.                                                               |
| `api_key_limit_reached`  | 409    | conflict            | no    | Dashboard only: 25 live keys already.                                         |
| `credit_lot_not_found`   | 404    | not_found           | no    | Dashboard only.                                                               |
| `credits_not_refundable` | 422    | unprocessable_input | no    | Dashboard only.                                                               |

### Ours

| code             | status | type        | retry | do                                                     |
| ---------------- | ------ | ----------- | ----- | ------------------------------------------------------ |
| `internal_error` | 500    | unavailable | yes   | Retry once. If it persists, report the `request_id`.   |

## Retry policy in three lines

- `retryable: true` with a `429`: sleep `Retry-After`, repeat the same request.
- `retryable: true` on a confirm (`quote_unverified`, `request_in_progress`):
  repeat with the same `Idempotency-Key`. Never mint a new one.
- `retryable: false`: do not repeat. Change something, or tell the user.
