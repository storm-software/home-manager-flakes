import importlib.util
from pathlib import Path
import tempfile
import tomllib
import unittest

import tomlkit


spec = importlib.util.spec_from_file_location(
    "configure_headroom_clients",
    Path(__file__).with_name("configure-headroom-clients.py"),
)
clients = importlib.util.module_from_spec(spec)
spec.loader.exec_module(clients)


class ConfigureHeadroomClientsTests(unittest.TestCase):
    def test_codex_preserves_oauth_and_routes_directly_through_weave(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config_dir = home / ".codex"
            config_dir.mkdir()
            path = config_dir / "config.toml"
            path.write_text(
                'model = "gpt-5.6-luna"\n'
                '[model_providers.weave]\n'
                'requires_openai_auth = true\n'
                'http_headers = { "X-Weave-Router-Key" = "rk_test", '
                '"X-Weave-User-Name" = "test", "X-App" = "codex"}\n'
            )

            clients.configure_codex(home)

            config = tomlkit.parse(path.read_text())
            provider = config["model_providers"]["weave"]
            self.assertEqual(config["model_provider"], "weave")
            self.assertEqual(config["openai_base_url"], "http://127.0.0.1:8080/v1")
            self.assertTrue(provider["requires_openai_auth"])
            self.assertFalse(provider["supports_websockets"])
            self.assertNotIn("env_key", provider)
            self.assertEqual(provider["http_headers"]["X-Weave-Router-Key"], "rk_test")
            self.assertEqual(provider["http_headers"]["X-Weave-User-Name"], "test")
            self.assertEqual(provider["http_headers"]["X-App"], "codex")
            self.assertEqual(provider["http_headers"]["X-Weave-Force-Model"], "gpt-5.6-luna")

            clients.configure_codex(home)
            reparsed = tomllib.loads(path.read_text())
            self.assertEqual(reparsed["model"], "gpt-5.6-luna")
            self.assertEqual(
                reparsed["model_providers"]["weave"]["http_headers"][
                    "X-Weave-Force-Model"
                ],
                "gpt-5.6-luna",
            )

    def test_codex_falls_back_to_subscription_backed_model(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config_dir = home / ".codex"
            config_dir.mkdir()
            path = config_dir / "config.toml"
            path.write_text(
                'model = "gpt-6-astra"\n'
                '[model_providers.weave]\n'
                'http_headers = { "X-Weave-Router-Key" = "rk_test" }\n'
            )

            clients.configure_codex(home)

            config = tomlkit.parse(path.read_text())
            headers = config["model_providers"]["weave"]["http_headers"]
            self.assertEqual(headers["X-Weave-Force-Model"], "gpt-5.6-sol")

    def test_codex_refuses_to_drop_local_router_auth(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config_dir = home / ".codex"
            config_dir.mkdir()
            path = config_dir / "config.toml"
            path.write_text('model = "gpt-5.6-sol"\n')

            with self.assertRaisesRegex(SystemExit, "no Weave router key"):
                clients.configure_codex(home)


if __name__ == "__main__":
    unittest.main()
