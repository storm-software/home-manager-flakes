#!/usr/bin/env python3
"""Configure Headroom clients while keeping Codex OAuth directly on Weave."""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import tomlkit


HEADROOM_URL = "http://127.0.0.1:8787"
WEAVE_URL = "http://127.0.0.1:8080"


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

    # Weave authenticates the local client with its rk_ key while preserving
    # Authorization for the upstream ChatGPT OAuth credential. Keep Codex
    # directly on Weave: Headroom deliberately routes ChatGPT session auth to
    # chatgpt.com and therefore cannot relay that credential to another proxy.
    providers = config.setdefault("model_providers", tomlkit.table())
    weave = providers.get("weave")
    weave_headers = weave.get("http_headers") if hasattr(weave, "get") else None
    if not hasattr(weave_headers, "get") or not weave_headers.get("X-Weave-Router-Key"):
        raise SystemExit(
            f"{path} has no Weave router key; start weave-router before Headroom"
        )

    # Preserve the installer-owned headers, but remove any old force-model
    # override so Weave can choose automatically from the enabled roster.
    updated_headers = tomlkit.inline_table()
    for name, value in weave_headers.items():
        if name.casefold() != "x-weave-force-model":
            updated_headers[name] = str(value)
    weave["http_headers"] = updated_headers

    backup_once(path)
    config["model_provider"] = "weave"
    config["openai_base_url"] = str(weave.get("base_url", f"{WEAVE_URL}/v1"))
    weave["supports_websockets"] = False
    weave["requires_openai_auth"] = True
    path.write_text(tomlkit.dumps(config))


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: configure-headroom-clients.py HOME_DIRECTORY")
    home = Path(sys.argv[1])
    configure_claude(home)
    configure_codex(home)


if __name__ == "__main__":
    main()
