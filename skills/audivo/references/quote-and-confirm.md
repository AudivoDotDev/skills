# Quote and confirm

A quote prices a selection and reserves nothing. A confirm spends what the
quote priced, as one job group. Every guard on the confirm runs before the
first credit moves, so a refusal writes nothing.

## Credits, in one paragraph

One credit is one minute of audio, rounded up per episode. A quote gives each
fresh episode `estimated_credits` from its declared duration and
`quote_ceiling_credits`, the estimate plus 25% rounded up. The ceiling is the
most that episode can ever settle for. At confirm each fresh job reserves its
ceiling. On completion it settles at the measured minutes, capped at the
ceiling, and the rest is released. An episode already transcribed by another
account is a cached read: one tenth of its minutes, rounded up, never under
one credit, settled at once at confirm. Full rules at
https://docs.audivo.dev/credits.

## Price a selection

`POST /v1/quotes` (operationId `createQuote`)

The body is one of two shapes. Send exactly one.

### Shape 1: named shows

```json
{
  "shows": [
    {
      "feed_url": "https://example.com/feed.xml",
      "itunes_id": 123456789,
      "episode_ids": ["ep_..."],
      "title": "Optional label"
    }
  ],
  "episodes_per_show": 1
}
```

| field                       | meaning                                                                                         |
| --------------------------- | ----------------------------------------------------------------------------------------------- |
| `shows[].feed_url`          | Required. Copy it from a `ShowSummary`.                                                         |
| `shows[].itunes_id`         | Copy it when the show has one. It changes how `show_id` derives.                                |
| `shows[].episode_ids`       | The exact episodes this show contributes, from the episode list. 1 to 100 ids.                  |
| `shows[].title`             | Only a label the quote shows back. Defaults to the feed URL.                                    |
| `episodes_per_show`         | The N in "the newest N per show". 1 to 100, default 1. Ignored for a show with `episode_ids`.    |
| `include_music_led`         | Accepted, changes nothing here. Named shows are taken as chosen.                                |

`episode_ids` and `episodes_per_show` do not combine. Name the episodes, or
take the newest N. Naming is the only way to reach an older episode.

### Shape 2: a chart

```json
{
  "chart": { "category": "Business", "size": 10, "language": "en" },
  "episodes_per_show": 1,
  "include_music_led": false
}
```

The chart is fetched and clamped inside the quote exactly as `GET /v1/charts`
clamps it. Music-led shows are excluded unless `include_music_led` is `true`,
and each one is named in `excluded`.

### Limits on a selection

Two plan bounds apply: the chart size, and the total number of episodes one
selection may hold. Episodes per selection: free 3, hobby 10, startup 30,
growth 60, scale 100. A bound that bites is reported in `clamps`, never
applied silently. There is no per-show depth cap; name the episodes you want.

### The quote response

```json
{
  "quote_id": "qte_...",
  "source": "shows",
  "episodes_per_show": 1,
  "entries": [
    {
      "episode_id": "ep_...",
      "show_id": "sh_...",
      "feed_url": "...",
      "guid": "...",
      "show_title": "...",
      "episode_title": "...",
      "published_at": "...",
      "is_cached": false,
      "estimated_credits": 52,
      "quote_ceiling_credits": 65,
      "quote_basis": "feed_metadata",
      "declared_duration_seconds": 3100
    }
  ],
  "excluded": [
    { "feed_url": "...", "guid": null, "title": "...", "reason": "music_led", "detail": "..." }
  ],
  "clamps": [
    { "dimension": "total_selection", "requested": 5, "allowed": 3, "limit": 3, "clamped": true, "detail": "..." }
  ],
  "cached_members": 0,
  "uncached_members": 1,
  "total_ceiling_credits": 65,
  "remaining_open_jobs": 3,
  "balance_credits": 120,
  "reserved_credits": 0,
  "expires_at": "2026-09-16T12:15:00Z",
  "created_at": "2026-09-16T12:00:00Z"
}
```

What to read before confirming:

