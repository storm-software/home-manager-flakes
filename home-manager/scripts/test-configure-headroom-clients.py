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
    def test_codex_preserves_oauth_and_routes_through_headroom(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config_dir = home / ".codex"
            config_dir.mkdir()
            path = config_dir / "config.toml"
            path.write_text(
                'model = "gpt-5.6-luna"\n'
                '[model_providers.weave]\n'
                'env_key = "OPENAI_API_KEY"\n'
                'experimental_bearer_token = "legacy-bearer"\n'
                'http_headers = { "X-Weave-Router-Key" = "rk_test", '
                '"ChatGPT-Account-ID" = "legacy-account", "Authorization" = "Bearer old", '
                '"X-App" = "codex", "X-Weave-Force-Model" = "gpt-5.6-terra" }\n'
                '[model_providers.weave.env_http_headers]\n'
                'X-Weave-Force-Model = "WEAVE_FORCE_MODEL"\n'
            )

            clients.configure_codex(home, use_weave_router=False)

            config = tomlkit.parse(path.read_text())
            provider = config["model_providers"]["headroom"]
            self.assertEqual(config["model_provider"], "headroom")
            self.assertEqual(provider["name"], "Headroom")
            self.assertEqual(config["forced_login_method"], "chatgpt")
            self.assertEqual(config["openai_base_url"], "http://127.0.0.1:8787/v1")
            self.assertTrue(provider["requires_openai_auth"])
            self.assertTrue(provider["supports_websockets"])
            self.assertNotIn("env_key", provider)
            self.assertNotIn("experimental_bearer_token", provider)
            self.assertEqual(dict(provider["http_headers"]), {"X-App": "codex"})
            self.assertEqual(
                dict(provider["env_http_headers"]),
                {
                    "ChatGPT-Account-ID": "CODEX_CHATGPT_ACCOUNT_ID",
                },
            )

            clients.configure_codex(home, use_weave_router=False)
            reparsed = tomllib.loads(path.read_text())
            self.assertEqual(reparsed["model"], "gpt-5.6-luna")
            self.assertNotIn(
                "X-Weave-Force-Model",
                reparsed["model_providers"]["headroom"]["http_headers"],
            )
            self.assertFalse((config_dir / "config.toml.pre-headroom").exists())

    def test_codex_does_not_copy_a_preexisting_force_model_to_headroom(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config_dir = home / ".codex"
            config_dir.mkdir()
            path = config_dir / "config.toml"
            path.write_text(
                'model = "gpt-6-astra"\n'
                '[model_providers.weave]\n'
                'http_headers = { "X-Weave-Router-Key" = "rk_test", '
                '"X-Weave-Force-Model" = "gpt-5.6-terra" }\n'
            )

            clients.configure_codex(home, use_weave_router=False)

            config = tomlkit.parse(path.read_text())
            headers = config["model_providers"]["headroom"]["http_headers"]
            self.assertNotIn("X-Weave-Force-Model", headers)

    def test_codex_creates_environment_backed_headroom_provider(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            path = home / ".codex" / "config.toml"
            path.parent.mkdir()
            path.write_text('model = "gpt-5.6-terra"\n')

            clients.configure_codex(home, use_weave_router=False)

            config = tomlkit.parse(path.read_text())
            provider = config["model_providers"]["headroom"]
            self.assertEqual(config["model_provider"], "headroom")
            self.assertEqual(config["forced_login_method"], "chatgpt")
            self.assertEqual(provider["base_url"], "http://127.0.0.1:8787/v1")
            self.assertEqual(
                dict(provider["env_http_headers"]),
                {
                    "ChatGPT-Account-ID": "CODEX_CHATGPT_ACCOUNT_ID",
                },
            )

    def test_codex_keeps_weave_as_the_default_upstream(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            path = home / ".codex" / "config.toml"
            path.parent.mkdir()
            path.write_text('model = "gpt-5.6-terra"\n')

            clients.configure_codex(home, use_weave_router=True)

            config = tomlkit.parse(path.read_text())
            provider = config["model_providers"]["weave"]
            self.assertEqual(config["model_provider"], "weave")
            self.assertEqual(provider["name"], "Weave Router")
            self.assertEqual(config["openai_base_url"], "http://127.0.0.1:8080/v1")
            self.assertEqual(provider["base_url"], "http://127.0.0.1:8080/v1")
            self.assertEqual(
                dict(provider["env_http_headers"]),
                {
                    "X-Weave-Router-Key": "WEAVE_ROUTER_KEY",
                    "ChatGPT-Account-ID": "CODEX_CHATGPT_ACCOUNT_ID",
                },
            )


if __name__ == "__main__":
    unittest.main()
