#!/usr/bin/env bash
# Which path did the last edit take -- CLI (headless) or the App control channel?
# And which path is usable right now?
#
# Usage:
#   bash which-mode.sh
#
# Config (env vars, all optional):
#   LC_PORT          control port                     (default 7980)
#   LC_DESKTOP_LIB   library the desktop App opens     (default ~/Pictures/LightCraft Library)
#   LC_BATCH_LIB     library you point the CLI at      (default ~/Pictures/lc-batch)
#
# Why it works: the two paths write to two different libraries. Every edit
# touches catalog.snap, so whichever library has the newer stamp did the work.
set -u

PORT="${LC_PORT:-7980}"
DESKTOP_LIB="${LC_DESKTOP_LIB:-$HOME/Pictures/LightCraft Library}"
BATCH_LIB="${LC_BATCH_LIB:-$HOME/Pictures/lc-batch}"

# BSD (macOS) uses stat -f, GNU uses stat -c. Try both.
stamp_mtime() {
  stat -f "%m" "$1" 2>/dev/null || stat -c "%Y" "$1" 2>/dev/null || echo 0
}
stamp_human() {
  stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$1" 2>/dev/null \
    || stat -c "%y" "$1" 2>/dev/null | cut -d. -f1 \
    || echo "(none)"
}

echo "======== status ========"

APP_PID=$(pgrep -f "LightCraft\.app/Contents/MacOS/LightCraft" 2>/dev/null | head -1)
if [ -n "${APP_PID:-}" ]; then
  echo "app process   : running (pid $APP_PID)"
else
  echo "app process   : not running"
fi

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "control port  : open (127.0.0.1:$PORT) -- App channel usable, screenshots available"
else
  echo "control port  : closed -- App channel unusable"
fi

CLI_BIN=$(command -v lightcraft-cli 2>/dev/null)
if [ -n "$CLI_BIN" ]; then
  echo "cli binary    : $CLI_BIN"
else
  echo "cli binary    : not found in PATH"
fi

echo
echo "======== which library was written last ========"

D_MT=$(stamp_mtime "$DESKTOP_LIB/catalog.snap" 2>/dev/null)
B_MT=$(stamp_mtime "$BATCH_LIB/catalog.snap" 2>/dev/null)

if [ -f "$DESKTOP_LIB/catalog.snap" ]; then
  echo "desktop (App) : $(stamp_human "$DESKTOP_LIB/catalog.snap")"
else
  echo "desktop (App) : $DESKTOP_LIB -- no catalog.snap"
fi

if [ -f "$BATCH_LIB/catalog.snap" ]; then
  echo "batch (CLI)   : $(stamp_human "$BATCH_LIB/catalog.snap")"
else
  echo "batch (CLI)   : $BATCH_LIB -- no catalog.snap"
fi

echo
echo "======== verdict ========"

if [ "${D_MT:-0}" -gt "${B_MT:-0}" ] 2>/dev/null; then
  echo "last edit     : App control channel (desktop library is newer)"
elif [ "${B_MT:-0}" -gt "${D_MT:-0}" ] 2>/dev/null; then
  echo "last edit     : CLI headless (batch library is newer)"
else
  echo "last edit     : undetermined (same timestamp, or neither library has history)"
fi

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "usable now    : both App channel and CLI"
elif [ -n "$CLI_BIN" ]; then
  echo "usable now    : CLI only. For the App channel, restart with:"
  echo "                open -a \"LightCraft\" --args --control $PORT"
else
  echo "usable now    : neither. Install the CLI, or restart the App with --control $PORT"
fi
