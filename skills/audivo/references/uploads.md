# Uploads

For audio Audivo cannot reach on its own: your own recording, or audio you
obtained yourself and hold the rights to transcribe (for example with
`yt-dlp`, from a Spotify- or YouTube-only show). Audivo's servers never
fetch from YouTube or Spotify; you bring the bytes. For everything reachable
by feed or Apple link, use `references/discover.md` and
`references/quote-and-confirm.md` instead — an upload costs the same as a
fresh job and skips no rule.

An upload is three calls: announce it, PUT the bytes, then quote it like any
other entry. `scripts/upload.sh` does the first two and prints what the
third needs.

## 1. Announce the file

`POST /v1/uploads` (operationId `createUpload`)

```json
{
  "sha256": "3f8a9c2b1d4e9f2c1d4e9f2c1d4e9f2c3f8a9c2b1d4e9f2c1d4e9f2c1d4e9f2c",
  "bytes": 28934112,
  "content_type": "audio/mpeg",
  "declared_duration_seconds": 1807.4,
  "title": "Interview take two"
}
```

| field                       | meaning                                                                                    |
| ---------------------------- | ------------------------------------------------------------------------------------------- |
| `sha256`                    | Required. Lowercase hex, 64 characters. The PUT is signed against it; a body that hashes differently is refused by S3 with `BadDigest`. |
| `bytes`                     | Required. The file's exact length, 1 to 5368709120 (5 GiB). The PUT must carry the same `Content-Length`. |
| `content_type`               | Required. One of `audio/mpeg`, `audio/mp3`, `audio/mp4`, `audio/m4a`, `audio/x-m4a`, `audio/aac`, `audio/x-aac`, `audio/ogg`, `audio/opus`, `audio/flac`, `audio/x-flac`, `audio/wav`, `audio/x-wav`, `audio/webm`. |
| `declared_duration_seconds`  | Required. Above 0, at most 36000 (10 hours). What the quote prices from; see "The declared-duration ceiling" below. |
| `title`                      | Optional, 1 to 300 characters. How the entry is labelled. The show it appears under is always `"Uploads"`; this only labels the episode. |

`content_type` is not guessed from the file; state it. `scripts/upload.sh`
derives it from the extension: `mp3` to `audio/mpeg`, `m4a`/`mp4` to
`audio/mp4`, `aac` to `audio/aac`, `ogg`/`oga` to `audio/ogg`, `opus` to
`audio/opus`, `flac` to `audio/flac`, `wav` to `audio/wav`, `webm` to
`audio/webm`.

Response `201 UploadCreated`:

```json
{
  "upload_id": "upl_7c1f0a9b3e2d4c5b6a7f8e9d",
  "put_url": "https://...s3.us-east-1.amazonaws.com/...",
  "put_headers": {
    "content-type": "audio/mpeg",
    "content-length": "28934112",
    "x-amz-checksum-sha256": "P4qcKx1OnywdTp88HU6fLD+KnCsdTp8sHU6fLB1Onyw="
  },
  "put_url_expires_at": "2026-09-17T11:00:00Z",
  "retained_until": "2026-09-24T10:00:00Z",
  "bytes": 28934112,
  "content_type": "audio/mpeg",
  "declared_duration_seconds": 1807.4,
  "title": "Interview take two"
}
```

| field                | meaning                                                                                       |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| `upload_id`           | `upl_` plus 16 to 32 characters. Name it in a quote as `uploads: [{ upload_id }]`.              |
| `put_url`             | Presigned `PUT`. Expires one hour after the announcement (`put_url_expires_at`).                |
| `put_headers`         | Every header the PUT must carry, verbatim, and nothing else. They are part of the URL's signature, not a suggestion. Note `x-amz-checksum-sha256` is base64, not the hex `sha256` you sent; you never compute it yourself, only replay what came back. |
| `put_url_expires_at`  | One hour from the announcement.                                                                 |
| `retained_until`      | Seven days from the announcement. A quote naming this upload after that is `upload_not_found`.  |

## 2. Send the bytes

`PUT` the file to `put_url` with exactly the headers in `put_headers` and no
others:

