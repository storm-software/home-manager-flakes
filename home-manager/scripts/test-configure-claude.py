import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "configure_claude",
    Path(__file__).with_name("configure-claude.py"),
)
claude = importlib.util.module_from_spec(spec)
spec.loader.exec_module(claude)


class ConfigureClaudeTests(unittest.TestCase):
    def test_uses_subscription_without_an_api_key(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            path = home / ".claude" / "settings.json"
            path.parent.mkdir()
            path.write_text(
                json.dumps(
                    {
                        "permissions": {"allow": ["Bash(git status)"]},
                        "env": {
                            "ANTHROPIC_API_KEY": "legacy-api-key",
                            "KEEP_ME": "preserved",
                        },
                    }
                )
            )

            claude.configure(home)

            settings = json.loads(path.read_text())
            self.assertEqual(settings["permissions"], {"allow": ["Bash(git status)"]})
            self.assertNotIn("ANTHROPIC_API_KEY", settings["env"])
            self.assertEqual(settings["env"]["ANTHROPIC_BASE_URL"], claude.HEADROOM_URL)
            self.assertEqual(settings["env"]["ENABLE_TOOL_SEARCH"], "true")
            self.assertEqual(settings["env"]["KEEP_ME"], "preserved")

    def test_refuses_to_overwrite_invalid_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            path = home / ".claude" / "settings.json"
            path.parent.mkdir()
            path.write_text("{ invalid JSON")

            with self.assertRaisesRegex(SystemExit, "invalid JSON"):
                claude.configure(home)

            self.assertEqual(path.read_text(), "{ invalid JSON")


if __name__ == "__main__":
    unittest.main()
