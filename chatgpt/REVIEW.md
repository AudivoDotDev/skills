# Submitting Audivo to OpenAI's plugin directory

Everything OpenAI's review asks for that does not live in `plugin.json`.
This file is not in the ZIP (`scripts/build-chatgpt.mjs` packs only the
manifest, `mcp.json`, `assets/` and `skills/`).

## Annotation justifications

The dashboard imports each tool's annotations from the server's scan and
asks why each value is right. Paste these. The values are the ones
`@audivo/mcp` 0.4.0 advertises on `https://api.audivo.dev/mcp`.

| Tool | Read-only | Destructive | Open-world | Justification |
| --- | --- | --- | --- | --- |
| `transcribe` | false | true | true | Creates a transcription job and spends credits from the user's Audivo account, which cannot be undone, so it is a write and destructive. It downloads audio from the public podcast feed named by the request, an open-ended set of publishers, so it is open-world. Repeating the same call returns the same job and never charges twice. |
| `search_shows` | true | false | true | Searches the public podcast directory and returns shows; it changes nothing. The results are public, publisher-authored content from anywhere, so it is open-world. |
| `chart_shows` | true | false | true | Reads a public podcast category chart; it changes nothing. The shows are public, publisher-authored content, so it is open-world. |
| `list_episodes` | true | false | true | Reads a show's public feed and lists its episodes with estimated prices; it changes nothing and spends nothing. The feed is any publisher's, so it is open-world. |
| `quote` | false | false | true | Prices a selection of episodes and records the quote so a later `confirm` can be checked against it. Recording the quote is a write, so it is not read-only; it spends and reserves nothing and deletes nothing, so it is not destructive. It reads public feeds from any publisher, so it is open-world. |
| `confirm` | false | true | false | Turns a quote into transcription jobs and reserves credits for them, an irreversible spend, so it is a destructive write. It is refused unless the caller restates the quoted total. It acts only on the user's own account and quotes, so it is not open-world. |
| `group_status` | true | false | false | Reads the state of one of the user's own job groups and previews finished transcripts; it changes nothing. Confined to the user's account. |
| `list_groups` | true | false | false | Lists the user's own job groups; it changes nothing. Confined to the user's account. |
| `cancel_group` | false | true | false | Cancels the user's jobs that have not started and releases their reserved credits. A cancellation cannot be undone, so it is a destructive write. Confined to the user's own groups. |
| `read_transcript` | true | false | false | Reads a transcript the user already has, a page at a time, or waits for one of their jobs to finish. It charges nothing and changes nothing. Confined to the user's account. |
| `list_transcripts` | true | false | false | Lists the user's own recent transcripts with their titles; it changes nothing and charges nothing. Confined to the user's account. It is also the app's sidebar and conversation-tab entrypoint. |

**UI resource:** `ui://audivo/app-v1.html`, one self-contained page with
inline script and styles. It declares no connect, resource or frame
domains and embeds no iframe, so there is no domain or iframe to justify.

## Reviewer credentials (Review details)

Create a dedicated account at `https://dash.audivo.dev/signup` with email
and password (not Google), verify the address once, and give it credits.
Before submitting, run positive case 2 with it once, so its library already
holds a transcript if reviewers run the cases out of order.

Enter in **Review details**:

- **Login URL:** `https://dash.audivo.dev/signin`
- **Email / password:** the reviewer account's
- **Sign-in instructions:** Connecting Audivo in ChatGPT opens Audivo's
  sign-in page. Sign in with the email and password above (no MFA, no
  codes). On Audivo's next page, which asks to connect the app, choose
  Allow.
  The account has credits for the test cases; transcribing spends them,
  and everything else is free. Keep this account; it is used for later
  reviews too.

## Screenshots

One per starter prompt, in the same order, PNG or JPEG, **706 pixels wide
and 400–860 tall**:

1. `screenshot-1.png`: "Transcribe the latest episode of Hard Fork and
   summarize it…", showing the transcript reader beside the summary.
2. `screenshot-2.png`: "Find the Acquired episode about Costco and quote…",
   showing the quotes with timestamps and the reader.
3. `screenshot-3.png`: "Show my Audivo transcripts.", showing the library.

Capture them in the ChatGPT desktop app, then size each one and save it
into `assets/`:

```bash
sips --resampleWidth 706 ~/Desktop/shot.png --out chatgpt/assets/screenshot-1.png
sips -g pixelHeight chatgpt/assets/screenshot-1.png         # must be 400-860
sips --cropToHeightWidth 860 706 chatgpt/assets/screenshot-1.png   # only if it is taller
```

Then add to `interface` in `plugin.json`:

```json
"screenshots": ["./assets/screenshot-1.png", "./assets/screenshot-2.png", "./assets/screenshot-3.png"]
```

## Demo video

OpenAI wants the main use cases and tools shown "across supported
platforms", so record on the desktop app and on a phone. About three minutes:

1. Connect Audivo and sign in (the consent page, then Allow).
2. Positive cases 1 to 5 from `plugin.json`, in order: the reader appearing,
   a running job filling in, the library, quotes with timestamps, a price
   with nothing spent.
3. Open the library from the sidebar, open a transcript, search inside it.
4. One negative case (the Spotify link), refused with nothing spent.
5. On a phone: one transcript request and the reader.

Upload it unlisted (YouTube or Loom) and either put the link in
`plugin.json` as `review.demo_recording_url` or enter it in the dashboard.
