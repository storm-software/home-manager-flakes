# Codex Home Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install and configure Codex declaratively through Home Manager, route it through the local Weave Router with automatic model selection, and keep all router, ChatGPT, and MCP credentials out of Nix-rendered TOML.

**Architecture:** A dedicated Home Manager module renders the non-secret Codex baseline and installs a wrapper around the flake-pinned `pkgs.codex`. Two focused shell helpers own the mutable boundaries: one atomically installs the baseline, and one loads the private router/account values only at process launch or into the systemd user environment. Existing Weave and Headroom writers normalize legacy files to the same environment-backed provider shape, while the pinned upstream source patch stops serializing the router key and retains OAuth eligibility without forcing a model.

**Tech Stack:** Nix/Home Manager, Bash, Python 3 `unittest`, `tomlkit`, `tomllib`, systemd user services, Codex `config.toml`, Weave Router.

**Spec:** `docs/superpowers/specs/2026-09-15-codex-home-manager-design.md`

## Global Constraints

- The declared Codex request model is exactly `gpt-5.6-terra`; this is not a Weave force-model instruction.
- Codex uses `http://127.0.0.1:8080/v1` with `model_provider = "weave"`.
- Authentication is ChatGPT OAuth only: `forced_login_method = "chatgpt"` and `requires_openai_auth = true`.
- Never add `OPENAI_API_KEY`, `env_key`, a direct bearer token, OAuth token, router-key value, or ChatGPT account-ID value to Nix data or rendered TOML.
- Never add `X-Weave-Force-Model` or assign the incoming Codex model to the router's internal `forceModel` variable.
- Preserve the router's validated ChatGPT bearer/account-ID path so Weave may select an eligible native OpenAI model.
- Preserve automatic selection across configured OpenAI and non-OpenAI providers.
- Render `~/.codex/config.toml` as a regular mode-`0600` file, not a Home Manager store symlink.
- Do not create a new backup containing the legacy secret-bearing Codex configuration.
- Report pre-existing `config.toml.pre-*` backups without deleting them.
- Missing router state or account ID must not prevent `codex login` from running.
- `--skip-weave-router` skips router startup and systemd environment import but still installs Codex.
- Do not run the activation package during implementation; the user will uninstall standalone Codex and activate the built generation.
- Preserve unrelated dirty work in `home-manager/mcp.nix`, `home-manager/scripts/weave-compose.py`, and all overlapping files. Stage only implementation-owned hunks.
- The repository has no `devenv.nix`; run focused Python and Nix commands directly.

## File Structure

- Create `home-manager/codex.nix`: generate the non-secret TOML baseline, translate shared MCP definitions to Codex environment references, install the wrapper and helper packages, and register the activation entry.
- Create `home-manager/scripts/install-codex-config.sh`: validate an existing TOML file and atomically install the Nix template without making a backup.
- Create `home-manager/scripts/test-install-codex-config.py`: prove invalid-file refusal, atomic regular-file replacement, mode `0600`, and no new secret-bearing backup.
- Create `home-manager/scripts/codex-router-env.sh`: load private router/account values, execute the real Codex binary, or import variable names into the systemd user manager.
- Create `home-manager/scripts/test-codex-router-env.py`: prove partial credentials, malformed auth, no secret arguments, and exec/import behavior.
- Create `home-manager/patches/weave-router-codex-env-headers.patch`: change the pinned upstream installer from static router-key TOML to `env_http_headers`.
- Modify `home-manager/default.nix`: import the dedicated Codex module.
- Modify `home-manager/scripts/weave-clients.py`: normalize legacy Weave/Headroom provider tables without static credentials, force headers, or new Codex backups.
- Modify `home-manager/scripts/test-weave-clients.py`: specify the credential-free, idempotent writer behavior.
- Modify `home-manager/scripts/configure-headroom-clients.py`: make Headroom's final Codex writer converge on the same provider shape.
- Modify `home-manager/scripts/test-configure-headroom-clients.py`: specify environment-backed authentication and empty/legacy config migration.
- Modify `home-manager/weave-router.nix`: apply the upstream installer patch, assert its output, and remove the internal `forceModel` assignment while retaining OAuth eligibility.
- Modify `home-manager/activate-wrapper.nix`: substitute the installed credential helper path into the outer activation wrapper.
- Modify `home-manager/scripts/activate-wrapper.sh`: import runtime credentials after successful router startup and before starting Headroom.

---

### Task 1: Make Every Runtime Codex Writer Credential-Free

**Files:**

- Modify: `home-manager/scripts/test-weave-clients.py`
- Modify: `home-manager/scripts/weave-clients.py`
- Modify: `home-manager/scripts/test-configure-headroom-clients.py`
- Modify: `home-manager/scripts/configure-headroom-clients.py`

**Interfaces:**

- Consumes: existing `configure(home: Path, state: Path, key: str)` and `configure_codex(home: Path)` entry points.
- Produces: a Codex provider with static `http_headers` metadata, environment-name mappings in `env_http_headers`, ChatGPT-only auth, and no new Codex backup.

- [ ] **Step 1: Rewrite the Weave client fixture to specify the migrated provider shape**

Replace the Codex setup and assertions in `test_repeated_setup_preserves_settings_and_rotates_only_managed_keys` with a legacy file that contains every forbidden form and assertions for the normalized result:

```python
(home / ".codex/config.toml").write_text(
    'model = "gpt-5.6-terra"\n'
    'model_provider = "headroom"\n'
    'forced_login_method = "api"\n'
    '[model_providers.weave]\n'
    'base_url = "http://127.0.0.1:8080/v1"\n'
    'env_key = "OPENAI_API_KEY"\n'
    'experimental_bearer_token = "legacy-bearer"\n'
    'http_headers = { "X-Weave-Router-Key" = "rk_test", '
    '"ChatGPT-Account-ID" = "legacy-account", "Authorization" = "Bearer old", '
    '"X-App" = "codex", "X-Weave-Force-Model" = "gpt-5.6-terra" }\n'
    '[model_providers.weave.env_http_headers]\n'
    'X-Weave-Force-Model = "WEAVE_FORCE_MODEL"\n'
)
```

