import importlib.util
import json
import os
from pathlib import Path
import tempfile
import subprocess
import unittest

import tomlkit
import yaml

spec = importlib.util.spec_from_file_location("clients", Path(__file__).with_name("weave-clients.py"))
clients = importlib.util.module_from_spec(spec)
spec.loader.exec_module(clients)


class ClientSetupTests(unittest.TestCase):
    def test_restart_does_not_seed_again(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary = root / "bin"
            binary.mkdir()
            source = root / "source"
            (source / "install").mkdir(parents=True)
            (source / "install/install.sh").write_text("exit 0\n")
            mocks = {
                "docker": "exit 0\n",
                "curl": "exit 0\n",
                "weave-router-compose": '''
printf '%s\\n' "$*" >> "$WEAVE_STATE/compose-calls"
case "$*" in
  *keygen.go*) printf '%s\\n' '{"primaryKeyId":1}' ;;
  'run --rm -T seed') printf '  rk_test12345678901234567890\\n' ;;
esac
''',
            }
            for name, script in mocks.items():
                path = binary / name
                path.write_text("#!/bin/sh\n" + script)
                path.chmod(0o755)
            scripts = Path(__file__).parent.resolve()
            env = os.environ | {
                "PATH": str(binary) + ":" + os.environ["PATH"],
                "WEAVE_STATE": str(root / "state"),
                "WEAVE_SOURCE": str(source),
                "WEAVE_IMAGE": "weave-router:test",
                "WEAVE_REVISION": "test",
                "WEAVE_CLIENT_HOME": str(root / "home"),
                "WEAVE_CONFIGURE": str(scripts / "weave-clients.py"),
                "XDG_RUNTIME_DIR": str(root),
            }
            subprocess.run(["bash", str(scripts / "weave-setup.sh")],
                           env=env, check=True, capture_output=True, text=True)
            with (root / "state/providers.env").open("a") as providers:
                providers.write(
                    "OPENAI_API_KEY=obsolete-secret\n"
                    "export OPENAI_API_TOKEN=also-obsolete\n"
                )
            subprocess.run(["bash", str(scripts / "weave-setup.sh")],
                           env=env, check=True, capture_output=True, text=True)
            calls = (root / "state/compose-calls").read_text().splitlines()
            self.assertEqual(calls.count("run --rm -T seed"), 1)
            self.assertEqual(sum("keygen.go" in call for call in calls), 1)
            self.assertEqual((root / "state/router-key").stat().st_mode & 0o777, 0o600)
            providers = (root / "state/providers.env").read_text()
            self.assertNotIn("OPENAI_API_KEY", providers)
            self.assertNotIn("OPENAI_API_TOKEN", providers)

    def test_repeated_setup_preserves_settings_and_rotates_only_managed_keys(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            state = home / "state"
            state.mkdir()
            (home / ".gemini").mkdir()
            original = '{"hooks":{"BeforeTool":["rtk"]},"theme":"dark"}'
            (home / ".gemini/settings.json").write_text(original)
            (home / ".gemini/.env").write_text("OTHER_KEY=keep\nGEMINI_API_KEY=old\n")
            (home / ".vibe").mkdir()
            (home / ".vibe/config.toml").write_text(
                '[[providers]]\nname="other"\napi_base="http://example.invalid"\n'
                '[[models]]\nname="other-model"\nalias="other"\nprovider="other"\n'
            )
            (home / ".factory").mkdir()
            (home / ".factory/settings.json").write_text(json.dumps({
                "hooks": {"PreToolUse": ["rtk"]},
                "customModels": [{"id": "custom:other", "model": "other"}],
            }))
            (home / ".codex").mkdir()
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
            clients.configure(home, state, "rk_test_first")
            clients.configure(home, state, "rk_test_second")
            gemini = json.loads((home / ".gemini/settings.json").read_text())
            self.assertEqual(gemini["hooks"], {"BeforeTool": ["rtk"]})
            self.assertEqual(gemini["security"]["auth"]["selectedType"], "gemini-api-key")
            self.assertEqual((home / ".gemini/settings.json.pre-weave").read_text(), original)
            env = (home / ".gemini/.env").read_text()
            self.assertIn("OTHER_KEY=keep", env)
            self.assertNotIn("rk_test_first", env)
            self.assertEqual(env.count("GEMINI_API_KEY="), 1)
            self.assertIn("X-Weave-Router-Key: rk_test_second", env)
            vibe = tomlkit.loads((home / ".vibe/config.toml").read_text())
            self.assertEqual(len(vibe["providers"]), 2)
            self.assertEqual(vibe["active_model"], "weave")
            droid = json.loads((home / ".factory/settings.json").read_text())
            self.assertEqual(len(droid["customModels"]), 2)
            self.assertEqual(droid["hooks"], {"PreToolUse": ["rtk"]})
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
            hermes = yaml.safe_load((home / ".hermes/config.yaml").read_text())
            self.assertEqual(hermes["model"]["provider"], "custom:weave")
            for path in [home / ".gemini/.env", home / ".factory/settings.json",
                         home / ".vibe/.env", home / ".hermes/config.yaml", state / "client.env"]:
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_malformed_file_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / ".gemini").mkdir()
            path = home / ".gemini/settings.json"
            path.write_text("{invalid")
            with self.assertRaises(json.JSONDecodeError):
                clients.configure(home, home, "rk_test")
            self.assertEqual(path.read_text(), "{invalid")


if __name__ == "__main__":
    unittest.main()
