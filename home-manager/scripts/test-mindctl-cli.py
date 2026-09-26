import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("mindctl-cli.sh")


class MindctlCliTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.secrets = self.root / "secrets.env"
        self.secrets.write_text(
            "MINDCTL_GATEWAY_TOKEN=other-secret\n"
            "MINDCTL_ENCRYPTION_KEY=existing-encryption-key\n"
        )
        self.mindctl = self.root / "mindctl-bin"
        self.mindctl.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, sys\n"
            "print(json.dumps({\n"
            "  'args': sys.argv[1:],\n"
            "  'key': os.environ.get('MINDCTL_ENCRYPTION_KEY'),\n"
            "  'gateway': os.environ.get('MINDCTL_GATEWAY_TOKEN'),\n"
            "}))\n"
        )
        self.mindctl.chmod(0o755)

    def tearDown(self):
        self.temporary.cleanup()

    def run_cli(self, *args, secret_file=None, key=None):
        env = os.environ.copy()
        env.pop("MINDCTL_ENCRYPTION_KEY", None)
        env.pop("MINDCTL_GATEWAY_TOKEN", None)
        if key is not None:
            env["MINDCTL_ENCRYPTION_KEY"] = key
        result = subprocess.run(
            ["bash", str(SCRIPT), str(self.mindctl), str(secret_file or self.secrets), *args],
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_history_loads_only_the_existing_encryption_key(self):
        self.assertEqual(
            self.run_cli("history", "--limit", "5"),
            {"args": ["history", "--limit", "5"], "key": "existing-encryption-key", "gateway": None},
        )

    def test_other_commands_do_not_load_the_key(self):
        self.assertEqual(self.run_cli("status"), {"args": ["status"], "key": None, "gateway": None})

    def test_existing_encryption_key_is_not_overridden(self):
        self.assertEqual(self.run_cli("history", key="custom-key")["key"], "custom-key")

    def test_missing_secrets_file_preserves_original_command_behavior(self):
        self.assertIsNone(self.run_cli("history", secret_file=self.root / "missing")["key"])


if __name__ == "__main__":
    unittest.main()
