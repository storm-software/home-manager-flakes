from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("install-codex-config.sh")
TEMPLATE_TEXT = 'model = "gpt-5.6-terra"\nmodel_provider = "weave"\n'


def run_installer(template: Path, home: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(SCRIPT), str(template), str(home)],
        text=True,
        capture_output=True,
        check=False,
    )


class InstallCodexConfigTests(unittest.TestCase):
    def test_replaces_valid_legacy_file_without_secret_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            codex_dir = home / ".codex"
            codex_dir.mkdir(parents=True)
            template = root / "template.toml"
            template.write_text(TEMPLATE_TEXT)
            legacy = codex_dir / "config.toml"
            legacy.write_text(
                '[model_providers.weave]\nhttp_headers = { X = "secret" }\n'
            )

            result = run_installer(template, home)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(legacy.read_text(), TEMPLATE_TEXT)
            self.assertEqual(legacy.stat().st_mode & 0o777, 0o600)
            self.assertFalse((codex_dir / "config.toml.pre-codex").exists())

    def test_refuses_invalid_existing_toml(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            codex_dir = home / ".codex"
            codex_dir.mkdir(parents=True)
            template = root / "template.toml"
            template.write_text(TEMPLATE_TEXT)
            legacy = codex_dir / "config.toml"
            legacy.write_text("[invalid")

            result = run_installer(template, home)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("invalid TOML", result.stderr)
            self.assertEqual(legacy.read_text(), "[invalid")

    def test_replaces_a_store_style_symlink_with_a_regular_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            codex_dir = home / ".codex"
            codex_dir.mkdir(parents=True)
            template = root / "template.toml"
            template.write_text(TEMPLATE_TEXT)
            old_target = root / "old-store-config.toml"
            old_target.write_text('model = "old"\n')
            legacy = codex_dir / "config.toml"
            legacy.symlink_to(old_target)

            result = run_installer(template, home)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(legacy.is_symlink())
            self.assertEqual(legacy.read_text(), TEMPLATE_TEXT)
            self.assertEqual(old_target.read_text(), 'model = "old"\n')

    def test_reports_but_preserves_an_existing_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "home"
            codex_dir = home / ".codex"
            codex_dir.mkdir(parents=True)
            template = root / "template.toml"
            template.write_text(TEMPLATE_TEXT)
            backup = codex_dir / "config.toml.pre-weave"
            backup.write_text("historical-private-config\n")

            result = run_installer(template, home)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(str(backup), result.stderr)
            self.assertEqual(backup.read_text(), "historical-private-config\n")


if __name__ == "__main__":
    unittest.main()