| field                   | meaning                                                                                                   |
| ----------------------- | --------------------------------------------------------------------------------------------------------- |
| `total_ceiling_credits` | The most the whole selection can cost. This is the number you restate on confirm.                         |
| `balance_credits`       | What the account holds right now. Below the ceiling means the confirm will be refused `payment_required`. |
| `reserved_credits`      | What other open jobs already hold.                                                                        |
| `remaining_open_jobs`   | How many more jobs the plan allows open at once. Enforced at confirm as `concurrency_limited`.            |
| `entries[].is_cached`   | `true` means a cheap, instant cached read. `false` means a fresh job at the ceiling.                       |
| `excluded[]`            | Everything asked for that is not priced, each with a `reason` from the closed list below.                 |
| `clamps[]`              | Every plan bound that bit: `chart_size`, `episodes_per_show` or `total_selection`.                        |
| `expires_at`            | Fifteen minutes after creation. A confirm after this is `quote_expired`.                                  |

Exclusion reasons: `feed_unavailable`, `feed_unparseable`, `budget_exceeded`,
`music_led`, `no_feed_url`, `duplicate_show`, `chart_size_capped`,
`total_selection_capped`, `no_episodes`, `no_guid`, `no_enclosure`,
`episode_not_in_feed`, `episode_not_found`, `no_declared_duration`,
`no_stable_asset_revision`. A `budget_exceeded` entry means the request ran
out of time reading that feed; quote again with fewer shows.

If everything was excluded the answer is `422 nothing_to_quote` and the
message counts the reasons.

## Confirm the quote

`POST /v1/quotes/{quote_id}/confirm` (operationId `confirmQuote`)

| part                | value                                                                                              |
| ------------------- | -------------------------------------------------------------------------------------------------- |
| path `quote_id`     | From the quote.                                                                                    |
| header `Idempotency-Key` | Required. 1 to 255 printable ASCII characters. A UUID is fine.                               |
| body                | `{ "expected_total_credits": <total_ceiling_credits> }`. An empty body is accepted; any other field is refused. |

Always send `expected_total_credits`. It is the fence: if it disagrees with
the quote's recorded total the API answers `409 expected_total_mismatch`
before anything is probed or reserved.

### What the confirm checks, in order

1. The quote is yours and unexpired: `404 quote_not_found`, `409 quote_expired`.
2. `expected_total_credits` equals the quote's `total_ceiling_credits`:
   `409 expected_total_mismatch`.
3. Every entry's audio is re-probed. A republished episode refuses the whole
   confirm: `409 quote_mismatch`, take a new quote. An entry the probe budget
   did not reach: `409 quote_unverified`, send the same confirm again with
   the same key.
4. The job-bearing members fit the plan's open-job cap:
   `429 concurrency_limited`, naming the cap and the room left.
5. The balance covers the whole ceiling: `402 payment_required`.

### Idempotency

The group is created under the `Idempotency-Key` before any member is
reserved. The same key with the same body returns the original group, in
whatever state it is now, with `200` and charges nothing further. The same
key with a different body is `409 idempotency_conflict`. Keys are kept for
24 hours. Rule: one fresh key per intended confirm, the same key on every
retry of that confirm.

### The response: a job group

```json
{
  "group_id": "grp_...",
  "status": "complete",
  "quote_id": "qte_...",
  "member_count": 2,
  "members": [
    { "kind": "job", "job_id": "job_...", "episode_id": "ep_...", "status": "queued",
      "estimated_credits": 52, "reserved_credits": 65, "created_at": "..." },
    { "kind": "cached_read", "read_id": "job_...", "episode_id": "ep_...",
      "credits_charged": 6, "created_at": "..." }
  ],
  "member_counts": { "validating": 0, "queued": 1, "downloading": 0, "transcribing": 0,
                     "merging": 0, "completed": 0, "failed": 0, "cancelled": 0, "cached_read": 1 },
  "credits_reserved": 65,
  "credits_settled": 6,
  "credits_released": 0,
  "created_at": "...",
  "completion_deadline": "...",
  "completed_at": "...",
  "abandoned_at": null
}
```

Two kinds of member. A `job` member has a `job_id` to poll and holds its
reservation. A `cached_read` member was paid at confirm and has a `read_id`
to read from; there is no job behind it. Keep both ids; they are how you get
the transcripts. `poll-and-read.md` covers what happens next.

A group whose `status` is still `pending` is a confirm still fanning out, or
one that died. Past `completion_deadline` it is swept to `abandoned` and its
reservations come back. Reading the group tells you which.
