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
            "printf '%s\\n' 'activate-inner' >> \"$ACTIVATION_LOG\"",
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

    def test_imports_codex_environment_between_router_and_headroom(self):
        result = self.run_activate("--skip-displaylink")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.log.read_text().splitlines(),
            [
                "activate-inner",
                "systemctl --user restart weave-router.service",
                "codex-secrets-env import",
                "systemctl --user restart headroom.service",
                "weave-router-login-codex",
            ],
        )

    def test_skip_weave_router_skips_services_import_and_login(self):
        result = self.run_activate("--skip-displaylink", "--skip-weave-router")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ["activate-inner"])


if __name__ == "__main__":
    unittest.main()
