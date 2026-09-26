#!/usr/bin/env python3
"""Configure Claude Code for the local Headroom proxy and native subscription."""

from __future__ import annotations

import json
import sys
from pathlib import Path


HEADROOM_URL = "http://127.0.0.1:8787"


def backup_once(path: Path) -> None:
    backup = path.with_name(path.name + ".pre-headroom")
    if path.exists() and not backup.exists():
        backup.write_bytes(path.read_bytes())


def configure(home: Path) -> None:
    path = home / ".claude" / "settings.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = path.read_text() if path.exists() else "{}"
    try:
        settings = json.loads(existing)
    except json.JSONDecodeError as error:
        raise SystemExit(f"{path} is invalid JSON: {error}; refusing to overwrite it") from error
    if not isinstance(settings, dict):
        raise SystemExit(f"{path} must contain a JSON object; refusing to overwrite it")
    env = settings.setdefault("env", {})
    if not isinstance(env, dict):
        raise SystemExit(f"{path} has a non-object env value; refusing to overwrite it")

    backup_once(path)
    # Claude Code's native account session supplies subscription credentials.
    # A configured API key switches it to API-key billing instead.
    env.pop("ANTHROPIC_API_KEY", None)
    env["ANTHROPIC_BASE_URL"] = HEADROOM_URL
    env["ENABLE_TOOL_SEARCH"] = "true"
    path.write_text(json.dumps(settings, indent=2) + "\n")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: configure-claude.py HOME_DIRECTORY")
    configure(Path(sys.argv[1]))


if __name__ == "__main__":
    main()
