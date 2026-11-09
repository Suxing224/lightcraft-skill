# lightcraft-skill

**English** · [简体中文](README.zh-CN.md)

Drive [LightCraft](https://github.com/storytold/lightcraft) from an AI agent. **MCP first, with three fallback paths.**

What you get here that the official repo does not: a config that actually works, the traps we already stepped on, and a prompt formula for talking to the person behind the keyboard.

```
You:    adjust ~/Pictures/x.jpg — it's hazy, I want it crisp and cold
Agent:  (import → read EXIF → set controls → preview → iterate → export)
        here's the result
```

## Why this exists

LightCraft ships a genuinely good MCP server (`lightcraft-cli mcp`), and this project uses it. It reaches the whole engine plus a 122-control develop surface. What it does not give you:

1. **A config that works on the first try** — three flags, each one load-bearing
2. **Bugs already stepped on** — `open --args` silently drops flags, `osascript quit` fails with `-10004`, `max_side` vs `maxSize`…
3. **Fallback paths** — the CLI and the raw socket still earn their keep when MCP is unavailable, unsupported by your client, or just overkill
4. **A way to talk to the user** — `examples/prompts.md`, a four-slot prompt formula. Good tooling still collapses on "make it look better"

`references/` are unmodified copies from [ai-2070/claude-storytold-skills](https://github.com/ai-2070/claude-storytold-skills).

## The config: three flags, none optional

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
| `--connect 7980` | You cannot reach the App you are looking at. Swap for `--library DIR` for a standalone library — and note that **no library flag at all means an in-memory library, so every edit is lost on exit** |
| `--compact` | **Tool count jumps from 28 to 628** (600 `cmd_*` wrappers) and burns your context for zero extra reach — `command_run` still gets to every command |

`--connect` degrades gracefully: with the App down it logs `will retry on each call` and keeps serving, so the server can sit in your config permanently.

## Two startup traps

```bash
# BAD: LaunchServices often swallows the flag — App starts, port stays closed
open -a "LightCraft" --args --control 7980

# GOOD: run the binary directly, the flag always gets through
"/Applications/LightCraft.app/Contents/MacOS/LightCraft" --control 7980 &
```

To shut it down use `pkill -TERM -f "LightCraft.app/Contents/MacOS/LightCraft"`. `osascript -e 'quit app "LightCraft"'` fails with `-10004` (privilege violation) and leaves the App running.

## Four paths, and how each one sees the frame

| Path | How you see the frame | Best for |
|---|---|---|
| official MCP, `--connect --compact` | `render_preview` (photo) and `ui_screenshot` (window) return images in one call | everyday editing — **the default** |
| official MCP, `--library DIR` | same, against a standalone library | batch work that must persist |
| `lightcraft-cli` headless | `render` to a file | cron, CI, unattended runs |
| control channel via `scripts/lc.py` | `ui.screenshot` to a PNG | MCP unavailable, zero config, no resident process |

Two details worth knowing:

- `scripts/which-mode.sh` — every path produces identical pixels, so it answers "which one actually ran last" by comparing the `catalog.snap` mtime in each library. Give the CLI its own library and the evidence is unambiguous.
- `scripts/lc.py` — a ~100-line stdlib-only client for the JSON-lines socket. Nothing to install, no config file.

## Install

Two steps: clone into your skills directory, then merge the `mcpServers` block above into your `mcp.json`. **Restart the session** for MCP to load.

```bash
# WorkBuddy (per workspace)
git clone https://github.com/Suxing224/lightcraft-skill.git .workbuddy/skills/lightcraft

# Claude Code (per user)
git clone https://github.com/Suxing224/lightcraft-skill.git ~/.claude/skills/lightcraft
```

MCP is not mandatory. Any agent that can read a `SKILL.md` as context will work — point it at the file and skip the config entirely.

## Requirements

At least one of: the desktop App, or `lightcraft-cli`. Both is better — MCP needs the CLI, the control channel needs the App.

```bash
# CLI — grab lightcraft-cli-<ver>-macos-universal.zip from the releases page
unzip lightcraft-cli-*.zip
cp */lightcraft-cli /usr/local/bin/ && chmod +x /usr/local/bin/lightcraft-cli

# Desktop App — run the binary directly, not via open --args
"/Applications/LightCraft.app/Contents/MacOS/LightCraft" --control 7980 &
```

## Verify it works

```bash
# 1. Is the control port actually open? Probe it — do not trust lsof
python3 -c "import socket;s=socket.socket();print('open' if not s.connect_ex(('127.0.0.1',7980)) else 'closed')"

# 2. Which path ran last, and can you edit right now?
bash scripts/which-mode.sh

# 3. Render one photo without going through MCP
lightcraft-cli render in.jpg -o out.jpg --set effects.dehaze=15 --size 1600
```

For MCP, check your session's tool list for these 28: `query_photos`, `select_photos`, `set_develop`, `render_preview`, `ui_screenshot`, …

## Verified on

Every number in this README and in `SKILL.md` comes from one machine. **Re-check on yours.**

| | |
|---|---|
| LightCraft App / CLI | 0.19.0 |
| headless commands | 389 |
| develop controls | **122** (matches the upstream 0.9.1 docs — unchanged in two years) |
| MCP tools | **28** with `--compact`; 628 without it |
| platform | macOS |

Untested: Linux, Windows, LightCraft &lt; 0.19, and AI masks (they need the SAM 3 model, ~3.4 GB).

## What it is not

- **Not a Lightroom replacement** — LightCraft is; this only drives it
- **Not generative retouching** — denoise, upscaling, portrait smoothing and old-photo repair are a different pipeline
- **Never touches your originals** — imports are references, edits live in the LightCraft library and can be reverted at any time

## Layout

```
SKILL.md                 the main doc an agent reads (Chinese)
references/
  controls.md            122 develop controls: ids and ranges
  commands.md            371 command signatures
scripts/
  lc.py                  control-channel client (no deps, MCP fallback)
  which-mode.sh          CLI / App path self-check
examples/
  prompts.md             how to ask a user for a usable prompt
```

## Known limits

- Command argument formats are verified on 0.19 and may drift — check with `lightcraft-cli run engine.commands` first
- `which-mode.sh` relies on the CLI having **its own library**; share one library and the mtime tells you nothing
- The control port has no authentication and binds to loopback only. Close the App when you are done
- MCP config changes need a session restart; `--connect` needs the App running with `--control`

## License

MIT. `references/*.md` are unmodified copies from [ai-2070/claude-storytold-skills](https://github.com/ai-2070/claude-storytold-skills) (MIT, Copyright © 2026 V and contributors). Attribution in [LICENSE](LICENSE).

## Contributing

The most useful thing you can send is **a report from a different environment**: Linux or Windows path and process detection, command diffs on 0.18 and older, filename handling under non-UTF-8 locales. Open an issue with your version and platform.
