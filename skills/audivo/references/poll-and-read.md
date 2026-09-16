# Poll and read

After a confirm you hold a `group_id`, and inside it `job_id`s to poll and
`read_id`s that are already paid. This file covers reading the group, the
job states, the transcript formats, what caching does to the price, and the
one-call path for a single episode.

## Read the group

`GET /v1/groups/{group_id}` (operationId `getGroup`)

Returns the `JobGroupResponse` shown in `quote-and-confirm.md`. Poll it until
`member_counts` has zero in every non-terminal state: `validating`,
`queued`, `downloading`, `transcribing`, `merging`. Then every job member is
`completed`, `failed` or `cancelled`, and every `cached_read` member was
ready from the start.

Wait about ten seconds between polls. A finished hour of audio is typically
a few minutes away.

| group field        | meaning                                                                                   |
| ------------------ | ----------------------------------------------------------------------------------------- |
| `status`           | `pending` while the confirm fans out, `complete` once every member landed, `abandoned` if swept. A cancelled group is `complete` with `cancelled` members. |
| `credits_reserved` | What the group still holds against the balance.                                           |
| `credits_settled`  | What it has been charged so far, jobs and cached reads together.                          |
| `credits_released` | What came back from members that failed, were cancelled, or settled under their ceiling.  |

`GET /v1/groups` (operationId `listGroups`) lists your groups newest first,
summaries only, `limit` 1 to 100. `next_cursor` is always `null` today.

## Cancel what has not started

`POST /v1/groups/{group_id}/cancel` (operationId `cancelGroup`)

Cancels every member still `validating` or `queued` and releases each
reservation exactly once. A member a worker already owns runs to the end
and settles normally. Idempotent: a repeat cancels nothing more and returns
the same rollup. No body, no extra headers.

## Poll one job

`GET /v1/transcripts/{job_id}` (operationId `getTranscriptJob`)

`format` has **no default** here. Omit it for status only. Pass
`format=json` to also get the transcript once the job is `completed`. Pass
`format=text`, `srt`, `vtt` or `md` for the raw rendering of a completed
job; against a job that is not completed that is `409 job_not_completed`,
so keep polling without `format` until it is.

Job states, in order, never backwards:

```
validating -> queued -> downloading -> transcribing -> merging -> completed
```

Any state can end in `failed`. `validating` and `queued` can end in
`cancelled`. Those three are terminal.

| field                  | when present            | meaning                                                                 |
| ---------------------- | ----------------------- | ----------------------------------------------------------------------- |
| `status`               | always                  | One of the states above.                                                |
| `progress`             | while transcribing      | `chunks_done`, `chunks_total`, `percent`, `realtime_factor`, `eta_seconds`. Chunks are fifteen-minute pieces run in parallel. |
| `reserved_credits`     | always                  | The ceiling this job holds.                                             |
| `settled_credits`      | `completed`             | Measured minutes, capped at the reservation.                            |
| `released_credits`     | terminal                | The unused part of the reservation, returned.                           |
| `reservation_released` | `failed`, `cancelled`   | `true`. Never means a cash refund.                                      |
| `error`                | `failed`                | An error object with code `processing_failed` and its `retryable` flag. |
| `artifact`             | `completed` and `?format=json` | `{ "format": "json", "transcript": {...} }` or `{ "transcript_url", "expires_at" }` when oversized. |

Reading a completed job costs nothing, as often as you like.

## Read a cached read

`GET /v1/reads/{read_id}` (operationId `getTranscriptRead`)

Serves the transcript behind a settled read and charges nothing. `read_id`
is the `read_id` of a `cached_read` group member, or the `job_id` of a job
that reached `completed`. Both are ids the account has paid once. `format`
defaults to `json`. A `read_id` you hold no receipt for is `404 job_not_found`.

Response `TranscriptRead`:

```json
{
  "format": "json",
  "is_cached": true,
  "credits_charged": 0,
  "transcript": { ...CanonicalTranscript }
}
```

`credits_charged` is always `0` on this operation.

## Formats

Every transcript read takes `format`, one of `json`, `text`, `srt`, `vtt`,
`md`. Delivery only: it never changes the cache key or the transcript.

