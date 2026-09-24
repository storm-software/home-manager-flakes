from pathlib import Path
import re
import unittest


SOURCE = Path(__file__).with_name("..") / "mindctl-router.nix"


class MindctlRouterPackageTests(unittest.TestCase):
    def test_builds_responses_gateway_from_the_pinned_compatibility_source(self):
        source = SOURCE.read_text()

        self.assertIn('version = "0.1.6";', source)
        self.assertIn("pkgs.buildGoModule", source)
        self.assertIn('rev = "7ca5657";', source)
        self.assertIn('hash = "sha256-EEZvoT9F/CElGVVY3tpVsGoEIMGbsJSBmhFnd3SbWYQ=";', source)
        self.assertRegex(source, r'vendorHash = "sha256-[A-Za-z0-9+/]{43}=";')
        self.assertIn("doCheck = false;", source)
        self.assertNotIn("releaseSources =", source)
        self.assertNotIn("pkgs.fetchurl", source)


if __name__ == "__main__":
    unittest.main()
