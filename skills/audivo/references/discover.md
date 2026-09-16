# Discover: search, charts, episodes

Three read-only operations. None of them spends credits today. All take
`Authorization: Bearer $AUDIVO_API_KEY` and answer JSON.

## Search shows by name

`GET /v1/search/shows` (operationId `searchShows`)

| query param | required | meaning                                          |
| ----------- | -------- | ------------------------------------------------ |
| `q`         | yes      | Free text, 1 to 200 characters.                  |
| `limit`     | no       | How many entries come back. 1 to 100, default 20 |

The provider decides which shows match. Audivo decides the order: an exact
title match first, then titles that start with the query, then titles that
contain it as whole words, then the rest. Within each band the larger
catalogue wins, then a show with an Apple listing. "The" at the start of a
title and punctuation are ignored when comparing.

Response `ShowSearchResponse`:

```json
{
  "data": [ ShowSummary, ... ],
  "excluded": [ { "title": "...", "reason": "no_feed_url", "detail": "..." } ],
  "next_cursor": null
}
```

`next_cursor` is always `null` here. The provider does not page this call.

## A category chart

`GET /v1/charts` (operationId `getChart`)

| query param | required | meaning                                                             |
| ----------- | -------- | ------------------------------------------------------------------- |
| `category`  | yes      | A provider category name, for example `Business` or `Technology`.   |
| `size`      | no       | How many shows you want. 1 to 100, default 10. Clamped to the plan. |
| `language`  | no       | A BCP-47 tag to restrict the chart to one language.                 |

The plan's chart cap is applied before the provider is called. The clamp is
always reported, whether or not it changed anything:

```json
{
  "category": "Business",
  "language": null,
  "size": { "requested": 40, "allowed": 10, "limit": 10, "clamped": true },
  "data": [ ShowSummary, ... ],
  "excluded": [ ... ]
}
```

Chart caps per plan: free 10, hobby 20, startup 30, growth 40, scale 50.

## What a show looks like

`ShowSummary` is the shape both search and charts return:

| field             | meaning                                                                             |
| ----------------- | ----------------------------------------------------------------------------------- |
| `show_id`         | Canonical id, `sh_` plus 16 characters. Stable across search, chart and quote.      |
| `title`           | The publisher's title. Display text, never an input.                                |
| `feed_url`        | The RSS feed. This is what you pass to quote and to the episode list.               |
| `itunes_id`       | Apple collection id, or `null`. Pass it along when present; it changes `show_id`.   |
| `author`          | The provider's author string, or `null`.                                            |
| `categories`      | Provider category names, provider order.                                            |
| `artwork_url`     | Cover art URL, or `null`.                                                           |
| `music_led`       | `true` when the provider's categories say the show is music, not talk.              |
| `music_led_basis` | Why `music_led` is what it is, in words you can show.                               |

A music-led show is marked, never hidden, on search and charts. A quote
built from a chart drops music-led shows unless `include_music_led: true`.
A quote built from named shows takes every show as chosen.

`excluded` lists provider entries that carry no usable feed URL. There is
nothing to select for those, so they are named instead of dropped.

## List a show's episodes

`GET /v1/shows/{show_id}/episodes` (operationId `listShowEpisodes`)

| param       | in    | required | meaning                                                              |
| ----------- | ----- | -------- | -------------------------------------------------------------------- |
| `show_id`   | path  | yes      | From a `ShowSummary`.                                                |
| `feed_url`  | query | yes      | The same show's `feed_url`. A `show_id` cannot be turned back into a feed. |
| `itunes_id` | query | no       | The same show's `itunes_id` when it is not `null`. Required for the id to match. |
| `limit`     | query | no       | 1 to 100, default 20.                                                |
| `cursor`    | query | no       | `next_cursor` from the previous page. Opaque.                        |

The handler re-derives `show_id` from `feed_url` and `itunes_id` and refuses
the request when it does not match the path. So send all three exactly as
the search or chart gave them.

Response `EpisodesListResponse`, newest first:

```json
{
  "data": [
    {
      "episode_id": "ep_...",
      "show_id": "sh_...",
      "guid": "...",
      "title": "...",
      "published_at": "2026-09-01T06:00:00Z",
      "duration_sec": 3841,
      "publisher_transcript_available": false,
      "is_cached": null,
      "estimated_credits": 65
    }
  ],
  "next_cursor": "..."
}
```

| field                            | meaning                                                                      |
| -------------------------------- | ---------------------------------------------------------------------------- |
| `episode_id`                     | Canonical id, `ep_` plus 16 characters. Pass it in a quote's `episode_ids`.  |
| `guid`                           | The feed's own item GUID. Used verbatim by `POST /v1/transcripts`.           |
| `duration_sec`                   | Feed-published length in seconds, or `null` if the feed does not say.        |
| `is_cached`                      | Always `null` on a listing. A listing does not probe the audio. The quote does. |
| `estimated_credits`              | Rough cost to transcribe fresh, from the declared duration, or `null`.       |
| `publisher_transcript_available` | Whether the feed advertises its own transcript. Not used by the pipeline yet. |

Page with `cursor` until `next_cursor` is `null`.

## Resolve one pointer without a job

`GET /v1/resolve` (operationId `resolvePointer`)

Exactly one of `url` (an Apple Podcasts episode link) or `feed_url` plus
`guid`. Returns `episode_id`, `show_id`, `is_cached` and, when known,
`estimated_credits`, `quote_basis`, `estimated_seconds`. Supplying neither,
both, or half a pair is `400 invalid_request`. Spotify, YouTube and raw
audio are `422 source_not_supported`.

## Errors you will meet here

- `400 invalid_request`: a parameter is missing or out of range, or `show_id`
  does not match `feed_url` and `itunes_id`.
- `404 show_not_found` on the episode list when the show cannot be resolved.
- `503 discovery_unavailable`: the show directory did not answer. Retry.
- `429 rate_limited`: over the plan's requests per minute. Wait for
  `Retry-After`.

Full list in `errors.md`.
