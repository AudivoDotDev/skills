# Audivo Skill

An [Agent Skill](https://agentskills.io) that teaches your coding agent the
[Audivo API](https://docs.audivo.dev): find a podcast show, list its episodes,
price a transcript, confirm the spend, poll the job, and read the transcript
as JSON, plain text, SRT, VTT or Markdown.

Once installed, the skill activates on its own when you mention podcast
transcripts, a show or episode, podcast charts, or the Audivo API.

## Install

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

Create an API key in your [Audivo dashboard](https://audivo.dev). The key is
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
│   ├── quote-and-confirm.md  # price a selection, then spend it once
│   ├── poll-and-read.md      # group and job states, transcript formats
│   └── errors.md             # every error code and what to do about it
└── scripts/
    ├── search.sh             # find shows by name
    ├── episodes.sh           # list a show's episodes
    ├── quote.sh              # price one or more episodes
    ├── confirm.sh            # confirm a quote (spends credits)
    ├── poll.sh               # read a group or a job
    └── read.sh               # read a paid transcript in any format
```

## Other ways to use Audivo

- **MCP server.** Run `npx -y @audivo/mcp` locally, or point an MCP client at
  the hosted server at `https://api.audivo.dev/mcp` with your key in the
  `Authorization` header. See [docs.audivo.dev/mcp-server](https://docs.audivo.dev/mcp-server).
- **REST API.** The full reference, with every field, is at
  [docs.audivo.dev](https://docs.audivo.dev).

## Links

- Documentation: https://docs.audivo.dev
- Dashboard: https://audivo.dev
- MCP server: https://github.com/AudivoDotDev/mcp

## License

MIT, see [LICENSE](LICENSE).
