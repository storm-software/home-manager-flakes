import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("secretspec-pass-cli.sh")


class SecretSpecPassCliTests(unittest.TestCase):
    def test_rewrites_proton_pass_ids_as_equals_arguments(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            record = root / "pass-cli.json"
            pass_cli = bin_dir / "pass-cli"
            pass_cli.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, pathlib, sys\n"
                "pathlib.Path(os.environ['PASS_CLI_RECORD']).write_text(json.dumps(sys.argv[1:]))\n"
            )
            pass_cli.chmod(0o755)

            result = subprocess.run(
                [
                    "bash",
                    str(SCRIPT),
                    "item",
                    "get",
                    "--item-id",
                    "-item-id",
                    "--share-id",
                    "-share-id",
                ],
                env=os.environ | {
                    "PATH": str(bin_dir) + ":" + os.environ["PATH"],
                    "PASS_CLI_RECORD": str(record),
                },
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                json.loads(record.read_text()),
                [
                    "item",
                    "get",
                    "--item-id=-item-id",
                    "--share-id=-share-id",
                ],
            )


if __name__ == "__main__":
    unittest.main()
