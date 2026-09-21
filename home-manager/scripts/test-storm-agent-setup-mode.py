import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("storm-agent-setup-mode.sh")


class StormAgentSetupModeTests(unittest.TestCase):
    def run_mode(self, state: Path, **extra_env: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(SCRIPT)],
            env=os.environ | {"STORM_AGENT_SETUP_STATE": str(state)} | extra_env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_persisted_disabled_mode_overrides_boot_default(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "agent-setup.env"
            state.write_text("STORM_SETUP_WEAVE_ROUTER=0\n")

            result = self.run_mode(state)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "0\n")

    def test_explicit_activation_mode_takes_precedence_over_saved_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "agent-setup.env"
            state.write_text("STORM_SETUP_WEAVE_ROUTER=0\n")

            result = self.run_mode(state, STORM_SETUP_WEAVE_ROUTER="1")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "1\n")


if __name__ == "__main__":
    unittest.main()
