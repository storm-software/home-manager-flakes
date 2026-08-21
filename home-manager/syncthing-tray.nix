{
  pkgs,
  config,
  lib,
  ...
}:
let
  syncthingDir = "${config.home.homeDirectory}/.local/state/syncthing";
  trayIni = "${config.home.homeDirectory}/.config/syncthingtray.ini";

  trayService = {
    Unit = {
      After = lib.mkAfter [ "syncthing.service" ];
      Wants = [ "syncthing.service" ];
    };
    Service.ExecStart = lib.mkForce "${syncthingTrayWrapper}/bin/syncthingtray-managed";
  };

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

              if [[ -f "$syndir/config.xml" ]]; then
              apikey=$(${pkgs.libxml2}/bin/xmllint --xpath 'string(configuration/gui/apikey)' "$syndir/config.xml")

              mkdir -p "$(dirname "$trayini")"

              ${pkgs.python3}/bin/python3 - "$trayini" "$apikey" "$syndir" <<'PY'
      import sys
      from pathlib import Path

      trayini, apikey, syndir = sys.argv[1:4]
      updates = {
          r"connections\1\apiKey=": f"connections\\1\\apiKey=@ByteArray({apikey})",
          r"connections\1\localPath=": f"connections\\1\\localPath={syndir}",
          r"connections\1\syncthingUrl=": "connections\\1\\syncthingUrl=http://127.0.0.1:8384",
          r"connections\size=": "connections\\size=1",
      }

      path = Path(trayini)
      lines = path.read_text().splitlines() if path.exists() else ["[tray]"]
      new_lines = []
      seen = set()
      tray_index = None
      for line in lines:
          if line == "[tray]":
              tray_index = len(new_lines)

          for prefix, value in updates.items():
              if line.startswith(prefix):
                  new_lines.append(value)
                  if tray_index is not None:
                      seen.add(prefix)
                  break
          else:
              new_lines.append(line)

      if tray_index is None:
          new_lines.append("[tray]")
          tray_index = len(new_lines) - 1

      missing_values = [value for prefix, value in updates.items() if prefix not in seen]
      new_lines[tray_index + 1:tray_index + 1] = missing_values

      path.write_text("\n".join(new_lines) + "\n")
      PY
            fi

            exec ${pkgs.syncthingtray-minimal}/bin/syncthingtray --wait
    '';
  };
in
{
  home.packages = [ syncthingTrayWrapper ];

  systemd.user.services = {
    syncthingtray = trayService;
    syncthingtray-minimal = trayService;
  };
}
