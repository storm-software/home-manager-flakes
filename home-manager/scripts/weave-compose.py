"""Adapt the pinned upstream stack without copying its deployment graph."""
import json
from pathlib import Path
import sys

import yaml

source, state, keygen = map(Path, sys.argv[1:4])
revision = sys.argv[4]
image = sys.argv[5]
stack = yaml.safe_load((source / "docker-compose.yml").read_text())
services = stack["services"]
del services["hmm-sidecar"]
for service in services.values():
    service.pop("ports", None)
    service.pop("env_file", None)
    service["volumes"] = [
        str(source / volume[2:]) if volume.startswith("./") else
        f"{source}:/app:ro" if volume == ".:/app" else volume
        for volume in service.get("volumes", [])
    ]
services["postgres"]["environment"]["POSTGRES_PASSWORD"] = "${POSTGRES_PASSWORD:?}"
services["postgres"]["restart"] = "unless-stopped"
services["pubsub-emulator"]["restart"] = "unless-stopped"
dsn = "postgres://router:${POSTGRES_PASSWORD:?}@postgres:5432/router?sslmode=disable"
services["migrate"]["command"][1] = f"-database={dsn}&search_path=router"
for name in ("server", "seed"):
    services[name]["environment"]["DATABASE_URL"] = dsn
server = services["server"]
server["build"]["context"] = str(source)
server["build"]["args"] = {"ROUTER_SHA": revision}
server["image"] = image
server["ports"] = ["127.0.0.1:8080:8080"]
server["env_file"] = [str(state / "secrets.env"), str(state / "providers.env")]
server["environment"]["ROUTER_DEPLOYMENT_MODE"] = "selfhosted"
server["environment"]["ROUTER_SUBSCRIPTION_POOLS_ENABLED"] = "true"
server["environment"]["WV_CAPTURE_CONTENT"] = "off"
services["seed"]["volumes"].append(f"{keygen}:/keygen.go:ro")
json.dump(stack, sys.stdout, indent=2)
