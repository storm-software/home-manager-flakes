import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("codex-vscode.sh")
ROUTER_ENV = Path(__file__).with_name("codex-router-env.sh")


class CodexVscodeLauncherTests(unittest.TestCase):
    def test_uses_newest_bundled_cli_with_secrets_and_forwards_arguments(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            extensions = root / "extensions"
            state = root / "state"
            output = root / "invocation.json"
            (state / "mindctl").mkdir(parents=True)
            (state / "mindctl" / "secrets.env").write_text(
                "MINDCTL_GATEWAY_TOKEN=ide-test-token\n"
            )

            for version in ("26.9.0", "26.10.0"):
                executable = (
                    extensions
                    / f"openai.chatgpt-{version}-linux-x64"
                    / "bin"
                    / "linux-x86_64"
                    / "codex"
                )
                executable.parent.mkdir(parents=True)
                executable.write_text(
                    "#!/usr/bin/env python3\n"
                    "import json, os, sys\n"
                    "from pathlib import Path\n"
                    "Path(os.environ['TEST_OUTPUT']).write_text(json.dumps({\n"
                    "  'version': os.environ['TEST_VERSION'],\n"
                    "  'token': os.environ.get('MINDCTL_GATEWAY_TOKEN'),\n"
                    "  'args': sys.argv[1:],\n"
                    "}))\n"
                )
                executable.chmod(0o755)
                executable.write_text(
                    executable.read_text().replace(
                        "os.environ['TEST_VERSION']", repr(version)
                    )
                )

            environment = os.environ.copy()
            environment.update(
                {
                    "CODEX_SECRETS_ENV": str(ROUTER_ENV),
                    "CODEX_VSCODE_EXTENSIONS_DIR": str(extensions),
                    "XDG_STATE_HOME": str(state),
                    "TEST_OUTPUT": str(output),
                }
            )
            subprocess.run(
                ["bash", str(SCRIPT), "app-server", "--listen", "stdio://"],
                env=environment,
                check=True,
            )

            self.assertEqual(
                json.loads(output.read_text()),
                {
                    "version": "26.10.0",
                    "token": "ide-test-token",
                    "args": ["app-server", "--listen", "stdio://"],
                },
            )

    def test_fails_clearly_when_no_bundled_cli_exists(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            environment = os.environ.copy()
            environment.update(
                {
                    "CODEX_SECRETS_ENV": str(ROUTER_ENV),
                    "CODEX_VSCODE_EXTENSIONS_DIR": temporary_directory,
                }
            )
            result = subprocess.run(
                ["bash", str(SCRIPT), "app-server"],
                env=environment,
                text=True,
                capture_output=True,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("no executable bundled Codex CLI found", result.stderr)


if __name__ == "__main__":
    unittest.main()
