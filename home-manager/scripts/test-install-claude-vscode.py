import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("install-claude-vscode.sh")


class InstallClaudeVscodeTests(unittest.TestCase):
    def test_installs_once_and_preserves_existing_extension(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cli = root / "code-insiders"
            calls = root / "calls"
            cli.write_text(
                "#!/bin/sh\n"
                'printf "%s\\n" "$*" >> "$TEST_CALLS"\n'
                'if [ "$1" = "--list-extensions" ]; then\n'
                '  printf "%s\\n" "$TEST_EXTENSIONS"\n'
                "fi\n"
            )
            cli.chmod(0o755)
            environment = os.environ.copy()
            environment["TEST_CALLS"] = str(calls)

            environment["TEST_EXTENSIONS"] = "openai.chatgpt"
            first = subprocess.run(
                ["bash", str(SCRIPT), str(cli)],
                env=environment,
                capture_output=True,
                text=True,
            )
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(
                calls.read_text().splitlines(),
                ["--list-extensions", "--install-extension anthropic.claude-code"],
            )

            calls.write_text("")
            environment["TEST_EXTENSIONS"] = "openai.chatgpt\nAnthropic.claude-code"
            second = subprocess.run(
                ["bash", str(SCRIPT), str(cli)],
                env=environment,
                capture_output=True,
                text=True,
            )
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(calls.read_text().splitlines(), ["--list-extensions"])

    def test_skips_when_code_insiders_is_unavailable(self):
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "code-insiders"
            result = subprocess.run(
                ["bash", str(SCRIPT), str(missing)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
