"""Inspect generated setup/compose artifacts without invoking either command."""

import json
from pathlib import Path
import re
import sys


def main():
    profile = Path(sys.argv[1])
    setup = (profile / "bin/weave-router-setup").read_text()
    compose_wrapper = (profile / "bin/weave-router-compose").read_text()

    def export(name):
        return re.search(rf"^export {name}=(\S+)$", setup, re.M).group(1)

    source = export("WEAVE_SOURCE")
    revision = export("WEAVE_REVISION")
    image = export("WEAVE_IMAGE")
    fingerprint = Path(source).name.split("-", 1)[0]
    assert re.fullmatch(r"[0-9a-z]{32}", fingerprint), fingerprint
    assert image != f"weave-router:{revision}-codex-oauth-routing", image
    assert image == f"weave-router:{revision}-{fingerprint}", image
    compose_path = re.search(r" -f (\S+) ", compose_wrapper).group(1)
    server = json.loads(Path(compose_path).read_text())["services"]["server"]
    assert server["image"] == image, server["image"]
    assert server["build"]["context"] == source
    assert server["build"]["args"]["ROUTER_SHA"] == revision
    print(f"image fingerprint and compose/setup consistency passed: {image}")
    print(f"patched source: {source}")
    print(f"compose: {compose_path}")


if __name__ == "__main__":
    main()
