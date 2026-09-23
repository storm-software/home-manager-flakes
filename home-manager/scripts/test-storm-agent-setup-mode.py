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

    def test_missing_mode_defaults_to_mindctl(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "agent-setup.env"

            result = self.run_mode(state)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "mindctl\n")

    def test_persisted_direct_mode_overrides_boot_default(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "agent-setup.env"
            state.write_text("STORM_AGENT_ROUTER_MODE=direct\n")

            result = self.run_mode(state)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "direct\n")

    def test_legacy_disabled_weave_state_migrates_to_new_mindctl_default(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "agent-setup.env"
            state.write_text("STORM_SETUP_WEAVE_ROUTER=0\n")

            result = self.run_mode(state)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "mindctl\n")

    def test_explicit_activation_mode_takes_precedence_over_saved_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "agent-setup.env"
            state.write_text("STORM_AGENT_ROUTER_MODE=direct\n")

            result = self.run_mode(state, STORM_AGENT_ROUTER_MODE="weave")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "weave\n")

    def test_write_persists_mindctl_mode_privately(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "agent-setup.env"

            result = subprocess.run(
                ["bash", str(SCRIPT), "write", "mindctl"],
                env=os.environ | {"STORM_AGENT_SETUP_STATE": str(state)},
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(state.read_text(), "STORM_AGENT_ROUTER_MODE=mindctl\n")
            self.assertEqual(state.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
