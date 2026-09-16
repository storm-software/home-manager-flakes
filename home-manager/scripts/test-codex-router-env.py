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
            "'account_id': os.environ.get('CODEX_CHATGPT_ACCOUNT_ID'), "
            "'context7_authorization': os.environ.get('CONTEXT7_AUTHORIZATION'), "
            "'context7_api_key': os.environ.get('CONTEXT7_API_KEY'), "
            "'firecrawl_api_key': os.environ.get('FIRECRAWL_API_KEY')}))\n"
        )
        self.mock_codex.chmod(0o755)
        self.systemctl_record = self.root / "systemctl.json"
        self.systemctl_state = self.root / "systemctl-state.json"
        systemctl = self.bin / "systemctl"
        systemctl.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, pathlib, sys\n"
            "record = pathlib.Path(os.environ['SYSTEMCTL_RECORD'])\n"
            "calls = json.loads(record.read_text()) if record.exists() else []\n"
            "calls.append({"
            "'args': sys.argv[1:], "
            "'router_key': os.environ.get('WEAVE_ROUTER_KEY'), "
            "'account_id': os.environ.get('CODEX_CHATGPT_ACCOUNT_ID')})\n"
            "record.write_text(json.dumps(calls))\n"
            "state = pathlib.Path(os.environ['SYSTEMCTL_STATE'])\n"
            "values = json.loads(state.read_text()) if state.exists() else {}\n"
            "assert sys.argv[1] == '--user'\n"
            "for name in sys.argv[3:]:\n"
            "    if sys.argv[2] == 'unset-environment': values.pop(name, None)\n"
            "    elif sys.argv[2] == 'import-environment': values[name] = os.environ[name]\n"
            "    else: raise AssertionError(sys.argv)\n"
            "state.write_text(json.dumps(values))\n"
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
            "SYSTEMCTL_STATE": str(self.systemctl_state),
        }
        env.pop("WEAVE_ROUTER_KEY", None)
        env.pop("CODEX_CHATGPT_ACCOUNT_ID", None)
        env.pop("CONTEXT7_AUTHORIZATION", None)
        env.pop("CONTEXT7_API_KEY", None)
        env.pop("FIRECRAWL_API_KEY", None)
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
                "context7_authorization": None,
                "context7_api_key": None,
                "firecrawl_api_key": None,
            },
        )

    def test_exec_allows_login_when_account_id_is_missing(self):
        (self.state / "weave-router/router-key").write_text("rk_test\n")

        result = self.run_helper("exec", str(self.mock_codex), "login")

        self.assertEqual(result.returncode, 0, result.stderr)
        recorded = json.loads(result.stdout)
        self.assertEqual(recorded["args"], ["login"])
        self.assertIsNone(recorded["account_id"])
        self.assertIsNone(recorded["context7_authorization"])
        self.assertIsNone(recorded["context7_api_key"])
        self.assertIsNone(recorded["firecrawl_api_key"])

    def test_exec_loads_router_key_without_trailing_newline(self):
        (self.state / "weave-router/router-key").write_text("rk_test")

        result = self.run_helper("exec", str(self.mock_codex), "login")

        self.assertEqual(result.returncode, 0, result.stderr)
        recorded = json.loads(result.stdout)
        self.assertEqual(recorded["args"], ["login"])
        self.assertEqual(recorded["router_key"], "rk_test")
        self.assertIsNone(recorded["context7_authorization"])
        self.assertIsNone(recorded["context7_api_key"])
        self.assertIsNone(recorded["firecrawl_api_key"])

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
        self.assertIsNone(recorded["context7_authorization"])
        self.assertIsNone(recorded["context7_api_key"])
        self.assertIsNone(recorded["firecrawl_api_key"])

    def test_exec_prefers_explicit_secretspec_values(self):
        self.write_credentials()

        result = self.run_helper(
            "--from-secretspec",
            "exec",
            str(self.mock_codex),
            "--version",
            inherited={
                "WEAVE_ROUTER_KEY": "vault-router-key",
                "CODEX_CHATGPT_ACCOUNT_ID": "vault-account-id",
                "CONTEXT7_AUTHORIZATION": "Bearer vault-context7",
                "CONTEXT7_API_KEY": "vault-context7-key",
                "FIRECRAWL_API_KEY": "vault-firecrawl-key",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout),
            {
                "args": ["--version"],
                "router_key": "vault-router-key",
                "account_id": "vault-account-id",
                "context7_authorization": "Bearer vault-context7",
                "context7_api_key": "vault-context7-key",
                "firecrawl_api_key": "vault-firecrawl-key",
            },
        )

    def test_exec_clears_unmarked_mcp_values(self):
        result = self.run_helper(
            "exec",
            str(self.mock_codex),
            "--version",
            inherited={
                "CONTEXT7_AUTHORIZATION": "stale-context7-authorization",
                "CONTEXT7_API_KEY": "stale-context7-key",
                "FIRECRAWL_API_KEY": "stale-firecrawl-key",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        recorded = json.loads(result.stdout)
        self.assertIsNone(recorded["context7_authorization"])
        self.assertIsNone(recorded["context7_api_key"])
        self.assertIsNone(recorded["firecrawl_api_key"])

    def test_exec_falls_back_to_local_sources_for_missing_secretspec_router_values(self):
        self.write_credentials()

        result = self.run_helper(
            "--from-secretspec",
            "exec",
            str(self.mock_codex),
            "--version",
            inherited={
                "CONTEXT7_AUTHORIZATION": "Bearer vault-context7",
                "CONTEXT7_API_KEY": "vault-context7-key",
                "FIRECRAWL_API_KEY": "vault-firecrawl-key",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout),
            {
                "args": ["--version"],
                "router_key": "rk_test",
                "account_id": "acct_test",
                "context7_authorization": "Bearer vault-context7",
                "context7_api_key": "vault-context7-key",
                "firecrawl_api_key": "vault-firecrawl-key",
            },
        )

    def test_exec_warns_when_secretspec_omits_mcp_credentials(self):
        result = self.run_helper(
            "--from-secretspec",
            "exec",
            str(self.mock_codex),
            "--version",
            inherited={
                "WEAVE_ROUTER_KEY": "vault-router-key",
                "CODEX_CHATGPT_ACCOUNT_ID": "vault-account-id",
            },
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("MCP credentials unavailable", result.stderr)

    def test_import_passes_names_not_values_on_argv(self):
        self.write_credentials()

        result = self.run_helper("import")

        self.assertEqual(result.returncode, 0, result.stderr)
        recorded, = json.loads(self.systemctl_record.read_text())
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

    def test_repeated_import_clears_missing_or_unusable_sources(self):
        cases = {
            "absent": None,
            "empty": "",
            "malformed": "{invalid",
            "missing-account": '{"tokens": {}}',
            "empty-account": '{"tokens": {"account_id": ""}}',
            "non-string-account": '{"tokens": {"account_id": 123}}',
        }
        for case, auth in cases.items():
            with self.subTest(case=case):
                self.write_credentials()
                self.systemctl_state.write_text(json.dumps({"UNRELATED": "keep"}))
                initial = self.run_helper("import")
                self.assertEqual(initial.returncode, 0, initial.stderr)
                self.assertEqual(json.loads(self.systemctl_state.read_text()), {
                    "UNRELATED": "keep", "WEAVE_ROUTER_KEY": "rk_test",
                    "CODEX_CHATGPT_ACCOUNT_ID": "acct_test",
                })
                key_file = self.state / "weave-router/router-key"
                auth_file = self.codex_home / "auth.json"
                if auth is None:
                    key_file.unlink()
                    auth_file.unlink()
                else:
                    key_file.write_text("")
                    auth_file.write_text(auth)
                for _ in range(2):
                    result = self.run_helper("import")
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(json.loads(self.systemctl_state.read_text()), {"UNRELATED": "keep"})
                recorded = json.loads(self.systemctl_record.read_text())
                self.assertEqual(recorded[-1]["args"], [
                    "--user", "unset-environment", "WEAVE_ROUTER_KEY", "CODEX_CHATGPT_ACCOUNT_ID",
                ])
                self.assert_safe_systemctl_argv(recorded)

    def test_import_unsets_absent_name_before_importing_present_name(self):
        for missing in ("WEAVE_ROUTER_KEY", "CODEX_CHATGPT_ACCOUNT_ID"):
            with self.subTest(missing=missing):
                self.write_credentials()
                initial = self.run_helper("import")
                self.assertEqual(initial.returncode, 0, initial.stderr)
                if missing == "WEAVE_ROUTER_KEY":
                    (self.state / "weave-router/router-key").unlink()
                    present, value = "CODEX_CHATGPT_ACCOUNT_ID", "acct_test"
                else:
                    (self.codex_home / "auth.json").write_text("{invalid")
                    present, value = "WEAVE_ROUTER_KEY", "rk_test"
                result = self.run_helper("import")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(self.systemctl_state.read_text()), {present: value})
                recorded = json.loads(self.systemctl_record.read_text())
                self.assertEqual([call["args"] for call in recorded[-2:]], [
                    ["--user", "unset-environment", missing],
                    ["--user", "import-environment", present],
                ])
                self.assert_safe_systemctl_argv(recorded)

    def assert_safe_systemctl_argv(self, calls):
        for call in calls:
            self.assertIn(call["args"][1], ("import-environment", "unset-environment"))
            self.assertTrue(set(call["args"][2:]) <= {"WEAVE_ROUTER_KEY", "CODEX_CHATGPT_ACCOUNT_ID"})
            self.assertNotIn("rk_test", " ".join(call["args"]))
            self.assertNotIn("acct_test", " ".join(call["args"]))

    def test_malformed_auth_warns_and_still_executes(self):
        (self.codex_home / "auth.json").write_text("{invalid")

        result = self.run_helper("exec", str(self.mock_codex), "login")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str(self.codex_home / "auth.json"), result.stderr)
        self.assertIn("invalid JSON", result.stderr)
        self.assertIsNone(json.loads(result.stdout)["account_id"])


if __name__ == "__main__":
    unittest.main()
