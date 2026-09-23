import base64
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml


SCRIPT = Path(__file__).with_name("mindctl-router-setup.sh")


class MindctlRouterSetupTests(unittest.TestCase):
    def run_setup(self, root: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(SCRIPT)],
            env=os.environ
            | {
                "MINDCTL_CONFIG_HOME": str(root / "config"),
                "MINDCTL_STATE_HOME": str(root / "state"),
            },
            text=True,
            capture_output=True,
            check=False,
        )

    def test_writes_laya_oauth_config_and_private_runtime_secrets(self):
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
            self.assertEqual(config["models"][0]["id"], "gpt-5")
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
