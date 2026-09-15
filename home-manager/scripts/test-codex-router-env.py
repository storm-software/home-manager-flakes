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

    def run_helper(
        self, *arguments: str, inherited: dict[str, str] | None = None
    ) -> subprocess.CompletedProcess[str]:
        env = os.environ | {
            "HOME": str(self.home),
            "XDG_STATE_HOME": str(self.state),
            "CODEX_HOME": str(self.codex_home),
            "PATH": str(self.bin) + ":" + os.environ["PATH"],
            "SYSTEMCTL_RECORD": str(self.systemctl_record),
        }
        env.pop("WEAVE_ROUTER_KEY", None)
        env.pop("CODEX_CHATGPT_ACCOUNT_ID", None)
        if inherited:
            env.update(inherited)
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

    def test_exec_loads_router_key_without_trailing_newline(self):
        (self.state / "weave-router/router-key").write_text("rk_test")

        result = self.run_helper("exec", str(self.mock_codex), "login")

        self.assertEqual(result.returncode, 0, result.stderr)
        recorded = json.loads(result.stdout)
        self.assertEqual(recorded["args"], ["login"])
        self.assertEqual(recorded["router_key"], "rk_test")

    def test_exec_clears_inherited_values_when_sources_are_absent(self):
        result = self.run_helper(
            "exec",
            str(self.mock_codex),
            "login",
            inherited={
                "WEAVE_ROUTER_KEY": "stale-router-key",
                "CODEX_CHATGPT_ACCOUNT_ID": "stale-account-id",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        recorded = json.loads(result.stdout)
        self.assertIsNone(recorded["router_key"])
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
