#!/usr/bin/env python3
"""Configure Claude Code for the local Headroom proxy, native subscription, and Nix baseline."""

from __future__ import annotations

import json
import os
import sys
import tempfile
from pathlib import Path


HEADROOM_URL = "http://127.0.0.1:8787"


def backup_once(path: Path) -> None:
    backup = path.with_name(path.name + ".pre-headroom")
    if path.exists() and not backup.exists():
        backup.write_bytes(path.read_bytes())


def load_object(path: Path) -> dict:
    existing = path.read_text() if path.exists() else "{}"
    try:
        value = json.loads(existing)
    except json.JSONDecodeError as error:
        raise SystemExit(f"{path} is invalid JSON: {error}; refusing to overwrite it") from error
    if not isinstance(value, dict):
        raise SystemExit(f"{path} must contain a JSON object; refusing to overwrite it")
    return value


def merge(target: dict, baseline: dict) -> None:
    for key, value in baseline.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            merge(target[key], value)
        else:
            target[key] = value


def trust_projects(home: Path, projects: list[str]) -> None:
    # Claude Code records workspace trust in ~/.claude.json, not settings.json.
    path = home / ".claude.json"
    state = load_object(path)
    entries = state.setdefault("projects", {})
    if not isinstance(entries, dict):
        raise SystemExit(f"{path} has a non-object projects value; refusing to overwrite it")
    for project in projects:
        entries.setdefault(project, {})["hasTrustDialogAccepted"] = True
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
    descriptor, temporary = tempfile.mkstemp(dir=home, prefix=".claude.json.")
    with os.fdopen(descriptor, "w") as stream:
        stream.write(json.dumps(state, indent=2) + "\n")
    os.chmod(temporary, mode)
    os.replace(temporary, path)


def configure(home: Path, baseline: dict | None = None, trusted_projects: list[str] = ()) -> None:
    path = home / ".claude" / "settings.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    settings = load_object(path)
    merge(settings, baseline or {})
    env = settings.setdefault("env", {})
    if not isinstance(env, dict):
        raise SystemExit(f"{path} has a non-object env value; refusing to overwrite it")

    model_overrides = settings.setdefault("modelOverrides", {})
    if not isinstance(model_overrides, dict):
        raise SystemExit(f"{path} has a non-object modelOverrides value; refusing to overwrite it")
    # Claude Code's Auto permission classifier requests Sonnet 5, which is not in the Mindctl catalog.
    model_overrides.setdefault("claude-sonnet-5", "claude-sonnet-5-5")

    backup_once(path)
    # Claude Code's native account session supplies subscription credentials.
    # A configured API key switches it to API-key billing instead.
    env.pop("ANTHROPIC_API_KEY", None)
    env["ANTHROPIC_BASE_URL"] = HEADROOM_URL
    env["ANTHROPIC_CUSTOM_MODEL_OPTION"] = "mindctl-auto"
    env["ANTHROPIC_CUSTOM_MODEL_OPTION_NAME"] = "Mindctl Auto"
    env["ENABLE_TOOL_SEARCH"] = "true"
    path.write_text(json.dumps(settings, indent=2) + "\n")
    if trusted_projects:
        trust_projects(home, list(trusted_projects))


def main() -> None:
    if len(sys.argv) not in (2, 4):
        raise SystemExit("usage: configure-claude.py HOME_DIRECTORY [SETTINGS_JSON TRUSTED_PROJECTS_JSON]")
    baseline = json.loads(Path(sys.argv[2]).read_text()) if len(sys.argv) == 4 else None
    projects = json.loads(Path(sys.argv[3]).read_text()) if len(sys.argv) == 4 else []
    configure(Path(sys.argv[1]), baseline, projects)


if __name__ == "__main__":
    main()
