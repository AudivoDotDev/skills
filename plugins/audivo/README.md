# Audivo

Podcast transcripts in one call. Ask for an episode by name, Apple Podcasts
link or RSS feed, and Audivo transcribes it and hands the transcript back, a
page at a time, so you can summarise it, pull quotes, or search what was said.
An episode someone already transcribed comes back at once.

## Use it

Install the plugin, then connect the **Audivo** connector and sign in to your
Audivo account (create one free at [audivo.dev](https://audivo.dev)). Then ask:

- "Transcribe the latest episode of Acquired and summarise it."
- "Find the Hard Fork episode about AI regulation and quote what they said about the EU."
- "What did the last three episodes of The Daily cover?"

For many episodes at once, such as a category chart or a show's back catalogue,
the model prices the selection first and asks you before it spends.

## Cost

Transcription spends Audivo credits from your account: about one credit per
audio minute, and a tenth of that for an episode another account already
transcribed. The free plan includes 120 credits. You can see and revoke the
connection under **Connected apps** in the [dashboard](https://dash.audivo.dev).

## Data

The plugin sends the episode you ask for (a link, a feed, or an id) and your
search terms to Audivo through `https://api.audivo.dev/mcp`, authorised by the
connection you approved. Audivo fetches the public episode audio from its
publisher and transcribes it; transcripts of public episodes are cached and
may be read by other accounts. See the [privacy policy](https://audivo.dev/privacy)
and [terms](https://audivo.dev/terms).

YouTube episodes and audio files on your disk need the local server; see the
`audivo-local` plugin in this marketplace.
