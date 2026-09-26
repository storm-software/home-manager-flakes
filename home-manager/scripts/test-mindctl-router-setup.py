import base64
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml


SCRIPT = Path(__file__).with_name("mindctl-router-setup.sh")
OPENAI_MODEL_IDS = [
    "gpt-6-astra",
    "gpt-6-sol",
    "gpt-6-luna",
    "gpt-5.6-sol",
    "gpt-5.6-terra",
    "gpt-5.6-luna",
    "gpt-5.3-codex",
    "gpt-5.3-codex-spark",
]
ANTHROPIC_MODEL_IDS = [
    "claude-fable-5-1",
    "claude-opus-5-5",
    "claude-sonnet-5",
    "claude-haiku-4-5",
]
MUSE_MODEL_IDS = ["muse-spark-1.3", "muse-spark-1.3-contributor"]
DEEPSEEK_MODEL_IDS = ["deepseek-v4-flash", "deepseek-v4-pro"]


class MindctlRouterSetupTests(unittest.TestCase):
    def run_setup(
        self, root: Path, provider_tokens: dict[str, str] | None = None
    ) -> subprocess.CompletedProcess[str]:
        environment = os.environ | {
            "MINDCTL_CONFIG_HOME": str(root / "config"),
            "MINDCTL_STATE_HOME": str(root / "state"),
        }
        environment.pop("DEEPSEEK_API_TOKEN", None)
        environment.pop("MUSE_API_TOKEN", None)
        environment.pop("DEEPSEEK_API_KEY", None)
        environment.pop("MUSE_API_KEY", None)
        if provider_tokens:
            environment.update(provider_tokens)
        return subprocess.run(
            ["bash", str(SCRIPT)],
            env=environment,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_writes_laya_and_oauth_config_without_optional_provider_tokens(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            result = self.run_setup(root)

            self.assertEqual(result.returncode, 0, result.stderr)
            config_path = root / "config" / "mindctl" / "config.yaml"
            secrets_path = root / "state" / "mindctl" / "secrets.env"
            laya_secrets_path = root / "state" / "mindctl" / "laya.env"
            config = yaml.safe_load(config_path.read_text())
            self.assertEqual(config["listen"], "127.0.0.1:8080")
            self.assertEqual(config["classifier"]["endpoint"], "http://127.0.0.1:8091")
            self.assertEqual(config["classifier"]["token_env"], "LAYA_CLASSIFIER_TOKEN")
            self.assertEqual(config["sqlite"]["path"], str(root / "state" / "mindctl" / "mindctl.db"))
            self.assertEqual(config["providers"], [
                {"id": "openai", "base_url": "https://chatgpt.com/backend-api/codex", "auth": "chatgpt_oauth_passthrough"},
                {"id": "anthropic", "base_url": "https://api.anthropic.com", "auth": "claude_oauth_passthrough"},
            ])
            self.assertEqual([model["id"] for model in config["models"]], OPENAI_MODEL_IDS + ANTHROPIC_MODEL_IDS)
            self.assertTrue(all(model["available"] for model in config["models"] if model["provider"] == "anthropic"))
            self.assertIn("web_search", config["models"][0]["capabilities"])
            self.assertIn("images", config["models"][0]["capabilities"])
            spark = next(model for model in config["models"] if model["id"] == "gpt-5.3-codex-spark")
            self.assertFalse(spark["available"])
            self.assertEqual(config_path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(secrets_path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(laya_secrets_path.stat().st_mode & 0o777, 0o600)
            secrets = dict(line.split("=", 1) for line in secrets_path.read_text().splitlines())
            self.assertRegex(secrets["MINDCTL_GATEWAY_TOKEN"], r"^[0-9a-f]{64}$")
            self.assertRegex(secrets["LAYA_CLASSIFIER_TOKEN"], r"^[0-9a-f]{64}$")
            self.assertEqual(len(base64.b64decode(secrets["MINDCTL_ENCRYPTION_KEY"], validate=True)), 32)
            self.assertEqual(
                laya_secrets_path.read_text(),
                f"LAYA_CLASSIFIER_TOKEN={secrets['LAYA_CLASSIFIER_TOKEN']}\n",
            )
            self.assertNotIn("MINDCTL_GATEWAY_TOKEN", laya_secrets_path.read_text())
            self.assertNotIn("MINDCTL_ENCRYPTION_KEY", laya_secrets_path.read_text())

    def test_includes_each_optional_provider_only_when_its_credential_is_available(self):
        token_cases = [
            ({"DEEPSEEK_API_TOKEN": "deepseek-token"}, "deepseek", DEEPSEEK_MODEL_IDS),
            ({"MUSE_API_TOKEN": "muse-token"}, "meta", MUSE_MODEL_IDS),
            ({"DEEPSEEK_API_KEY": "deepseek-key"}, "deepseek", DEEPSEEK_MODEL_IDS),
            ({"MUSE_API_KEY": "muse-key"}, "meta", MUSE_MODEL_IDS),
            (
                {"DEEPSEEK_API_KEY": "deepseek-key", "MUSE_API_KEY": "muse-key"},
                "deepseek",
                DEEPSEEK_MODEL_IDS,
            ),
        ]
        for provider_tokens, provider_id, provider_model_ids in token_cases:
            with self.subTest(provider_tokens=provider_tokens), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)

                result = self.run_setup(root, provider_tokens)

                self.assertEqual(result.returncode, 0, result.stderr)
                config = yaml.safe_load((root / "config" / "mindctl" / "config.yaml").read_text())
                provider = next(provider for provider in config["providers"] if provider["id"] == provider_id)
                credential_name = "DEEPSEEK" if provider_id == "deepseek" else "MUSE"
                suffix = "API_KEY" if credential_name + "_API_KEY" in provider_tokens else "API_TOKEN"
                self.assertEqual(provider["api_key_env"], credential_name + "_" + suffix)
                self.assertEqual(
                    [model["id"] for model in config["models"] if model["provider"] == provider_id],
                    provider_model_ids,
                )
                expected_model_ids = OPENAI_MODEL_IDS + ANTHROPIC_MODEL_IDS
                if "MUSE_API_TOKEN" in provider_tokens or "MUSE_API_KEY" in provider_tokens:
                    expected_model_ids += MUSE_MODEL_IDS
                if "DEEPSEEK_API_TOKEN" in provider_tokens or "DEEPSEEK_API_KEY" in provider_tokens:
                    expected_model_ids += DEEPSEEK_MODEL_IDS
                self.assertEqual([model["id"] for model in config["models"]], expected_model_ids)

    def test_prefers_api_keys_over_tokens_when_both_are_available(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_setup(Path(directory), {
                "DEEPSEEK_API_KEY": "deepseek-key",
                "DEEPSEEK_API_TOKEN": "deepseek-token",
                "MUSE_API_KEY": "muse-key",
                "MUSE_API_TOKEN": "muse-token",
            })

            self.assertEqual(result.returncode, 0, result.stderr)
            config = yaml.safe_load((Path(directory) / "config" / "mindctl" / "config.yaml").read_text())
            providers = {provider["id"]: provider for provider in config["providers"]}
            self.assertEqual(providers["deepseek"]["api_key_env"], "DEEPSEEK_API_KEY")
            self.assertEqual(providers["meta"]["api_key_env"], "MUSE_API_KEY")

    def test_falls_back_to_tokens_when_api_keys_are_empty(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_setup(Path(directory), {
                "DEEPSEEK_API_KEY": "",
                "DEEPSEEK_API_TOKEN": "deepseek-token",
                "MUSE_API_KEY": "",
                "MUSE_API_TOKEN": "muse-token",
            })

            self.assertEqual(result.returncode, 0, result.stderr)
            config = yaml.safe_load((Path(directory) / "config" / "mindctl" / "config.yaml").read_text())
            providers = {provider["id"]: provider for provider in config["providers"]}
            self.assertEqual(providers["deepseek"]["api_key_env"], "DEEPSEEK_API_TOKEN")
            self.assertEqual(providers["meta"]["api_key_env"], "MUSE_API_TOKEN")

    def test_reactivation_preserves_secrets_and_backs_up_manual_config_once(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config_dir = root / "config" / "mindctl"
            config_dir.mkdir(parents=True)
            config_path = config_dir / "config.yaml"
            config_path.write_text("manual: true\n")

            first = self.run_setup(root)
            first_secrets = (root / "state" / "mindctl" / "secrets.env").read_text()
            second = self.run_setup(root)

            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(second.returncode, 0, second.stderr)
            backup = config_dir / "config.yaml.pre-home-manager"
            self.assertEqual(backup.read_text(), "manual: true\n")
            self.assertEqual(backup.stat().st_mode & 0o777, 0o600)
            self.assertEqual((root / "state" / "mindctl" / "secrets.env").read_text(), first_secrets)

    def test_rejects_an_incomplete_existing_secrets_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state_dir = root / "state" / "mindctl"
            state_dir.mkdir(parents=True)
            secrets_path = state_dir / "secrets.env"
            secrets_path.write_text("MINDCTL_GATEWAY_TOKEN=existing-token\n")

            result = self.run_setup(root)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("invalid Mindctl secrets file", result.stderr)
            self.assertEqual(secrets_path.read_text(), "MINDCTL_GATEWAY_TOKEN=existing-token\n")


if __name__ == "__main__":
    unittest.main()
