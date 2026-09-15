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


FORBIDDEN_STATIC_HEADERS = {
    "authorization",
    "chatgpt-account-id",
    "x-weave-force-model",
    "x-weave-router-key",
}


def normalize_codex_provider(provider: dict, base_url: str) -> None:
    provider["base_url"] = base_url
    provider["wire_api"] = "responses"
    provider["requires_openai_auth"] = True
    provider["supports_websockets"] = False
    provider.pop("env_key", None)
    provider.pop("experimental_bearer_token", None)

    static_headers = tomlkit.inline_table()
    for name, value in provider.get("http_headers", {}).items():
        if name.casefold() not in FORBIDDEN_STATIC_HEADERS:
            static_headers[name] = str(value)
    static_headers["X-App"] = "codex"
    provider["http_headers"] = static_headers

    env_headers = tomlkit.inline_table()
    for name, value in provider.get("env_http_headers", {}).items():
        if name.casefold() not in FORBIDDEN_STATIC_HEADERS:
            env_headers[name] = str(value)
    env_headers["X-Weave-Router-Key"] = "WEAVE_ROUTER_KEY"
    env_headers["ChatGPT-Account-ID"] = "CODEX_CHATGPT_ACCOUNT_ID"
    provider["env_http_headers"] = env_headers


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

    # Keep Codex directly on Weave: Headroom deliberately routes ChatGPT
    # session auth to chatgpt.com and therefore cannot relay it to another
    # proxy. Credential header values are supplied by Codex's environment.
    providers = config.setdefault("model_providers", tomlkit.table())
    weave = providers.setdefault("weave", tomlkit.table())
    normalize_codex_provider(weave, f"{WEAVE_URL}/v1")
    config["model_provider"] = "weave"
    config["openai_base_url"] = f"{WEAVE_URL}/v1"
    config["forced_login_method"] = "chatgpt"
    path.write_text(tomlkit.dumps(config))


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: configure-headroom-clients.py HOME_DIRECTORY")
    home = Path(sys.argv[1])
    configure_claude(home)
    configure_codex(home)


if __name__ == "__main__":
    main()
