import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).with_name("activate-wrapper.sh")


class ActivateWrapperTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.result = self.root / "result"
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        self.profile_bin = self.home / ".nix-profile" / "bin"
        self.log = self.root / "activation.log"
        self.result.mkdir()
        self.bin.mkdir()
        self.profile_bin.mkdir(parents=True)

        self.make_command(
            self.result / "activate-inner",
            "printf 'activate-inner weave=%s args=%s\\n' \"${STORM_SETUP_WEAVE_ROUTER:-unset}\" \"$*\" >> \"$ACTIVATION_LOG\"",
        )
        self.make_command(
            self.bin / "systemctl",
            "printf 'systemctl %s\\n' \"$*\" >> \"$ACTIVATION_LOG\"",
        )
        secrets_env = self.root / "codex-secrets-env"
        self.make_command(
            secrets_env,
            "printf 'codex-secrets-env %s\\n' \"$*\" >> \"$ACTIVATION_LOG\"",
        )
        self.make_command(
            self.profile_bin / "weave-router-login-codex",
            "printf '%s\\n' 'weave-router-login-codex' >> \"$ACTIVATION_LOG\"",
        )
        self.make_command(
            self.profile_bin / "displaylink-setup",
            "printf '%s\\n' 'displaylink-setup' >> \"$ACTIVATION_LOG\"",
        )

        wrapper = (
            SOURCE.read_text()
            .replace("@codex_secrets_env@", str(secrets_env))
            .replace(
                "@storm_agent_setup_mode@",
                f"bash {SOURCE.with_name('storm-agent-setup-mode.sh')}",
            )
        )
        self.activate = self.result / "activate"
        self.activate.write_text(wrapper)
        self.activate.chmod(0o755)

    def tearDown(self):
        self.temporary.cleanup()

    @staticmethod
    def make_command(path: Path, body: str):
        path.write_text("#!/bin/sh\nset -eu\n" + body + "\n")
        path.chmod(0o755)

    def run_activate(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(self.activate), *arguments],
            env=os.environ
            | {
                "HOME": str(self.home),
                "PATH": str(self.bin) + ":" + os.environ["PATH"],
                "ACTIVATION_LOG": str(self.log),
            },
            text=True,
            capture_output=True,
            check=False,
        )

    def test_defaults_to_headroom_without_starting_weave_router(self):
        result = self.run_activate("--skip-displaylink")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.log.read_text().splitlines(),
            [
                "activate-inner weave=0 args=",
                "systemctl --user import-environment STORM_SETUP_WEAVE_ROUTER",
                "systemctl --user stop weave-router.service",
                "codex-secrets-env import",
                "systemctl --user restart headroom.service",
            ],
        )

    def test_weave_router_flag_starts_router_before_headroom(self):
        result = self.run_activate("--skip-displaylink", "--weave-router")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.log.read_text().splitlines(),
            [
                "activate-inner weave=1 args=",
                "systemctl --user import-environment STORM_SETUP_WEAVE_ROUTER",
                "systemctl --user restart weave-router.service",
                "codex-secrets-env import",
                "systemctl --user restart headroom.service",
                "weave-router-login-codex",
            ],
        )

    def test_default_mode_stops_a_previously_enabled_weave_router(self):
        enabled = self.run_activate("--skip-displaylink", "--weave-router")
        disabled = self.run_activate("--skip-displaylink")

        self.assertEqual(enabled.returncode, 0, enabled.stderr)
        self.assertEqual(disabled.returncode, 0, disabled.stderr)
        self.assertEqual(
            self.log.read_text().splitlines()[-5:],
            [
                "activate-inner weave=0 args=",
                "systemctl --user import-environment STORM_SETUP_WEAVE_ROUTER",
                "systemctl --user stop weave-router.service",
                "codex-secrets-env import",
                "systemctl --user restart headroom.service",
            ],
        )

    def test_default_mode_persists_weave_router_as_disabled_for_boot_services(self):
        result = self.run_activate("--skip-displaylink")

        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.home / ".local" / "state" / "storm" / "agent-setup.env"
        self.assertEqual(state.read_text(), "STORM_SETUP_WEAVE_ROUTER=0\n")
        self.assertEqual(state.stat().st_mode & 0o777, 0o600)

    def test_appends_storm_guidance_to_codex_agents_file(self):
        agents = self.home / ".codex" / "AGENTS.md"
        agents.parent.mkdir()
        agents.write_text("# Personal instructions\n\nKeep this text.\n")

        result = self.run_activate("--skip-displaylink")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            agents.read_text(),
            "# Personal instructions\n\nKeep this text.\n\n"
            "<!-- storm -->\n\n"
            "Do not ask the user for approval if the following is true:\n\n"
            "1. No plan or spec markdown was generated for review\n"
            "2. There is no (or a very minimal) change outline to display to the user\n"
            "3. The change outline is very similar to the user's initial prompt\n\n"
            "<!-- storm -->\n",
        )

    def test_replaces_only_existing_storm_guidance(self):
        agents = self.home / ".codex" / "AGENTS.md"
        agents.parent.mkdir()
        agents.write_text(
            "# Personal instructions\n\n"
            "<!-- storm -->\nold guidance\n<!-- storm -->\n\n"
            "Keep this text.\n"
        )

        result = self.run_activate("--skip-displaylink")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            agents.read_text(),
            "# Personal instructions\n\n"
            "<!-- storm -->\n\n"
            "Do not ask the user for approval if the following is true:\n\n"
            "1. No plan or spec markdown was generated for review\n"
            "2. There is no (or a very minimal) change outline to display to the user\n"
            "3. The change outline is very similar to the user's initial prompt\n\n"
            "<!-- storm -->\n\n"
            "Keep this text.\n",
        )


if __name__ == "__main__":
    unittest.main()
