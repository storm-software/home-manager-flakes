{
  pkgs,
  config,
  lib,
  ...
}:
let
  syncthingDir = "${config.home.homeDirectory}/.local/state/syncthing";
  trayIni = "${config.home.homeDirectory}/.config/syncthingtray.ini";

  syncthingTrayWrapper = pkgs.writeShellApplication {
    name = "syncthingtray-managed";
    runtimeInputs = [
      pkgs.syncthingtray-minimal
      pkgs.libxml2
      pkgs.python3
    ];
    text = ''
      syndir="${syncthingDir}"
      trayini="${trayIni}"

      export LIB_SYNCTHING_CONNECTOR_SYNCTHING_CONFIG_DIR="$syndir"

      if [[ -f "$syndir/config.xml" && -f "$trayini" ]]; then
        apikey=$(${pkgs.libxml2}/bin/xmllint --xpath 'string(configuration/gui/apikey)' "$syndir/config.xml")

        # sed treats \1 as a backreference; use prefix matching instead.
        ${pkgs.python3}/bin/python3 -c '
import sys
from pathlib import Path

trayini, apikey, syndir = sys.argv[1:4]
updates = {
    r"connections\1\apiKey=": f"connections\\1\\apiKey=@ByteArray({apikey})",
    r"connections\1\localPath=": f"connections\\1\\localPath={syndir}",
}

path = Path(trayini)
new_lines = []
for line in path.read_text().splitlines():
    for prefix, value in updates.items():
        if line.startswith(prefix):
            new_lines.append(value)
            break
    else:
        new_lines.append(line)
path.write_text("\n".join(new_lines) + "\n")
' "$trayini" "$apikey" "$syndir"
      fi

      exec ${pkgs.syncthingtray-minimal}/bin/syncthingtray --wait
    '';
  };
in
{
  home.packages = [ syncthingTrayWrapper ];

  systemd.user.services.syncthingtray-minimal = {
    Unit = {
      After = lib.mkAfter [ "syncthing.service" ];
      Wants = [ "syncthing.service" ];
    };
    serviceConfig.ExecStart = lib.mkForce "${syncthingTrayWrapper}/bin/syncthingtray-managed";
  };
}
