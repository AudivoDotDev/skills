# Audivo Skill and Plugins

An [Agent Skill](https://agentskills.io) that teaches your agent the
[Audivo API](https://docs.audivo.dev): send a podcast episode, get its
transcript back, in one call. It also finds shows and episodes, prices a
selection of many episodes before spending, and transcribes audio files and,
with the local MCP server, YouTube episodes.

This repository is also a plugin marketplace with two plugins that bundle the
skill with the [Audivo MCP server](https://github.com/AudivoDotDev/mcp).

## Install as a plugin (Claude Code)

```bash
claude plugin marketplace add AudivoDotDev/skills
claude plugin install audivo@audivo          # hosted server: sign in once with your Audivo account
claude plugin install audivo-local@audivo    # local server: your API key, plus YouTube and files
```

Pick one. `audivo` connects to `https://api.audivo.dev/mcp` and signs you in
through Audivo's OAuth page; it also works on claude.ai and in Cowork.
`audivo-local` runs `npx -y @audivo/mcp` on your machine, asks for your API key
once and keeps it in your system's credential store, and adds YouTube and local
files. See each plugin's README under `plugins/`.

## Install the skill on its own

Once installed, the skill activates on its own when you mention podcast
transcripts, a show or episode, podcast charts, or the Audivo API.

```bash
npx skills add AudivoDotDev/skills
```

### Install for a specific agent

```bash
npx skills add AudivoDotDev/skills -a claude-code
npx skills add AudivoDotDev/skills -a codex
npx skills add AudivoDotDev/skills -a cursor
```

### Install globally

```bash
npx skills add AudivoDotDev/skills -g
```

## Setup

Create an API key in your [Audivo dashboard](https://dash.audivo.dev). The key is
shown once. Export it where your agent runs:

```bash
export AUDIVO_API_KEY="hk_live_..."
```

The skill and its scripts send that key as `Authorization: Bearer` to
`https://api.audivo.dev`. Set `AUDIVO_API_BASE_URL` only if you were told to
use a different base URL.

## What the skill contains

```
skills/audivo/
├── SKILL.md                  # when to trigger, the one flow, the spending rules
├── references/
│   ├── discover.md           # search shows, charts, list episodes
│   ├── poll-and-read.md      # the one call, job states, formats, pages
│   ├── quote-and-confirm.md  # many episodes: price a selection, then spend it once
│   ├── uploads.md            # announce, upload and transcribe your own audio
│   └── errors.md             # every error code and what to do about it
└── scripts/
    ├── transcribe.sh         # one episode, one call: submit, wait, print the transcript
    ├── search.sh             # find shows by name
    ├── episodes.sh           # list a show's episodes
    ├── upload.sh             # announce and upload your own audio file
    ├── quote.sh              # price one or more episodes
    ├── confirm.sh            # confirm a quote (spends credits)
    ├── poll.sh               # read a group or a job
    └── read.sh               # read a paid transcript in any format
```

## Other ways to use Audivo

- **MCP server.** Run `npx -y @audivo/mcp` locally, or point an MCP client at
  the hosted server at `https://api.audivo.dev/mcp`: clients that support MCP
  authorization sign in with your Audivo account; others send your key in the
  `Authorization` header. See [docs.audivo.dev/mcp-server](https://docs.audivo.dev/mcp-server).
- **REST API.** The full reference, with every field, is at
  [docs.audivo.dev](https://docs.audivo.dev).

## Links

- Documentation: https://docs.audivo.dev
- Dashboard: https://dash.audivo.dev
- MCP server: https://github.com/AudivoDotDev/mcp

## License

MIT, see [LICENSE](LICENSE).

## Maintaining

The skill lives once, at `skills/audivo`. Each plugin carries a copy, because a
plugin cannot reach outside its own folder: after editing the skill, run
`scripts/sync-plugins.sh`. CI fails if a copy has drifted.