```python
codex = tomlkit.loads((home / ".codex/config.toml").read_text())
provider = codex["model_providers"]["weave"]
self.assertEqual(codex["model_provider"], "weave")
self.assertEqual(codex["forced_login_method"], "chatgpt")
self.assertEqual(codex["openai_base_url"], "http://127.0.0.1:8080/v1")
self.assertTrue(provider["requires_openai_auth"])
self.assertFalse(provider["supports_websockets"])
self.assertNotIn("env_key", provider)
self.assertNotIn("experimental_bearer_token", provider)
self.assertEqual(dict(provider["http_headers"]), {"X-App": "codex"})
self.assertEqual(
    dict(provider["env_http_headers"]),
    {
        "X-Weave-Router-Key": "WEAVE_ROUTER_KEY",
        "ChatGPT-Account-ID": "CODEX_CHATGPT_ACCOUNT_ID",
    },
)
self.assertFalse((home / ".codex/config.toml.pre-weave").exists())
self.assertNotIn("rk_test", (home / ".codex/config.toml").read_text())
self.assertNotIn("legacy-account", (home / ".codex/config.toml").read_text())
```

Remove the `auth.json` fixture: this writer must not read the account ID into TOML.

- [ ] **Step 2: Rewrite the Headroom tests for environment-backed auth**

In `test_codex_preserves_oauth_and_routes_directly_through_weave`, include static router/account/Authorization/force headers and assert the same normalized keys shown in Step 1. Replace `test_codex_refuses_to_drop_local_router_auth` with this migration case:

```python
def test_codex_creates_environment_backed_weave_provider(self):
    with tempfile.TemporaryDirectory() as directory:
        home = Path(directory)
        path = home / ".codex" / "config.toml"
        path.parent.mkdir()
        path.write_text('model = "gpt-5.6-terra"\n')

        clients.configure_codex(home)

        config = tomlkit.parse(path.read_text())
        provider = config["model_providers"]["weave"]
        self.assertEqual(config["model_provider"], "weave")
        self.assertEqual(config["forced_login_method"], "chatgpt")
        self.assertEqual(provider["base_url"], "http://127.0.0.1:8080/v1")
        self.assertEqual(
            dict(provider["env_http_headers"]),
            {
                "X-Weave-Router-Key": "WEAVE_ROUTER_KEY",
                "ChatGPT-Account-ID": "CODEX_CHATGPT_ACCOUNT_ID",
            },
        )
```

Also assert a repeated call remains parseable by `tomllib`, preserves the declared model, and does not create `.pre-headroom` for Codex.

- [ ] **Step 3: Run both focused suites and confirm the new expectations fail**

Run:

```bash
nix shell nixpkgs#python3 nixpkgs#python3Packages.tomlkit nixpkgs#python3Packages.pyyaml --command \
  python -m unittest \
  home-manager/scripts/test-weave-clients.py \
  home-manager/scripts/test-configure-headroom-clients.py -v
```

Expected: failures show a static `X-Weave-Router-Key` or `ChatGPT-Account-ID`, a missing `env_http_headers`, and the old Headroom refusal when no static key exists.

- [ ] **Step 4: Add a narrow provider-normalization helper to each standalone writer**

Use the same field rules in both scripts; keep the helper local because each script is packaged independently:

```python
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
```

In `weave-clients.py`, make `update` accept `backup=True`, skip the `.pre-weave` copy when false, ensure `model_providers.weave` exists, set the top-level fields, normalize `weave`, and scrub an existing `headroom` table without selecting it:

```python
def update(path, load, dump, change, *, backup=True):
    # existing load/change logic
    if backup and path.exists() and not path.with_suffix(path.suffix + ".pre-weave").exists():
        # existing backup logic


def codex(value):
    providers = value.setdefault("model_providers", tomlkit.table())
    weave = providers.setdefault("weave", tomlkit.table())
    normalize_codex_provider(weave, base + "/v1")
    if "headroom" in providers:
        normalize_codex_provider(
            providers["headroom"],
            str(providers["headroom"].get("base_url", "http://127.0.0.1:8787/v1")),
        )
    value["model_provider"] = "weave"
    value["openai_base_url"] = base + "/v1"
    value["forced_login_method"] = "chatgpt"


update(home / ".codex/config.toml", tomlkit.loads, tomlkit.dumps, codex, backup=False)
```

In `configure-headroom-clients.py`, remove the static-key precondition and the `backup_once(path)` call from `configure_codex`; create or normalize the `weave` table, set the three top-level fields, and leave Claude's backup behavior unchanged.

- [ ] **Step 5: Run the focused suites twice**

Run the command from Step 3 twice.

Expected: both runs report all tests passing; the second run proves deterministic TOML serialization and idempotence.

- [ ] **Step 6: Review and commit only these writer changes**

Run:

```bash
git diff -- home-manager/scripts/weave-clients.py \
  home-manager/scripts/test-weave-clients.py \
  home-manager/scripts/configure-headroom-clients.py \
  home-manager/scripts/test-configure-headroom-clients.py
git diff --check
git add -p -- home-manager/scripts/weave-clients.py \
  home-manager/scripts/test-weave-clients.py \
  home-manager/scripts/configure-headroom-clients.py \
  home-manager/scripts/test-configure-headroom-clients.py
git diff --cached --check
git commit --no-gpg-sign -m "fix: keep Codex router credentials out of TOML"
```

Expected: staged hunks contain only Codex normalization and its tests; pre-existing unrelated edits remain unstaged.

---

### Task 2: Atomically Install the Nix-Owned Mutable Baseline

**Files:**

- Create: `home-manager/scripts/install-codex-config.sh`
- Create: `home-manager/scripts/test-install-codex-config.py`

**Interfaces:**

- Consumes: `install-codex-config.sh TEMPLATE HOME_DIRECTORY`.
- Produces: a regular `$HOME/.codex/config.toml`, atomically installed with mode `0600`, or a nonzero exit without modification when the existing TOML is invalid.

- [ ] **Step 1: Write subprocess tests for replacement safety**

Create `test-install-codex-config.py` with this complete test body:

```python
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("install-codex-config.sh")
TEMPLATE_TEXT = 'model = "gpt-5.6-terra"\nmodel_provider = "weave"\n'


def run_installer(template: Path, home: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(SCRIPT), str(template), str(home)],
        text=True,
        capture_output=True,
        check=False,
    )


class InstallCodexConfigTests(unittest.TestCase):
    def test_replaces_valid_legacy_file_without_secret_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            codex_dir = home / ".codex"
            codex_dir.mkdir(parents=True)
            template = root / "template.toml"
            template.write_text(TEMPLATE_TEXT)
            legacy = codex_dir / "config.toml"
            legacy.write_text(
                '[model_providers.weave]\nhttp_headers = { X = "secret" }\n'
            )

            result = run_installer(template, home)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(legacy.read_text(), TEMPLATE_TEXT)
            self.assertEqual(legacy.stat().st_mode & 0o777, 0o600)
            self.assertFalse((codex_dir / "config.toml.pre-codex").exists())

    def test_refuses_invalid_existing_toml(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            codex_dir = home / ".codex"
            codex_dir.mkdir(parents=True)
            template = root / "template.toml"
            template.write_text(TEMPLATE_TEXT)
            legacy = codex_dir / "config.toml"
            legacy.write_text("[invalid")

            result = run_installer(template, home)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("invalid TOML", result.stderr)
            self.assertEqual(legacy.read_text(), "[invalid")

    def test_replaces_a_store_style_symlink_with_a_regular_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            codex_dir = home / ".codex"
            codex_dir.mkdir(parents=True)
            template = root / "template.toml"
            template.write_text(TEMPLATE_TEXT)
            old_target = root / "old-store-config.toml"
            old_target.write_text('model = "old"\n')
            legacy = codex_dir / "config.toml"
            legacy.symlink_to(old_target)

            result = run_installer(template, home)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(legacy.is_symlink())
            self.assertEqual(legacy.read_text(), TEMPLATE_TEXT)
            self.assertEqual(old_target.read_text(), 'model = "old"\n')

    def test_reports_but_preserves_an_existing_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            codex_dir = home / ".codex"
            codex_dir.mkdir(parents=True)
            template = root / "template.toml"
            template.write_text(TEMPLATE_TEXT)
            backup = codex_dir / "config.toml.pre-weave"
            backup.write_text("historical-private-config\n")

            result = run_installer(template, home)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(str(backup), result.stderr)
            self.assertEqual(backup.read_text(), "historical-private-config\n")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the new suite and confirm it fails because the script is absent**

Run:

```bash
python -m unittest home-manager/scripts/test-install-codex-config.py -v
```

Expected: all cases fail because `install-codex-config.sh` does not exist.

- [ ] **Step 3: Implement the installer**

Create `install-codex-config.sh` with this complete flow:

```bash
#!/usr/bin/env bash
set -euo pipefail
umask 077

