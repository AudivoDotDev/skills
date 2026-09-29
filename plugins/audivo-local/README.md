# Audivo (local, with YouTube)

Podcast transcripts in one call, through the Audivo MCP server running on your
own machine. Everything the hosted `audivo` plugin does, plus two things only a
local process can: transcribe a YouTube episode, downloaded on your machine with
yt-dlp, and transcribe an audio file on your disk. For Claude Code.

## Use it

Install the plugin; Claude Code asks once for your Audivo API key (create one at
[dash.audivo.dev](https://dash.audivo.dev)) and keeps it in your system's secure
credential store. The server starts with `npx -y @audivo/mcp`, so Node.js 22 or
later must be installed. Then ask:

- "Transcribe https://podcasts.apple.com/... and summarise it."
- "Find the Costco episode of Acquired on YouTube and transcribe it."
- "Transcribe ~/Downloads/interview.m4a."

## YouTube

The first YouTube request uses the `yt-dlp` on your `PATH` if you have one;
otherwise the server downloads yt-dlp's official standalone release for your
platform into your user cache directory, once, and checks it against the
release's published SHA-256 checksums before running it. Only the audio is
downloaded, it is uploaded to Audivo as your own upload, and its transcript is
private to your account. You are responsible for having the rights to
transcribe what you download.

## Cost and data

Transcription spends Audivo credits: about one per audio minute. The plugin
sends the episodes you ask for, your search terms, and the audio of any file or
YouTube video you transcribe to Audivo at `https://api.audivo.dev`, with your
API key. See the [privacy policy](https://audivo.dev/privacy) and
[terms](https://audivo.dev/terms).
