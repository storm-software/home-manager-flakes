from pathlib import Path
import tomllib
import unittest


MANIFEST = Path(__file__).parents[2] / "secretspec.toml"
ITEM_PREFIX = "storm-software/agents/"
SECRET_NAMES = {
    "WEAVE_ROUTER_KEY",
    "CODEX_CHATGPT_ACCOUNT_ID",
    "CONTEXT7_AUTHORIZATION",
    "CONTEXT7_API_KEY",
    "FIRECRAWL_API_KEY",
    "GITHUB_TOKEN",
}
MINDCTL_SECRET_NAMES = {"DEEPSEEK_API_TOKEN", "MUSE_API_TOKEN", "DEEPSEEK_API_KEY", "MUSE_API_KEY"}


class CodexSecretSpecManifestTests(unittest.TestCase):
    def test_codex_profile_uses_optional_exact_proton_pass_note_items(self):
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)

        profile = manifest["profiles"]["agents"]
        self.assertEqual(profile["defaults"]["inherit"], False)
        self.assertEqual(profile["defaults"]["providers"], ["protonpass-agents"])
        self.assertEqual(set(profile) - {"defaults"}, SECRET_NAMES)
        for name in SECRET_NAMES:
            secret = profile[name]
            self.assertFalse(secret["required"])
            self.assertEqual(secret["ref"]["item"], ITEM_PREFIX + name)

    def test_mindctl_profile_limits_vault_access_to_optional_provider_credentials(self):
        with MANIFEST.open("rb") as stream:
            manifest = tomllib.load(stream)

        profile = manifest["profiles"]["mindctl"]
        self.assertEqual(profile["defaults"]["inherit"], False)
        self.assertEqual(profile["defaults"]["providers"], ["protonpass-agents"])
        self.assertEqual(set(profile) - {"defaults"}, MINDCTL_SECRET_NAMES)
        for name in MINDCTL_SECRET_NAMES:
            secret = profile[name]
            self.assertFalse(secret["required"])
            self.assertEqual(secret["ref"]["item"], ITEM_PREFIX + name)


if __name__ == "__main__":
    unittest.main()
