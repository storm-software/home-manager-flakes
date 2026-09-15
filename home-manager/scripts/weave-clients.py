"""Merge local-router settings into clients without discarding RTK/user state."""
import json
import os
from pathlib import Path
import shlex
import shutil
import tempfile

import tomlkit
import yaml


def atomic_write(path, content):
    fd, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(content)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def update(path, load, dump, change):
    # Preserve a first-install backup. Atomic replacement leaves Nix-owned
    # symlink targets intact; Home Manager must not also own these settings.
    path.parent.mkdir(parents=True, exist_ok=True)
    value = load(path.read_text()) if path.exists() else {}
    change(value)
    if path.exists() and not path.with_suffix(path.suffix + ".pre-weave").exists():
        shutil.copyfile(path, path.with_suffix(path.suffix + ".pre-weave"))
        path.with_suffix(path.suffix + ".pre-weave").chmod(0o600)
    atomic_write(path, dump(value))


def configure(home, state, key):
    base = "http://127.0.0.1:8080"
    model = "claude-sonnet-4-6"

    def gemini(value):
        value.setdefault("security", {}).setdefault("auth", {})["selectedType"] = "gemini-api-key"

    update(home / ".gemini/settings.json", json.loads, lambda v: json.dumps(v, indent=2) + "\n", gemini)

    # Gemini and Vibe load their own .env files, including when launched by a
    # GUI. Replace only these owned keys and retain other environment entries.
    def env_file(path, entries):
        def change(lines):
            lines[:] = [line for line in lines if line.removeprefix("export ").split("=", 1)[0].strip() not in entries]
            lines.extend(f"{name}={shlex.quote(value)}" for name, value in entries.items())
        update(path, str.splitlines, lambda v: "\n".join(v) + "\n", change)

    # Ensure the loader's empty-file representation is a list.
    for path in (home / ".gemini/.env", home / ".vibe/.env"):
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists():
            path.touch(mode=0o600)
    env_file(home / ".gemini/.env", {
        "GOOGLE_GEMINI_BASE_URL": base,
        "GEMINI_API_KEY": key,
        "GEMINI_CLI_CUSTOM_HEADERS": f"X-Weave-Router-Key: {key}",
    })
    env_file(home / ".vibe/.env", {"WEAVE_ROUTER_KEY": key})

    def droid(value):
        models = value.setdefault("customModels", [])
        models[:] = [m for m in models if m.get("id") != "custom:weave-router"]
        models.append({"id": "custom:weave-router", "model": model,
                       "displayName": "Weave Router", "baseUrl": base,
                       "apiKey": key, "provider": "anthropic", "maxOutputTokens": 16384})
        value.setdefault("sessionDefaultSettings", {}).update(
            model="custom:weave-router", specModeModel="custom:weave-router")

    update(home / ".factory/settings.json", json.loads, lambda v: json.dumps(v, indent=2) + "\n", droid)

    def vibe(value):
        # Vibe accepts both legacy arrays and modern maps.
        for field, identity, entry in (
            ("providers", "name", {"name": "weave", "api_base": base + "/v1",
                                     "api_key_env_var": "WEAVE_ROUTER_KEY", "api_style": "openai"}),
            ("models", "alias", {"name": model, "alias": "weave", "provider": "weave"}),
        ):
            items = value.setdefault(field, [])
            if isinstance(items, dict):
                items["weave"] = entry
            else:
                value[field] = [item for item in items if item.get(identity) != "weave"] + [entry]
        value["active_model"] = "weave"

    update(home / ".vibe/config.toml", tomlkit.loads, tomlkit.dumps, vibe)

    def codex(value):
        # The upstream installer can add a force-model header for Codex. Keep
        # routing enabled, but leave selection to Weave rather than pinning a
        # model across all future sessions. The router recognizes ChatGPT OAuth
        # only when Codex sends both its bearer and account id.
        providers = value.get("model_providers", {})
        auth_path = home / ".codex/auth.json"
        auth = json.loads(auth_path.read_text()) if auth_path.exists() else {}
        account_id = auth.get("tokens", {}).get("account_id")
        for provider in ("weave", "headroom"):
            provider_config = providers.get(provider, {})
            headers = provider_config.get("http_headers", {})
            if not hasattr(headers, "items"):
                continue
            # Rebuild the installer's inline table instead of extending it in
            # place. tomlkit can retain the closing-brace trivia and render a
            # newly appended account id without the required comma.
            updated_headers = tomlkit.inline_table()
            for name, value in headers.items():
                if name.casefold() != "x-weave-force-model":
                    updated_headers[name] = str(value)
            if account_id:
                updated_headers["ChatGPT-Account-ID"] = str(account_id)
            provider_config["http_headers"] = updated_headers

    update(home / ".codex/config.toml", tomlkit.loads, tomlkit.dumps, codex)

    def hermes(value):
        value.setdefault("providers", {})["weave"] = {
            "api": base + "/v1", "api_key": key, "transport": "chat_completions"}
        # Drop obsolete endpoint/credential overrides that would bypass weave.
        current = value.get("model", {})
        if not isinstance(current, dict):
            current = {}
        for name in ("base_url", "api_key"):
            current.pop(name, None)
        current.update(default=model, provider="custom:weave")
        value["model"] = current

    update(home / ".hermes/config.yaml", lambda s: yaml.safe_load(s) or {},
           lambda v: yaml.safe_dump(v, sort_keys=False), hermes)
    env = {
        "WEAVE_ROUTER_KEY": key,
        "COPILOT_PROVIDER_BASE_URL": base + "/v1",
        "COPILOT_PROVIDER_TYPE": "openai",
        "COPILOT_PROVIDER_API_KEY": key,
        "COPILOT_PROVIDER_BEARER_TOKEN": key,
        "COPILOT_PROVIDER_WIRE_API": "completions",
        "COPILOT_MODEL": model,
        "COPILOT_PROVIDER_WIRE_MODEL": model,
    }
    path = state / "client.env"
    atomic_write(path, "".join(f"export {name}={shlex.quote(value)}\n" for name, value in env.items()))


if __name__ == "__main__":
    os.umask(0o077)
    configure(Path(os.environ["WEAVE_CLIENT_HOME"]), Path(os.environ["WEAVE_STATE"]),
              os.environ["WEAVE_ROUTER_KEY"])
