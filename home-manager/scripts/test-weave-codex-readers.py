"""Exercise only extracted Codex credential readers against synthetic TOML."""

import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(sys.argv.pop(1))


def function(source, name):
    match = re.search(rf"^{name}\(\) \{{\n.*?^\}}", source, re.M | re.S)
    if not match:
        raise AssertionError(f"Missing function {name}")
    return match.group()


class CodexReadersTest(unittest.TestCase):
    def test_credentials(self):
        installer = (SOURCE / "install/install.sh").read_text()
        canonical = (SOURCE / "install/codex-status.sh").read_text()
        readers = {
            "installer": (
                function(installer, "key_source_is_own")
                + "\n"
                + function(installer, "read_codex_key"),
                'scope=user; read_codex_key "$1/config.toml"',
            ),
            "canonical": (function(canonical, "read_codex_endpoint"), 'read_codex_endpoint'),
            "fallback": (function(installer, "read_codex_endpoint"), 'read_codex_endpoint'),
        }
        cases = [
            ("env-inline", 'env_http_headers = { "X-Weave-Router-Key" = "FIXTURE_WEAVE_KEY" }', "synthetic-key"),
            ("env-table", '[model_providers.weave.env_http_headers]\nX-Weave-Router-Key = "FIXTURE_WEAVE_KEY"', "synthetic-key"),
            ("static-inline", 'http_headers = { "X-Weave-Router-Key" = "legacy-key" }', "legacy-key"),
            ("static-table", '[model_providers.weave.http_headers]\nX-Weave-Router-Key = "legacy-key"', "legacy-key"),
            ("env-inline-unset", 'env_http_headers = { "X-Weave-Router-Key" = "UNSET_FIXTURE_KEY" }', ""),
            ("env-table-unset", '[model_providers.weave.env_http_headers]\nX-Weave-Router-Key = "UNSET_FIXTURE_KEY"', ""),
            ("env-inline-empty", 'env_http_headers = { "X-Weave-Router-Key" = "EMPTY_FIXTURE_KEY" }', ""),
            ("env-table-empty", '[model_providers.weave.env_http_headers]\nX-Weave-Router-Key = "EMPTY_FIXTURE_KEY"', ""),
            ("invalid-env-name", 'env_http_headers = { "X-Weave-Router-Key" = "$(false)" }', ""),
            ("unrelated-table", '[model_providers.other.env_http_headers]\nX-Weave-Router-Key = "FIXTURE_WEAVE_KEY"', ""),
            ("env-over-static", 'http_headers = { "X-Weave-Router-Key" = "legacy-key" }\nenv_http_headers = { "X-Weave-Router-Key" = "FIXTURE_WEAVE_KEY" }', "synthetic-key"),
            ("missing-env-over-static", 'http_headers = { "X-Weave-Router-Key" = "legacy-key" }\nenv_http_headers = { "X-Weave-Router-Key" = "UNSET_FIXTURE_KEY" }', ""),
        ]
        with tempfile.TemporaryDirectory(prefix="weave-reader-test-") as directory:
            config = Path(directory) / "config.toml"
            for case, headers, key in cases:
                config.write_text('[model_providers.weave]\nbase_url = "http://fixture.invalid/v1"\n' + headers + '\n')
                for reader, (definitions, invocation) in readers.items():
                    with self.subTest(case=case, reader=reader):
                        result = subprocess.run(
                            ["bash", "--noprofile", "--norc", "-c", 'set -euo pipefail\nhelper_dir="$1"\n' + definitions + "\n" + invocation, "weave-reader-test", directory],
                            env={"PATH": os.environ["PATH"], "FIXTURE_WEAVE_KEY": "synthetic-key", "EMPTY_FIXTURE_KEY": ""},
                            capture_output=True, text=True, check=True,
                        )
                        expected = key + "\n" if key else ""
                        if key and reader != "installer":
                            expected = "http://fixture.invalid/v1\n" + expected
                        self.assertEqual(result.stdout, expected)


if __name__ == "__main__":
    unittest.main()
