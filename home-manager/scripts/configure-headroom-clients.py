#!/usr/bin/env python3
"""Configure Headroom as the local proxy while keeping Weave as upstream."""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import tomlkit


HEADROOM_URL = "http://127.0.0.1:8787"


def backup_once(path: Path) -> None:
    backup = path.with_name(path.name + ".pre-headroom")
    if path.exists() and not backup.exists():
        shutil.copy2(path, backup)


def configure_claude(home: Path) -> None:
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
    env["ANTHROPIC_BASE_URL"] = HEADROOM_URL
    env["ENABLE_TOOL_SEARCH"] = "true"
    path.write_text(json.dumps(settings, indent=2) + "\n")


def configure_codex(home: Path) -> None:
    path = home / ".codex" / "config.toml"
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = path.read_text() if path.exists() else ""
    try:
        config = tomlkit.parse(existing)
    except Exception as error:
        raise SystemExit(f"{path} is invalid TOML: {error}; refusing to overwrite it") from error

    backup_once(path)
    config["model_provider"] = "headroom"
    config["openai_base_url"] = f"{HEADROOM_URL}/v1"
    providers = config.setdefault("model_providers", tomlkit.table())
    provider = providers.setdefault("headroom", tomlkit.table())
    provider["name"] = "Headroom via Weave Router"
    provider["base_url"] = f"{HEADROOM_URL}/v1"
    provider["supports_websockets"] = True
    provider["requires_openai_auth"] = True
    headers = tomlkit.inline_table()
    headers["X-Headroom-Base-Url"] = "HEADROOM_CODEX_UPSTREAM_BASE_URL"
    provider["env_http_headers"] = headers
    path.write_text(tomlkit.dumps(config))


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: configure-headroom-clients.py HOME_DIRECTORY")
    home = Path(sys.argv[1])
    configure_claude(home)
    configure_codex(home)


if __name__ == "__main__":
    main()