| `format` | media type             | what you get                                                           |
| -------- | ---------------------- | ---------------------------------------------------------------------- |
| `json`   | `application/json`     | The canonical transcript inside the envelope for that operation.       |
| `text`   | `text/plain`           | One line per segment.                                                  |
| `srt`    | `application/x-subrip` | Numbered cues, `HH:MM:SS,mmm`, lines wrapped at 42 characters.         |
| `vtt`    | `text/vtt`             | The same cues under a `WEBVTT` header, `.` in the timestamps.          |
| `md`     | `text/markdown`        | A `# Transcript` heading, provenance fields, one paragraph per segment. |

Raw bodies carry provenance in headers, because a plain body has no field
for it: `X-Transcript-Episode-Id`, `X-Transcript-Source`,
`X-Transcript-Timing-Precision`, and `X-Credits-Charged` when a read cost
something.

### The canonical transcript (`json`)

Required fields: `episode_id`, `show_id`, `language`, `duration_sec`,
`source`, `source_revision`, `model_version`, `pipeline_version`,
`timing_precision`, `diarized`, `warnings`, `segments`, `created_at`.

Each segment has `id`, `start`, `end`, `speaker` (always `null` today),
`text`, and `words` with `start`, `end`, `text` when `timing_precision` is
`word`. `diarized` is always `false` today. `warnings` holds per-segment
quality notes such as `repetition_loop`, `known_hallucination`,
`text_over_silence`, `language_mismatch`. A warning is information; the
transcript is delivered and charged as usual.

### Large transcripts

A rendering up to 5 MB is returned inline. Past that, in every format, the
response is `200 application/json` with `{ "transcript_url": "...",
"expires_at": "..." }`. The URL is a signed link valid for 24 hours. Fetch it
plainly, no auth header. Ask again after expiry for a fresh link.

## Cache behaviour

Transcripts of public episodes are shared across accounts. The cache key is
the episode's canonical identity plus its asset revision, which is what the
publisher is actually serving. So:

- The same episode named by feed and guid, by Apple link, or by `episode_id`
  is one key and one price.
- A re-uploaded episode gets a new revision and a fresh transcript.
- Engine and pipeline version are in the key. Output is never quietly
  replaced by a different engine's.

Where you learn whether an episode is cached: `POST /v1/quotes` per entry,
`GET /v1/resolve` per pointer, `POST /v1/transcripts` with `dry_run: true`.
The episode listing always says `null`; it does not probe.

What a cached read costs: the account that produced the transcript reads it
again for one credit. Any other account pays one tenth of the audio minutes,
rounded up, never under one. A read you already paid for is free through
`GET /v1/reads/{read_id}` and `GET /v1/transcripts/{job_id}`.

## The one-call path for a single episode

`POST /v1/transcripts` (operationId `createTranscript`)

Skips the quote when you already hold a pointer. Body is exactly one of
three shapes, plus optional fields:

```json
{ "url": "https://podcasts.apple.com/us/podcast/x/id123?i=456" }
{ "feed_url": "https://example.com/feed.xml", "guid": "episode-guid" }
{ "episode_id": "ep_..." }
```

| optional field | meaning                                                                                   |
| -------------- | ----------------------------------------------------------------------------------------- |
| `dry_run`      | `true` prices only: `is_cached`, `estimated_credits`, `quote_ceiling_credits`, `quote_basis`, `estimated_seconds`. Reserves nothing. |
| `language`     | A BCP-47 tag when you know it. Omitted, the engine detects it.                           |
| `format`       | Only `json` is served on this path. Read other formats through the job or read operations. |

Send an `Idempotency-Key` header. It is optional here but a retry without
one can start a second job for the same episode. A repeat while the original
is still running is `409 request_in_progress`; retry with the same key.

Three answers:

- `200` with `is_cached: true` and the transcript inline. A cached read was
  charged at the cached price; `X-Credits-Charged` says how much.
- `202` with `job_id`, `group_id`, `status`, `reserved_credits`. Fresh work
  was accepted as a group of one. Poll the job or the group.
- `200` with `dry_run: true`. The price, nothing else.

Refusals that reserve nothing: `422 source_not_supported`, `feed_dead`,
`episode_not_found`, `duration_exceeded` (over 10 hours), `size_exceeded`
(over 5 GB), `451 content_blocked`, `402 payment_required`.

`GET /v1/episodes/{episode_id}/transcript` (operationId
`getEpisodeTranscript`) fetches a cached transcript for a known episode and
charges a cached read each call. When nothing is cached it answers a quote
hint with the same figures as a dry run, and creates nothing. Prefer
`GET /v1/reads/{read_id}` for anything you already paid for; it is free.
