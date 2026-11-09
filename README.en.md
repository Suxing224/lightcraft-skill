# lightcraft-skill

Drive [LightCraft](https://github.com/storytold/lightcraft) from an AI agent — **no MCP server, no Node service, no glue code**.

The primary docs (`SKILL.md`, `examples/prompts.md`) are written in Chinese. This file is the English summary.

## Why

Every existing agent integration for LightCraft goes through MCP and requires installing `lightcraft-cli` plus an MCP client. This project keeps the CLI path but adds a second one: it talks straight to the JSON-lines control socket that `lightcraft --control PORT` opens on `127.0.0.1`.

That matters because **the two paths see different things**:

| Path | Can see the frame? | Best for |
|---|---|---|
| `lightcraft-cli` (headless) | No | batch, cron, unattended runs |
| control channel (`--control PORT`) | **Yes** — `ui.screenshot` | precise single-photo edits |

Editing colour blind is a gamble. Use the channel when judgement is needed, the CLI when it is not.

Two more bits:

- `scripts/which-mode.sh` — both paths produce identical output, so it answers "which one actually ran last" by comparing the `catalog.snap` mtime in each library. Give the CLI its own library and the evidence is unambiguous.
- `scripts/lc.py` — a 61-line stdlib-only client for the socket. Nothing to install.

## Install

```bash
# WorkBuddy (per workspace)
git clone https://github.com/<you>/lightcraft-skill.git .workbuddy/skills/lightcraft

# Claude Code (per user)
git clone https://github.com/<you>/lightcraft-skill.git ~/.claude/skills/lightcraft
```

Any agent that can read a `SKILL.md` as context will work — just point it here.

## Requirements

LightCraft desktop App, or `lightcraft-cli`, or both. Get the CLI from the [releases page](https://github.com/storytold/lightcraft/releases) (`lightcraft-cli-<ver>-macos-universal.zip`).

```bash
open -a "LightCraft" --args --control 7980
python3 scripts/lc.py '{"id":1,"method":"ui.inspect"}'
bash scripts/which-mode.sh
```

## Verified on

| | |
|---|---|
| LightCraft App / CLI | 0.19.0 |
| headless commands | 389 |
| develop controls | 122 |
| platform | macOS |

These numbers come from one machine — re-check on yours. Linux, Windows, and LightCraft &lt; 0.19 are untested.

## Scope

Not a Lightroom replacement (LightCraft is), not generative retouching (denoise, upscaling, portrait smoothing are a different pipeline), and it never touches your originals — imports are references, edits live in the LightCraft library.

## License

MIT. `references/*.md` are unmodified copies from [ai-2070/claude-storytold-skills](https://github.com/ai-2070/claude-storytold-skills) (MIT, Copyright © 2026 V and contributors) — see [LICENSE](LICENSE).

Contributions most wanted: cross-platform testing, command diffs across LightCraft versions.
