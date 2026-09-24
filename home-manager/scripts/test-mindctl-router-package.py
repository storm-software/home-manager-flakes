from pathlib import Path
import re
import unittest


SOURCE = Path(__file__).with_name("..") / "mindctl-router.nix"


class MindctlRouterPackageTests(unittest.TestCase):
    def test_builds_responses_gateway_from_the_pinned_compatibility_source(self):
        source = SOURCE.read_text()

        self.assertIn('version = "0.1.7";', source)
        self.assertIn("pkgs.buildGoModule", source)
        self.assertIn('rev = "v${version}";', source)
        self.assertRegex(source, r'hash = "sha256-[A-Za-z0-9+/]{43}=";')
        self.assertRegex(source, r'vendorHash = "sha256-[A-Za-z0-9+/]{43}=";')
        self.assertNotIn("doCheck = false;", source)
        self.assertNotIn("releaseSources =", source)
        self.assertNotIn("pkgs.fetchurl", source)


if __name__ == "__main__":
    unittest.main()
