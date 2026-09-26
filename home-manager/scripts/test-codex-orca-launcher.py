import subprocess
import unittest
from pathlib import Path

REPOSITORY = Path(__file__).resolve().parents[2]
ORCA_CODEX_SOURCE = (
    'path:.#homeConfigurations.development.config.home.file.".local/bin/codex".source'
)


class CodexOrcaLauncherTests(unittest.TestCase):
    def test_home_manager_owns_orca_launcher(self):
        result = subprocess.run(
            ["nix", "eval", "--raw", ORCA_CODEX_SOURCE],
            cwd=REPOSITORY,
            text=True,
            capture_output=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        launcher = Path(result.stdout)
        self.assertTrue(launcher.is_file(), launcher)
        self.assertTrue(launcher.stat().st_mode & 0o111, launcher)


if __name__ == "__main__":
    unittest.main()
