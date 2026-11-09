#!/usr/bin/env python3
"""Minimal client for LightCraft's JSON-lines control channel.

No dependencies beyond the Python standard library -- no MCP server, no CLI
install required. Talks straight to the socket that `lightcraft --control PORT`
opens on 127.0.0.1.

Usage:
    python3 lc.py '{"id":1,"method":"ui.inspect"}'
    python3 lc.py '<json1>' '<json2>'          # several requests, one per argument
    python3 lc.py --file cmds.jsonl            # one JSON object per line
    python3 lc.py --port 7981 '<json>'         # non-default port

Environment:
    LC_PORT     default port (default 7980)
    LC_TIMEOUT  per-request read timeout in seconds (default 240)
"""
import json
import os
import socket
import sys

HOST = "127.0.0.1"
PORT = int(os.environ.get("LC_PORT", "7980"))
TIMEOUT = float(os.environ.get("LC_TIMEOUT", "240"))


def send(lines, port=None, timeout=None):
    """Send each JSON string, yield parsed replies in order."""
    port = PORT if port is None else port
    timeout = TIMEOUT if timeout is None else timeout
    sock = socket.create_connection((HOST, port), timeout=15)
    sock.settimeout(timeout)
    f = sock.makefile("rwb")
    try:
        for i, line in enumerate(lines):
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            obj.setdefault("id", i + 1)
            f.write((json.dumps(obj) + "\n").encode("utf-8"))
            f.flush()
            raw = f.readline()
            if not raw:
                yield {"ok": False, "error": "connection closed by server"}
                return
            yield json.loads(raw.decode("utf-8"))
    finally:
        try:
            f.close()
        except Exception:
            pass
        sock.close()


def main(argv):
    port = None
    timeout = None
    args = list(argv)

    while args and args[0].startswith("--"):
        flag = args.pop(0)
        if flag in ("-h", "--help"):
            print(__doc__)
            return 0
        if flag == "--port":
            port = int(args.pop(0))
        elif flag == "--timeout":
            timeout = float(args.pop(0))
        elif flag == "--file":
            with open(args.pop(0), "r", encoding="utf-8") as fh:
                lines = [ln for ln in fh if ln.strip()]
            break
        else:
            print(f"unknown option: {flag}\n", file=sys.stderr)
            print(__doc__, file=sys.stderr)
            return 2
    else:
        lines = args

    if not lines:
        print(__doc__)
        return 2

    try:
        for reply in send(lines, port=port, timeout=timeout):
            print(json.dumps(reply, ensure_ascii=False))
    except ConnectionRefusedError:
        print(
            json.dumps(
                {
                    "ok": False,
                    "error": f"connection refused on {HOST}:{port or PORT} -- "
                    "is LightCraft running with --control?",
                }
            )
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
