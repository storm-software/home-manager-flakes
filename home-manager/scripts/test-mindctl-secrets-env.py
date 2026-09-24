import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("mindctl-secrets-env.sh")


class MindctlSecretsEnvTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.manifest = self.root / "secretspec.toml"
        self.manifest.write_text("[project]\nname = 'test'\n")
        self.record = self.root / "mindctl.json"
        self.setup_record = self.root / "setup.json"

        self.setup = self.bin / "setup"
        self.setup.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, pathlib\n"
            "pathlib.Path(os.environ['MINDCTL_SETUP_RECORD']).write_text(json.dumps({\n"
            "  'deepseek': os.environ.get('DEEPSEEK_API_TOKEN'),\n"
            "  'muse': os.environ.get('MUSE_API_TOKEN'),\n"
            "}))\n"
        )
        self.setup.chmod(0o755)

        self.router = self.bin / "router"
        self.router.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, pathlib\n"
            "pathlib.Path(os.environ['MINDCTL_RECORD']).write_text(json.dumps({\n"
            "  'deepseek': os.environ.get('DEEPSEEK_API_TOKEN'),\n"
            "  'muse': os.environ.get('MUSE_API_TOKEN'),\n"
            "}))\n"
        )
        self.router.chmod(0o755)

        secretspec = self.bin / "secretspec"
        secretspec.write_text(
            "#!/usr/bin/env python3\n"
            "import os, sys\n"
            "args = sys.argv[1:]\n"
            "assert 'mindctl' in args, args\n"
            "if args[2] == 'check': sys.exit(int(os.environ.get('CHECK_EXIT', '0')))\n"
            "if args[2] != 'run': raise AssertionError(args)\n"
            "command = args[args.index('--') + 1:]\n"
            "env = os.environ | {'DEEPSEEK_API_TOKEN': 'vault-deepseek', 'MUSE_API_TOKEN': 'vault-muse'}\n"
            "os.execvpe(command[0], command, env)\n"
        )
        secretspec.chmod(0o755)

    def tearDown(self):
        self.temporary.cleanup()

    def run_launcher(self, extra_env: dict[str, str] | None = None):
        env = os.environ | {
            "PATH": str(self.bin) + ":" + os.environ["PATH"],
            "SECRETSPEC_FILE": str(self.manifest),
            "MINDCTL_RECORD": str(self.record),
            "MINDCTL_SETUP_COMMAND": str(self.setup),
            "MINDCTL_SETUP_RECORD": str(self.setup_record),
        }
        if extra_env:
            env.update(extra_env)
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.router)],
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_runs_mindctl_with_optional_vault_provider_tokens(self):
        result = self.run_launcher()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(self.record.read_text()),
            {"deepseek": "vault-deepseek", "muse": "vault-muse"},
        )
        self.assertEqual(
            json.loads(self.setup_record.read_text()),
            {"deepseek": "vault-deepseek", "muse": "vault-muse"},
        )

    def test_starts_without_provider_tokens_when_the_vault_is_unavailable(self):
        result = self.run_launcher({"CHECK_EXIT": "1"})

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Proton Pass secrets unavailable", result.stderr)
        self.assertEqual(json.loads(self.record.read_text()), {"deepseek": None, "muse": None})
        self.assertEqual(json.loads(self.setup_record.read_text()), {"deepseek": None, "muse": None})


if __name__ == "__main__":
    unittest.main()