```bash
curl -sS --fail-with-body -X PUT -T "$FILE" \
  -H "content-type: audio/mpeg" \
  -H "content-length: 28934112" \
  -H "x-amz-checksum-sha256: P4qcKx1OnywdTp88HU6fLD+KnCsdTp8sHU6fLB1Onyw=" \
  "$PUT_URL"
```

The API never reads the bytes; S3 checks them against the signature. A
mismatched hash is refused at the PUT with `BadDigest`, not later at quote
time. There is no retry built into `scripts/upload.sh`: a failed PUT means
announce again and PUT the fresh URL.

## 3. Quote it

Name the `upload_id` in a quote, the same operation as everything else
(`references/quote-and-confirm.md`):

```json
{ "uploads": [{ "upload_id": "upl_7c1f0a9b3e2d4c5b6a7f8e9d" }] }
```

1 to 100 uploads per quote. This is `QuoteFromUploads`, one of the three
quote shapes (`shows`, `chart`, `uploads`) — send exactly one, and an
uploads quote has no `episodes_per_show`. Each upload is verified with one
object head (present, the declared length, the declared hash) and priced
from `declared_duration_seconds`. The resulting `QuoteEntry` looks like any
other, with these differences:

| field                        | value for an upload                                                              |
| ----------------------------- | ----------------------------------------------------------------------------------- |
| `show_title`                 | Always `"Uploads"`.                                                                |
| `episode_title`               | Your `title`, or `null` if you sent none.                                          |
| `published_at`                | Always `null`.                                                                      |
| `quote_basis`                 | Always `declared`: priced from what you stated, not from a feed or a probe.        |
| `feed_url`                    | The account's private `audivo://uploads/…` pointer. Not a real feed.               |
| `upload_id`                   | Present. This is how you tell an upload entry apart from a feed one.                |
| `declared_duration_seconds`   | Echoes what you announced.                                                          |

Everything past this point — `total_ceiling_credits`, `confirm`, polling the
group, reading the transcript — is identical to a feed-sourced job. An
upload's transcript is cached for your account alone; it is never shared
with or priced cheaper for another account the way a public episode's is.

## The declared-duration ceiling

The quote's ceiling is reserved from `declared_duration_seconds`, the number
you sent, not a measurement. If the file actually runs longer than that once
the job processes it, the job fails rather than silently reserving more: it
lands `status: failed` with `error.code: processing_failed`, and its message
says the audio ran past the ceiling reserved for its declared duration (the
spec's own name for this failure is `declared_duration_exceeded`). The
reservation is released, same as any other failed job. Declare the real
duration; when in doubt, round up.

## Limits

| limit                                   | value                                    |
| ----------------------------------------- | ------------------------------------------- |
| File size                                 | 1 byte to 5 GiB (5368709120 bytes)         |
| Declared duration                         | above 0 seconds, at most 36000 (10 hours)  |
| Title                                     | 1 to 300 characters, optional               |
| Presigned PUT URL lifetime                 | one hour from announcement                  |
| Upload retention                          | seven days from announcement (`retained_until`) |
| Account allowance                         | 10 GiB across 100 unexpired announcements at once |

An announcement counts against the account allowance the moment it is made,
whether or not a file ever arrives. Capacity returns as announcements pass
`retained_until`; there is no way to release one early. Over the allowance,
`POST /v1/uploads` answers `429 upload_quota_exceeded` before a PUT URL is
even issued. See `errors.md`.

## Quoting an upload that is not there, or is wrong

An upload that fails its check is not a request error: the quote still
answers `200` and the upload comes back in `excluded[]` with one of three
reasons, the same closed vocabulary every other exclusion uses:

| reason                 | meaning                                                                                       |
| ------------------------ | ------------------------------------------------------------------------------------------------ |
| `upload_not_found`      | The `upload_id` is unknown, belongs to another account, or is past `retained_until`. Announce again. |
| `upload_not_received`   | The announcement exists but nothing has landed at the bucket key yet. Send the PUT, then quote again. |
| `upload_mismatch`       | What landed does not match the announced length or hash. Announce again with the correct file.    |
