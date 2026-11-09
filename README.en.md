# lightcraft-skill

Drive [LightCraft](https://github.com/storytold/lightcraft) from an AI agent. **MCP first, with three fallback paths.**

The primary docs (`SKILL.md`, `examples/prompts.md`) are written in Chinese. This file is the English summary.

## Why

LightCraft ships a genuinely good MCP server (`lightcraft-cli mcp`) and this project uses it. What the official repo does not give you:

1. **A config that actually works** — three flags, each load-bearing (below)
2. **Bugs already stepped on** — `open --args` silently drops flags, `osascript quit` fails with `-10004`, `max_side` vs `maxSize` naming inconsistency…
3. **Fallback paths** — CLI and the raw socket still work when MCP is unavailable or unwanted
4. **A way to talk to the user** — `examples/prompts.md`, a four-slot prompt formula. Great tooling still collapses on "make it look better"

`references/` come unmodified from [ai-2070/claude-storytold-skills](https://github.com/ai-2070/claude-storytold-skills).

## The config

```json
{
  "mcpServers": {
    "lightcraft": {
      "command": "/usr/local/bin/lightcraft-cli",
      "args": ["mcp", "--connect", "7980", "--compact"]
    }
  }
}
```

| Flag | If you drop it |
|---|---|
| `--connect 7980` | cannot reach the App you are looking at; use `--library DIR` for a standalone library (no library flag at all = **in-memory, edits lost on exit**) |
| `--compact` | **tool count jumps from 28 to 628** (600 `cmd_*` wrappers) and burns context. Nothing is lost — `command_run` still reaches every command |

`--connect` degrades gracefully: if the App is not up it just logs `will retry on each call` and keeps serving, so the server can stay in your config permanently.

Two startup traps:

```bash
# BAD: LaunchServices often swallows the flag -- app starts, port stays closed
open -a "LightCraft" --args --control 7980

# GOOD: run the binary directly
"/Applications/LightCraft.app/Contents/MacOS/LightCraft" --control 7980 &
```

Kill it with `pkill -TERM -f "LightCraft.app/Contents/MacOS/LightCraft"`. `osascript -e 'quit app "LightCraft"'` fails with `-10004` (privilege violation).

## Paths and how you see the frame

| Path | How you see the frame | Best for |
|---|---|---|
| official MCP, `--compact` + `--connect` | `render_preview` (photo) / `ui_screenshot` (window) return images in one call | everyday editing — **default** |
| `lightcraft-cli` headless | `render` to a file | batch, cron, unattended runs |
| control channel via `scripts/lc.py` | `ui.screenshot` to a PNG | fallback when MCP is unavailable |

Two more bits:

- `scripts/which-mode.sh` — every path produces identical output, so it answers "which one actually ran last" by comparing the `catalog.snap` mtime in each library. Give the CLI its own library and the evidence is unambiguous.
- `scripts/lc.py` — a ~100-line stdlib-only client for the socket. Nothing to install.

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
| MCP tools | **28** (`--compact`); 628 without it |
| platform | macOS |

These numbers come from one machine — re-check on yours. Linux, Windows, and LightCraft &lt; 0.19 are untested.

## Scope

Not a Lightroom replacement (LightCraft is), not generative retouching (denoise, upscaling, portrait smoothing are a different pipeline), and it never touches your originals — imports are references, edits live in the LightCraft library.

## License

MIT. `references/*.md` are unmodified copies from [ai-2070/claude-storytold-skills](https://github.com/ai-2070/claude-storytold-skills) (MIT, Copyright © 2026 V and contributors) — see [LICENSE](LICENSE).

Contributions most wanted: cross-platform testing, command diffs across LightCraft versions.
