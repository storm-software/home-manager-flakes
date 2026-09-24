import subprocess
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("configure-codex-vscode.py")


class ConfigureCodexVscodeTests(unittest.TestCase):
    def run_configurer(self, settings: Path, launcher: str):
        return subprocess.run(
            ["python3", str(SCRIPT), str(settings), launcher],
            text=True,
            capture_output=True,
        )

    def test_adds_setting_without_losing_comments_or_trailing_commas(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            settings = Path(temporary_directory) / "User" / "settings.json"
            settings.parent.mkdir(parents=True)
            original = """{
  // Keep this explanation.
  "editor.fontSize": 15,
}
"""
            settings.write_text(original)

            result = self.run_configurer(settings, "/nix/store/example/bin/codex-vscode")

            self.assertEqual(result.returncode, 0, result.stderr)
            updated = settings.read_text()
            self.assertIn("// Keep this explanation.", updated)
            self.assertIn('"editor.fontSize": 15,', updated)
            self.assertIn(
                '"chatgpt.cliExecutable": "/nix/store/example/bin/codex-vscode"',
                updated,
            )

            repeated = self.run_configurer(
                settings, "/nix/store/example/bin/codex-vscode"
            )
            self.assertEqual(repeated.returncode, 0, repeated.stderr)
            self.assertEqual(settings.read_text(), updated)

    def test_updates_only_existing_cli_executable_value(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            settings = Path(temporary_directory) / "settings.json"
            settings.write_text(
                """{
  "chatgpt.cliExecutable": "/old/path", // preserve inline comment
  "workbench.colorTheme": "Default Dark Modern",
}
"""
            )

            result = self.run_configurer(settings, "/new/path")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                settings.read_text(),
                """{
  "chatgpt.cliExecutable": "/new/path", // preserve inline comment
  "workbench.colorTheme": "Default Dark Modern",
}
""",
            )

    def test_refuses_malformed_or_non_object_settings_without_overwriting(self):
        for original in ("{ broken", "[]\n"):
            with self.subTest(original=original):
                with tempfile.TemporaryDirectory() as temporary_directory:
                    settings = Path(temporary_directory) / "settings.json"
                    settings.write_text(original)

                    result = self.run_configurer(settings, "/new/path")

                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(settings.read_text(), original)


if __name__ == "__main__":
    unittest.main()