if (( $# != 2 )); then
  echo "usage: install-codex-config.sh TEMPLATE HOME_DIRECTORY" >&2
  exit 64
fi

template="$1"
home="$2"
directory="$home/.codex"
destination="$directory/config.toml"

if [[ -e "$destination" || -L "$destination" ]]; then
  if ! python3 - "$destination" <<'PY'
import pathlib
import sys
import tomllib

path = pathlib.Path(sys.argv[1])
try:
    with path.open("rb") as stream:
        tomllib.load(stream)
except Exception as error:
    print(f"{path} is invalid TOML: {error}; refusing to overwrite it", file=sys.stderr)
    raise SystemExit(1)
PY
  then
    exit 1
  fi
fi

for backup in "$destination".pre-*; do
  if [[ -e "$backup" || -L "$backup" ]]; then
    echo "Existing Codex backup may contain historical credentials: $backup" >&2
  fi
done

mkdir -p "$directory"
chmod 700 "$directory"
temporary="$(mktemp "$directory/.config.toml.XXXXXX")"
trap 'rm -f "$temporary"' EXIT
install -m 600 "$template" "$temporary"
mv -f "$temporary" "$destination"
trap - EXIT
```

The Python process only parses the file and prints an exception on invalid syntax; it never prints parsed values.

- [ ] **Step 4: Run the installer tests**

Run:

```bash
python -m unittest home-manager/scripts/test-install-codex-config.py -v
```

Expected: all four tests pass.

- [ ] **Step 5: Commit the helper and tests**

Run:

```bash
git add home-manager/scripts/install-codex-config.sh \
  home-manager/scripts/test-install-codex-config.py
git diff --cached --check
git commit --no-gpg-sign -m "feat: install mutable Codex config safely"
```

---

### Task 3: Load Router and ChatGPT Identity at Runtime

**Files:**

- Create: `home-manager/scripts/codex-router-env.sh`
- Create: `home-manager/scripts/test-codex-router-env.py`

**Interfaces:**

- Consumes: `codex-router-env.sh exec COMMAND [ARG ...]` or `codex-router-env.sh import`; optional `XDG_STATE_HOME` and `CODEX_HOME` path overrides.
- Produces: exported `WEAVE_ROUTER_KEY` and `CODEX_CHATGPT_ACCOUNT_ID` only when each private source contains a non-empty value; `import` passes only variable names to `systemctl --user import-environment`.

- [ ] **Step 1: Write tests with mock executables**

Create `test-codex-router-env.py` with this complete test body:

```python
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("codex-router-env.sh")


class CodexRouterEnvTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.home = self.root / "home"
        self.state = self.root / "state"
        self.codex_home = self.home / ".codex"
        self.bin = self.root / "bin"
        self.codex_home.mkdir(parents=True)
        (self.state / "weave-router").mkdir(parents=True)
        self.bin.mkdir()
        self.mock_codex = self.bin / "mock-codex"
        self.mock_codex.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, sys\n"
            "print(json.dumps({"
            "'args': sys.argv[1:], "
            "'router_key': os.environ.get('WEAVE_ROUTER_KEY'), "
            "'account_id': os.environ.get('CODEX_CHATGPT_ACCOUNT_ID')}))\n"
        )
        self.mock_codex.chmod(0o755)
        self.systemctl_record = self.root / "systemctl.json"
        systemctl = self.bin / "systemctl"
        systemctl.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, pathlib, sys\n"
            "pathlib.Path(os.environ['SYSTEMCTL_RECORD']).write_text(json.dumps({"
            "'args': sys.argv[1:], "
            "'router_key': os.environ.get('WEAVE_ROUTER_KEY'), "
            "'account_id': os.environ.get('CODEX_CHATGPT_ACCOUNT_ID')}))\n"
        )
        systemctl.chmod(0o755)

    def tearDown(self):
        self.temporary.cleanup()

    def run_helper(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        env = os.environ | {
            "HOME": str(self.home),
            "XDG_STATE_HOME": str(self.state),
            "CODEX_HOME": str(self.codex_home),
            "PATH": str(self.bin) + ":" + os.environ["PATH"],
            "SYSTEMCTL_RECORD": str(self.systemctl_record),
        }
        env.pop("WEAVE_ROUTER_KEY", None)
        env.pop("CODEX_CHATGPT_ACCOUNT_ID", None)
        return subprocess.run(
            ["bash", str(SCRIPT), *arguments],
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def write_credentials(self):
        (self.state / "weave-router/router-key").write_text("rk_test\n")
        (self.codex_home / "auth.json").write_text(
            json.dumps({"tokens": {"account_id": "acct_test"}})
        )

    def test_exec_loads_both_private_values(self):
        self.write_credentials()

        result = self.run_helper("exec", str(self.mock_codex), "--version")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout),
            {
                "args": ["--version"],
                "router_key": "rk_test",
                "account_id": "acct_test",
            },
        )

    def test_exec_allows_login_when_account_id_is_missing(self):
        (self.state / "weave-router/router-key").write_text("rk_test\n")

        result = self.run_helper("exec", str(self.mock_codex), "login")

        self.assertEqual(result.returncode, 0, result.stderr)
        recorded = json.loads(result.stdout)
        self.assertEqual(recorded["args"], ["login"])
        self.assertIsNone(recorded["account_id"])

    def test_import_passes_names_not_values_on_argv(self):
        self.write_credentials()

        result = self.run_helper("import")

        self.assertEqual(result.returncode, 0, result.stderr)
        recorded = json.loads(self.systemctl_record.read_text())
        self.assertEqual(
            recorded["args"],
            [
                "--user",
                "import-environment",
                "WEAVE_ROUTER_KEY",
                "CODEX_CHATGPT_ACCOUNT_ID",
            ],
        )
        self.assertEqual(recorded["router_key"], "rk_test")
        self.assertEqual(recorded["account_id"], "acct_test")
        self.assertNotIn("rk_test", " ".join(recorded["args"]))
        self.assertNotIn("acct_test", " ".join(recorded["args"]))

    def test_malformed_auth_warns_and_still_executes(self):
        (self.codex_home / "auth.json").write_text("{invalid")

        result = self.run_helper("exec", str(self.mock_codex), "login")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str(self.codex_home / "auth.json"), result.stderr)
        self.assertIn("invalid JSON", result.stderr)
        self.assertIsNone(json.loads(result.stdout)["account_id"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the suite and confirm it fails because the helper is absent**

Run:

```bash
python -m unittest home-manager/scripts/test-codex-router-env.py -v
```

Expected: all cases fail because `codex-router-env.sh` does not exist.

- [ ] **Step 3: Implement the helper without putting values in command arguments**

Create `codex-router-env.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
codex_home="${CODEX_HOME:-$HOME/.codex}"
key_file="$state_home/weave-router/router-key"
auth_file="$codex_home/auth.json"

if [[ -s "$key_file" ]]; then
  IFS= read -r WEAVE_ROUTER_KEY < "$key_file"
  if [[ -n "$WEAVE_ROUTER_KEY" ]]; then
    export WEAVE_ROUTER_KEY
  fi
fi

if [[ -e "$auth_file" ]]; then
  if account_id="$(jq -er '.tokens.account_id | select(type == "string" and length > 0)' "$auth_file" 2>/dev/null)"; then
    export CODEX_CHATGPT_ACCOUNT_ID="$account_id"
  elif ! jq -e . "$auth_file" >/dev/null 2>&1; then
    echo "$auth_file is invalid JSON; continuing without CODEX_CHATGPT_ACCOUNT_ID" >&2
  fi
fi

case "${1:-}" in
  exec)
    shift
    if (( $# == 0 )); then
      echo "codex-router-env exec requires a command" >&2
      exit 64
    fi
    exec "$@"
    ;;
  import)
    names=()
    [[ -n "${WEAVE_ROUTER_KEY:-}" ]] && names+=(WEAVE_ROUTER_KEY)
    [[ -n "${CODEX_CHATGPT_ACCOUNT_ID:-}" ]] && names+=(CODEX_CHATGPT_ACCOUNT_ID)
    if (( ${#names[@]} > 0 )); then
      exec systemctl --user import-environment "${names[@]}"
    fi
    ;;
  *)
    echo "usage: codex-router-env.sh {exec COMMAND [ARG ...]|import}" >&2
    exit 64
    ;;
esac
```

The mock `systemctl` test must observe values through its environment, proving that the values are available to systemd without appearing in its argument vector.

- [ ] **Step 4: Run the runtime-helper tests**

Run:

```bash
python -m unittest home-manager/scripts/test-codex-router-env.py -v
```

Expected: all tests pass.

- [ ] **Step 5: Commit the helper and tests**

Run:

```bash
git add home-manager/scripts/codex-router-env.sh \
  home-manager/scripts/test-codex-router-env.py
git diff --cached --check
git commit --no-gpg-sign -m "feat: load Codex router credentials at runtime"
```

---

### Task 4: Add the Declarative Codex Module and Terra Baseline

**Files:**

- Create: `home-manager/codex.nix`
- Modify: `home-manager/default.nix`

**Interfaces:**

- Consumes: `config.programs.mcp.servers`, `install-codex-config.sh TEMPLATE HOME_DIRECTORY`, and `codex-router-env.sh exec COMMAND` from Tasks 2 and 3.
- Produces: profile commands `codex`, `codex-router-env`, and `install-codex-config`; an activation entry named `installCodexConfig`; and the rendered non-secret baseline.

- [ ] **Step 1: Add a module import and verify evaluation fails while the module is absent**

Add `./codex.nix` next to `./agents.nix` in `home-manager/default.nix`, then run:

```bash
nix eval path:.#homeConfigurations.development.activationPackage.drvPath
```

Expected: evaluation fails because `home-manager/codex.nix` does not yet exist.

- [ ] **Step 2: Implement shared MCP translation with environment indirection**

Start `home-manager/codex.nix` with `{ config, lib, pkgs, ... }:` and define these functions:

```nix
stripDollar = value:
  if lib.hasPrefix "$" value then
    lib.removePrefix "$" value
  else
    throw "Codex secret-bearing MCP values must be environment references beginning with '$'";

codexMcpServer = name: server:
  if server.url != null then
    let
      remoteEnvHeaders =
        if name == "upstash/context7" then
          { Authorization = "CONTEXT7_AUTHORIZATION"; }
        else
          lib.mapAttrs (_header: stripDollar) server.headers;
    in
    { url = server.url; }
    // lib.optionalAttrs (remoteEnvHeaders != { }) {
      env_http_headers = remoteEnvHeaders;
    }
  else
    let
      inheritedEnv = lib.filterAttrs (_variable: value: builtins.isString value && lib.hasPrefix "$" value) server.env;
      literalEnv = lib.filterAttrs (_variable: value: builtins.isString value && !lib.hasPrefix "$" value) server.env;
    in
    {
      command = server.command;
      args = server.args;
    }
    // lib.optionalAttrs (literalEnv != { }) { env = literalEnv; }
    // lib.optionalAttrs (inheritedEnv != { }) {
      env_vars = map stripDollar (lib.attrValues inheritedEnv);
    };

codexMcpServers = lib.mapAttrs codexMcpServer config.programs.mcp.servers;
```

Add an assertion that no current shared local MCP entry uses a file-valued secret because this wrapper supports string environment references only:

```nix
assertion = lib.all (
  server: lib.all builtins.isString (lib.attrValues server.env)
) (lib.attrValues config.programs.mcp.servers);
message = "Codex MCP translation currently requires string env references";
```

This turns the existing Context7 and Firecrawl `$VARIABLE` declarations into variable names and lets local child processes inherit those values instead of writing them to TOML. The remote Context7 entry deliberately becomes `Authorization = "CONTEXT7_AUTHORIZATION"`, where the external environment supplies the complete preformatted authorization value required by the approved spec.

- [ ] **Step 3: Define the complete non-secret baseline**

Use `tomlFormat = pkgs.formats.toml { };` and define `codexSettings` with this shape:

```nix
codexSettings = {
  model = "gpt-5.6-terra";
  model_provider = "weave";
  model_reasoning_effort = "high";
  personality = "pragmatic";
  service_tier = "default";
  forced_login_method = "chatgpt";
  openai_base_url = "http://127.0.0.1:8080/v1";

  features = {
    hooks = true;
    memories = true;
    plugins = true;
  };
  memories = {
    generate_memories = true;
    use_memories = true;
  };
  model_providers.weave = {
    name = "Weave Router";
    base_url = "http://127.0.0.1:8080/v1";
    wire_api = "responses";
    requires_openai_auth = true;
    supports_websockets = false;
    http_headers.X-App = "codex";
    env_http_headers = {
      X-Weave-Router-Key = "WEAVE_ROUTER_KEY";
      ChatGPT-Account-ID = "CODEX_CHATGPT_ACCOUNT_ID";
    };
  };
  mcp_servers = codexMcpServers;
  plugins."prisma@plugins-cli".enabled = true;

  hooks = {
    SessionStart = [
      {
        hooks = [
          {
            type = "command";
            command = "${config.home.homeDirectory}/.codex/.weave/codex-status.sh";
          }
        ];
      }
    ];
    Stop = [
      {
        hooks = [
          {
            type = "command";
            command = "${config.home.homeDirectory}/.codex/.weave/codex-status.sh";
          }
        ];
      }
    ];
    UserPromptSubmit = [
      {
        hooks = [
          {
            type = "command";
            command = "${config.home.homeDirectory}/.codex/.weave/codex-directive.sh";
          }
        ];
      }
    ];
  };

  projects = lib.genAttrs [
    "/home/development"
    "/home/development/.config/orca/rate-limit-pty-cwd"
    "/home/development/repos/cyclone-ui"
    "/home/development/repos/home-manager-flakes"
    "/home/development/repos/media-kit"
    "/home/development/repos/powerlines"
    "/home/development/repos/razorwind"
    "/home/development/repos/shell-shock"
    "/home/development/repos/sourcebook"
    "/home/development/repos/storm-dev"
    "/home/development/repos/storm-ops"
    "/home/development/repos/stryke"
  ] (_path: { trust_level = "trusted"; });
};
```

Do not add transient UI acknowledgement fields.

Add Nix assertions for the hard security invariants:

```nix
{
  assertion = codexSettings.model == "gpt-5.6-terra";
  message = "Codex must use gpt-5.6-terra as its request model";
}
{
  assertion = !(codexSettings.model_providers.weave.http_headers ? X-Weave-Force-Model);
  message = "Codex must not force a Weave model";
}
{
  assertion = !(codexSettings.model_providers.weave ? env_key);
  message = "Codex must use ChatGPT OAuth, not OPENAI_API_KEY";
}
```

- [ ] **Step 4: Package the helpers, wrapper, and activation entry**

Define packages around the scripts:

```nix
codexConfig = tomlFormat.generate "codex-config.toml" codexSettings;

installCodexConfig = pkgs.writeShellApplication {
  name = "install-codex-config";
  runtimeInputs = [ pkgs.coreutils pkgs.python3 ];
  text = ''
    exec bash ${./scripts/install-codex-config.sh} "$@"
  '';
};

codexRouterEnv = pkgs.writeShellApplication {
  name = "codex-router-env";
  runtimeInputs = [ pkgs.coreutils pkgs.jq pkgs.systemd ];
  text = ''
    exec bash ${./scripts/codex-router-env.sh} "$@"
  '';
};

codex = pkgs.writeShellApplication {
  name = "codex";
  runtimeInputs = [ codexRouterEnv ];
  text = ''
    exec ${codexRouterEnv}/bin/codex-router-env exec ${pkgs.codex}/bin/codex "$@"
  '';
  meta = pkgs.codex.meta // { mainProgram = "codex"; };
};
```

Expose all three packages in `home.packages`, and install the baseline after the Home Manager write boundary:

```nix
home.activation.installCodexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  $DRY_RUN_CMD ${installCodexConfig}/bin/install-codex-config \
    ${codexConfig} ${lib.escapeShellArg config.home.homeDirectory}
'';
```

Do not enable `programs.codex.settings`; that module would create a store symlink at the same path.

- [ ] **Step 5: Format and evaluate the module**

Run:

```bash
nix fmt home-manager/codex.nix home-manager/default.nix
nix-instantiate --parse home-manager/codex.nix >/dev/null
nix eval path:.#homeConfigurations.development.activationPackage.drvPath
```

Expected: formatting and parse succeed; evaluation prints one derivation path.

- [ ] **Step 6: Build without activating and inspect the generated baseline**

Run:

```bash
nix build path:.#homeConfigurations.development.activationPackage
template="$(rg -o '/nix/store/[a-z0-9]+-codex-config\.toml' result/activate-inner | head -n 1)"
python - "$template" <<'PY'
import pathlib
import sys
import tomllib

path = pathlib.Path(sys.argv[1])
config = tomllib.loads(path.read_text())
provider = config["model_providers"]["weave"]
assert config["model"] == "gpt-5.6-terra"
assert config["model_provider"] == "weave"
assert config["forced_login_method"] == "chatgpt"
assert provider["requires_openai_auth"] is True
assert provider["env_http_headers"] == {
    "ChatGPT-Account-ID": "CODEX_CHATGPT_ACCOUNT_ID",
    "X-Weave-Router-Key": "WEAVE_ROUTER_KEY",
}
assert "X-Weave-Force-Model" not in path.read_text()
assert "OPENAI_API_KEY" not in path.read_text()
print(path)
PY
```

Expected: build and assertions succeed. The printed path is a Nix store template containing environment-variable names only.

- [ ] **Step 7: Review and commit the Codex module**

Run:

```bash
git diff -- home-manager/codex.nix home-manager/default.nix
git add home-manager/codex.nix home-manager/default.nix
git diff --cached --check
git commit --no-gpg-sign -m "feat: manage Codex through Home Manager"
```

---

### Task 5: Stop the Pinned Weave Installer and Router from Pinning Codex

**Files:**

- Create: `home-manager/patches/weave-router-codex-env-headers.patch`
- Modify: `home-manager/weave-router.nix`

**Interfaces:**

- Consumes: pinned Weave Router revision `7909ce56d6c79b1a341f774bb0fb36a36601392d`.
- Produces: upstream `write_codex_config` output with static `X-App`, environment-backed router/account headers, and no internal assignment from `feats.Model` to `forceModel`.

- [ ] **Step 1: Add build assertions before applying the installer patch**

At the end of `source.postPatch`, add checks that deliberately fail against the current source:

```bash
if grep -Fq 'local headers_parts="\"X-Weave-Router-Key\" = \"''${esc_key}\""' install/install.sh; then
  echo "Codex installer still serializes the Weave router key" >&2
  exit 1
fi
grep -Fq 'env_http_headers = { "X-Weave-Router-Key" = "WEAVE_ROUTER_KEY", "ChatGPT-Account-ID" = "CODEX_CHATGPT_ACCOUNT_ID" }' install/install.sh
if grep -Fq 'forceModel = feats.Model' internal/proxy/service.go; then
  echo "Codex OAuth path must not force the incoming model" >&2
  exit 1
fi
```

- [ ] **Step 2: Build and confirm the source assertion fails**

Run:

```bash
nix build path:.#homeConfigurations.development.activationPackage --no-link
```

Expected: the patched-source derivation fails with `Codex installer still serializes the Weave router key`.

- [ ] **Step 3: Create the upstream installer patch**

Generate a unified patch against the pinned source that makes these exact semantic changes in `install/install.sh`:

```diff
-  local esc_key esc_email esc_name esc_url esc_status
-  esc_key="$(toml_escape "$block_key")"
+  local esc_email esc_name esc_url esc_status
```

```diff
-  local headers_parts="\"X-Weave-Router-Key\" = \"${esc_key}\""
+  local headers_parts=""
```

Add this local helper and use it for optional email/name metadata and the mandatory app tag, so the inline table never starts with a comma:

```bash
append_header() {
  local entry="$1"
  if [[ -n "$headers_parts" ]]; then
    headers_parts="${headers_parts}, ${entry}"
  else
    headers_parts="$entry"
  fi
}

if [[ -n "$block_email" ]]; then
  append_header "\"X-Weave-User-Email\" = \"${esc_email}\""
fi
if [[ -n "$block_name" ]]; then
  append_header "\"X-Weave-User-Name\" = \"${esc_name}\""
fi
append_header '"X-App" = "codex"'

local headers_line="http_headers = { ${headers_parts} }"
local env_headers_line='env_http_headers = { "X-Weave-Router-Key" = "WEAVE_ROUTER_KEY", "ChatGPT-Account-ID" = "CODEX_CHATGPT_ACCOUNT_ID" }'
```

Place `${env_headers_line}` directly after `${headers_line}` in the managed provider block. Update the nearby permission comment to say the file may contain private user configuration even though this block no longer contains the router key.

Save the unified diff as `home-manager/patches/weave-router-codex-env-headers.patch`, and add it to the `pkgs.applyPatches` arguments:

```nix
patches = [ ./patches/weave-router-codex-env-headers.patch ];
```

- [ ] **Step 4: Remove only the automatic-routing override from the OAuth eligibility replacement**

In the replacement text for `internal/proxy/service.go`, keep this logic:

```go
if raw, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer "); ok {
    if requestcontext.CodexSubscriptionCreds(raw, r.Header.Get("ChatGPT-Account-ID")) != nil {
        enabledProviders[providers.ProviderOpenAI] = struct{}{}
    }
}
```

Delete the explanatory comment about an empty eligible pool and this entire branch:

```go
if forceModel == "" && requestcontext.CodexSubscriptionCoversModel(feats.Model) {
    forceModel = feats.Model
}
```

Do not change the later validated credential-restoration block; it is required for ChatGPT OAuth when Weave actually selects a native Codex model.

- [ ] **Step 5: Build and inspect the patched source**

Run:

```bash
nix build path:.#homeConfigurations.development.activationPackage
source_path="$(nix path-info -r ./result | rg '/[a-z0-9]+-weave-router-7909ce56d6c79b1a341f774bb0fb36a36601392d-codex-oauth-routing$' | head -n 1)"
rg -n 'env_http_headers|X-Weave-Router-Key|forceModel = feats.Model|CodexSubscriptionCreds' \
  "$source_path/install/install.sh" "$source_path/internal/proxy/service.go"
```

Expected: the installer contains the two environment-name mappings; no installer assignment embeds `block_key` into Codex TOML; `forceModel = feats.Model` is absent; OAuth eligibility and credential restoration remain present.

- [ ] **Step 6: Review and commit only the requested Weave hunks**

Run:

```bash
git diff -- home-manager/patches/weave-router-codex-env-headers.patch \
  home-manager/weave-router.nix
git add home-manager/patches/weave-router-codex-env-headers.patch
git add -p -- home-manager/weave-router.nix
git diff --cached --check
git commit --no-gpg-sign -m "fix: preserve automatic Codex routing through Weave"
```

Expected: the staged `weave-router.nix` hunks add the installer patch/assertions and remove only the internal force assignment; other worktree changes remain intact.

---

### Task 6: Import Runtime Credentials During Router Activation

**Files:**

- Modify: `home-manager/activate-wrapper.nix`
- Modify: `home-manager/scripts/activate-wrapper.sh`
- Modify: `home-manager/codex.nix`
- Create: `home-manager/scripts/test-activate-wrapper.py`

**Interfaces:**

- Consumes: the `codexRouterEnv` package from `home-manager/codex.nix` and a substituted `@codex_router_env@` executable path.
- Produces: outer activation order `restart weave-router` → `codex-router-env import` → `restart headroom` → `weave-router-login-codex`, with the entire sequence skipped under `--skip-weave-router`.

- [ ] **Step 1: Add a black-box activation-order test**

Create `test-activate-wrapper.py` with this complete black-box test body:

```python
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).with_name("activate-wrapper.sh")


class ActivateWrapperTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.result = self.root / "result"
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.profile_bin = self.home / ".nix-profile" / "bin"
        self.log = self.root / "activation.log"
        self.result.mkdir()
        self.bin.mkdir()
        self.profile_bin.mkdir(parents=True)

        self.make_command(
            self.result / "activate-inner",
            "printf '%s\\n' 'activate-inner' >> \"$ACTIVATION_LOG\"",
        )
        self.make_command(
            self.bin / "systemctl",
            "printf 'systemctl %s\\n' \"$*\" >> \"$ACTIVATION_LOG\"",
        )
        router_env = self.root / "codex-router-env"
        self.make_command(
            router_env,
            "printf 'codex-router-env %s\\n' \"$*\" >> \"$ACTIVATION_LOG\"",
        )
        self.make_command(
            self.profile_bin / "weave-router-login-codex",
            "printf '%s\\n' 'weave-router-login-codex' >> \"$ACTIVATION_LOG\"",
        )
        self.make_command(
            self.profile_bin / "displaylink-setup",
            "printf '%s\\n' 'displaylink-setup' >> \"$ACTIVATION_LOG\"",
        )

        wrapper = SOURCE.read_text().replace("@codex_router_env@", str(router_env))
        self.activate = self.result / "activate"
        self.activate.write_text(wrapper)
        self.activate.chmod(0o755)

    def tearDown(self):
        self.temporary.cleanup()

    @staticmethod
    def make_command(path: Path, body: str):
        path.write_text("#!/bin/sh\nset -eu\n" + body + "\n")
        path.chmod(0o755)

    def run_activate(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(self.activate), *arguments],
            env=os.environ
            | {
                "HOME": str(self.home),
                "PATH": str(self.bin) + ":" + os.environ["PATH"],
                "ACTIVATION_LOG": str(self.log),
            },
            text=True,
            capture_output=True,
            check=False,
        )

    def test_imports_codex_environment_between_router_and_headroom(self):
        result = self.run_activate("--skip-displaylink")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.log.read_text().splitlines(),
            [
                "activate-inner",
                "systemctl --user restart weave-router.service",
                "codex-router-env import",
                "systemctl --user restart headroom.service",
                "weave-router-login-codex",
            ],
        )

    def test_skip_weave_router_skips_services_import_and_login(self):
        result = self.run_activate("--skip-displaylink", "--skip-weave-router")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ["activate-inner"])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test and confirm the missing import fails**

Run:

```bash
python -m unittest home-manager/scripts/test-activate-wrapper.py -v
```

Expected: the normal-flow assertion fails because `codex-router-env import` is absent.

- [ ] **Step 3: Export the helper package from `codex.nix` through module arguments**

Set an internal read-only module value so `activate-wrapper.nix` can consume the exact derivation without duplicating it:

```nix
options.storm.codex.routerEnvPackage = lib.mkOption {
  type = lib.types.package;
  readOnly = true;
  internal = true;
};

config.storm.codex.routerEnvPackage = codexRouterEnv;
```

Because defining `options` switches this file to explicit module syntax, place the Task 4 `assertions`, `home.packages`, and `home.activation.installCodexConfig` definitions under the same top-level `config = { ... };` attribute set, with `storm.codex.routerEnvPackage = codexRouterEnv;` beside them. The values of those Task 4 definitions stay byte-for-byte unchanged.

- [ ] **Step 4: Substitute the helper path and add the ordered import**

Change `activate-wrapper.nix` to accept `config` and install the script through `substitute`:

```nix
{
  config,
  pkgs,
  ...
}:
let
  activateWrapper = pkgs.runCommand "activate-wrapper" { } ''
    substitute ${./scripts/activate-wrapper.sh} "$out" \
      --replace-fail '@codex_router_env@' \
      '${config.storm.codex.routerEnvPackage}/bin/codex-router-env'
    chmod +x "$out"
  '';
in
{
  home.extraBuilderCommands = ''
    mv $out/activate $out/activate-inner
    cp ${activateWrapper} $out/activate
    chmod +x $out/activate
  '';
}
```

In `activate-wrapper.sh`, update only the router branch:

```bash
if [[ "$setup_weave_router" == true ]]; then
  systemctl --user restart weave-router.service
  @codex_router_env@ import
  systemctl --user restart headroom.service

  # existing installed-login-helper check and invocation
fi
```

Values remain in the helper environment and are never interpolated into this generated wrapper.

- [ ] **Step 5: Run the activation-order tests and evaluate**

Run:

```bash
python -m unittest home-manager/scripts/test-activate-wrapper.py -v
nix fmt home-manager/codex.nix home-manager/activate-wrapper.nix
nix eval path:.#homeConfigurations.development.activationPackage.drvPath
```

Expected: both Python cases pass and Nix evaluation prints a derivation path.

- [ ] **Step 6: Build but do not activate**

Run:

```bash
nix build path:.#homeConfigurations.development.activationPackage
rg -n 'codex-router-env.*import|restart weave-router|restart headroom' result/activate
```

Expected: the generated wrapper uses a Nix store path for `codex-router-env`, in the required order. Do not run `result/activate`.

- [ ] **Step 7: Commit the activation integration**

Run:

```bash
git add home-manager/activate-wrapper.nix \
  home-manager/scripts/activate-wrapper.sh \
  home-manager/scripts/test-activate-wrapper.py \
  home-manager/codex.nix
git diff --cached --check
git commit --no-gpg-sign -m "feat: import Codex router credentials on activation"
```

---

### Task 7: Run the Complete Build-Only Verification

**Files:**

- Verify: all files changed in Tasks 1–6
- Preserve: unrelated unstaged work in the existing dirty worktree

**Interfaces:**

- Consumes: the complete Home Manager configuration and all focused test suites.
- Produces: evidence for source behavior, generated configuration, package closure, and activation script contents without changing live user services or files.

- [ ] **Step 1: Run every focused regression suite**

Run:

```bash
nix shell nixpkgs#python3 nixpkgs#python3Packages.tomlkit nixpkgs#python3Packages.pyyaml --command \
  python -m unittest \
  home-manager/scripts/test-weave-clients.py \
  home-manager/scripts/test-configure-headroom-clients.py \
  home-manager/scripts/test-install-codex-config.py \
  home-manager/scripts/test-codex-router-env.py \
  home-manager/scripts/test-activate-wrapper.py -v
```

Expected: every test passes.

- [ ] **Step 2: Format and perform static checks**

Run:

```bash
nix fmt home-manager/codex.nix home-manager/default.nix \
  home-manager/activate-wrapper.nix home-manager/weave-router.nix
nix-instantiate --parse home-manager/codex.nix >/dev/null
nix-instantiate --parse home-manager/default.nix >/dev/null
nix-instantiate --parse home-manager/activate-wrapper.nix >/dev/null
nix-instantiate --parse home-manager/weave-router.nix >/dev/null
git diff --check
```

Expected: all commands exit zero.

- [ ] **Step 3: Build the full activation package**

Run:

```bash
nix build path:.#homeConfigurations.development.activationPackage
```

Expected: build succeeds and updates `result`; do not execute the activation script.

- [ ] **Step 4: Prove Codex is in the closure and wraps the pinned binary**

Run:

```bash
nix path-info -r ./result | rg '/codex-(0\.154\.0|wrapper|router-env)|codex-config\.toml'
wrapper="$(readlink -f result/home-path/bin/codex)"
rg -n '/nix/store/.+-codex-0\.154\.0/bin/codex' "$wrapper"
```

Expected: the closure contains `pkgs.codex` version `0.154.0`, the runtime helper, wrapper, and TOML template; the wrapper executes the pinned store binary.

- [ ] **Step 5: Inspect the rendered TOML without reading live credentials**

Run:

```bash
template="$(rg -o '/nix/store/[a-z0-9]+-codex-config\.toml' result/activate-inner | head -n 1)"
python - "$template" <<'PY'
import pathlib
import sys
import tomllib

path = pathlib.Path(sys.argv[1])
text = path.read_text()
config = tomllib.loads(text)
provider = config["model_providers"]["weave"]
assert config["model"] == "gpt-5.6-terra"
assert config["model_provider"] == "weave"
assert config["forced_login_method"] == "chatgpt"
assert config["openai_base_url"] == "http://127.0.0.1:8080/v1"
assert provider["requires_openai_auth"] is True
assert provider["supports_websockets"] is False
assert provider["env_http_headers"]["X-Weave-Router-Key"] == "WEAVE_ROUTER_KEY"
assert provider["env_http_headers"]["ChatGPT-Account-ID"] == "CODEX_CHATGPT_ACCOUNT_ID"
for forbidden in (
    "OPENAI_API_KEY",
    "X-Weave-Force-Model",
    "experimental_bearer_token",
):
    assert forbidden not in text
print("generated Codex TOML security assertions passed")
PY
```

Expected: the script prints the success line and never reads `~/.codex/auth.json`, the router state file, or any external secret environment value.

- [ ] **Step 6: Prove source-level automatic routing and OAuth eligibility**

Run:

```bash
source_path="$(nix path-info -r ./result | rg '/[a-z0-9]+-weave-router-7909ce56d6c79b1a341f774bb0fb36a36601392d-codex-oauth-routing$' | head -n 1)"
test -z "$(rg -n 'forceModel = feats.Model|X-Weave-Force-Model' "$source_path/internal/proxy/service.go" "$source_path/install/install.sh" || true)"
rg -n 'CodexSubscriptionCreds|enabledProviders\[providers.ProviderOpenAI\]|CredentialsContextKey' \
  "$source_path/internal/server/middleware/auth.go" "$source_path/internal/proxy/service.go"
```

Expected: the absence check succeeds; the second command shows validated subscription discovery, OpenAI eligibility, and credential restoration.

- [ ] **Step 7: Inspect final repository state and commit any formatting-only implementation hunks**

Run:

```bash
git status --short
git diff --check
git diff --stat
```

If `nix fmt` changed implementation-owned lines after the task commits, stage only those exact hunks and commit them:

```bash
git add -p -- home-manager/codex.nix home-manager/default.nix \
  home-manager/activate-wrapper.nix home-manager/weave-router.nix
git diff --cached --check
git commit --no-gpg-sign -m "style: format Codex Home Manager configuration"
```

Expected: unrelated pre-existing modifications remain unstaged, and the implementation has no whitespace errors.

- [ ] **Step 8: Hand off activation with evidence boundaries**

Report:

- focused test results;
- activation-package build result;
- generated TOML assertions;
- pinned Codex package version and wrapper evidence;
- patched-source automatic-routing and OAuth evidence;
- existing `config.toml.pre-*` backup paths reported by read-only name checks, without opening their contents;
- that no live activation, service restart, login flow, or routed request was performed.

Give the user their planned runtime sequence only after these checks:

```bash
# User removes the standalone Codex installation using its own supported uninstaller.
./result/activate
codex --version
codex login status
```

State that desktop/IDE processes must be restarted after activation to inherit the systemd user-manager environment. Treat successful activation, ChatGPT login status, and a real routed request as separate runtime evidence that only the user's post-uninstall run can establish.
