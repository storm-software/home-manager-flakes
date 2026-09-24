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
            self.assertEqual(config["providers"], [{"id": "openai", "base_url": "https://chatgpt.com/backend-api/codex", "auth": "chatgpt_oauth_passthrough"}])
            self.assertEqual([model["id"] for model in config["models"]], OPENAI_MODEL_IDS)
            self.assertIn("web_search", config["models"][0]["capabilities"])
            self.assertIn("images", config["models"][0]["capabilities"])
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

    def test_includes_each_optional_provider_only_when_its_token_is_available(self):
        token_cases = [
            ({"DEEPSEEK_API_TOKEN": "deepseek-token"}, "deepseek", DEEPSEEK_MODEL_IDS),
            ({"MUSE_API_TOKEN": "muse-token"}, "meta", MUSE_MODEL_IDS),
            (
                {"DEEPSEEK_API_TOKEN": "deepseek-token", "MUSE_API_TOKEN": "muse-token"},
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
                self.assertIn(provider_id, {provider["id"] for provider in config["providers"]})
                self.assertEqual(
                    [model["id"] for model in config["models"] if model["provider"] == provider_id],
                    provider_model_ids,
                )
                expected_model_ids = OPENAI_MODEL_IDS.copy()
                if "MUSE_API_TOKEN" in provider_tokens:
                    expected_model_ids += MUSE_MODEL_IDS
                if "DEEPSEEK_API_TOKEN" in provider_tokens:
                    expected_model_ids += DEEPSEEK_MODEL_IDS
                self.assertEqual([model["id"] for model in config["models"]], expected_model_ids)

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
