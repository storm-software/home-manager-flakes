import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("codex-secrets-env.sh")


class CodexSecretsEnvTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.manifest = self.root / "secretspec.toml"
        self.manifest.write_text("[project]\nname = 'test'\n")
        self.record = self.root / "router.json"

        self.router = self.bin / "router"
        self.router.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, pathlib, sys\n"
            "record = {\n"
            "  'args': sys.argv[1:],\n"
            "  'account_id': os.environ.get('CODEX_CHATGPT_ACCOUNT_ID'),\n"
            "  'context7_api_key': os.environ.get('CONTEXT7_API_KEY'),\n"
            "  'firecrawl_api_key': os.environ.get('FIRECRAWL_API_KEY'),\n"
            "}\n"
            "github_token = os.environ.get('CODEX_GITHUB_PERSONAL_ACCESS_TOKEN')\n"
            "if github_token is not None: record['github_personal_access_token'] = github_token\n"
            "pathlib.Path(os.environ['ROUTER_RECORD']).write_text(json.dumps(record))\n"
        )
        self.router.chmod(0o755)

        secretspec = self.bin / "secretspec"
        secretspec.write_text(
            "#!/usr/bin/env python3\n"
            "import os, sys\n"
            "args = sys.argv[1:]\n"
            "if args[2] == 'check':\n"
            "  sys.exit(int(os.environ.get('CHECK_EXIT', '0')))\n"
            "if args[2] != 'run': raise AssertionError(args)\n"
            "command = args[args.index('--') + 1:]\n"
            "env = os.environ | {\n"
            "  'CODEX_CHATGPT_ACCOUNT_ID': 'vault-account-id',\n"
            "  'CONTEXT7_API_KEY': 'vault-context7-key',\n"
            "  'FIRECRAWL_API_KEY': 'vault-firecrawl-key',\n"
            "  'GITHUB_TOKEN': 'vault-github-token',\n"
            "}\n"
            "os.execvpe(command[0], command, env)\n"
        )
        secretspec.chmod(0o755)

    def tearDown(self):
        self.temporary.cleanup()

    def run_launcher(self, *arguments: str, extra_env: dict[str, str] | None = None):
        env = os.environ | {
            "PATH": str(self.bin) + ":" + os.environ["PATH"],
            "SECRETSPEC_FILE": str(self.manifest),
            "CODEX_ROUTER_ENV": str(self.router),
            "ROUTER_RECORD": str(self.record),
        }
        if extra_env:
            env.update(extra_env)
        return subprocess.run(
            ["bash", str(SCRIPT), *arguments],
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_runs_router_with_injected_values_after_a_successful_check(self):
        result = self.run_launcher("exec", "probe")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(self.record.read_text()),
            {
                "args": ["--from-secretspec", "exec", "probe"],
                "account_id": "vault-account-id",
                "context7_api_key": "vault-context7-key",
                "firecrawl_api_key": "vault-firecrawl-key",
            },
        )

    def test_falls_back_without_injected_values_when_check_fails(self):
        result = self.run_launcher("exec", "probe", extra_env={"CHECK_EXIT": "1"})

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Proton Pass secrets unavailable", result.stderr)
        self.assertNotIn("vault-router-key", result.stderr)
        self.assertEqual(
            json.loads(self.record.read_text()),
            {
                "args": ["exec", "probe"],
                "account_id": None,
                "context7_api_key": None,
                "firecrawl_api_key": None,
            },
        )


if __name__ == "__main__":
    unittest.main()
