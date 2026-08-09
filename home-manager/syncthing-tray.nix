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
      pkgs.gnused
    ];
    text = ''
      syndir="${syncthingDir}"
      trayini="${trayIni}"

      export LIB_SYNCTHING_CONNECTOR_SYNCTHING_CONFIG_DIR="$syndir"

      if [[ -f "$syndir/config.xml" && -f "$trayini" ]]; then
        apikey=$(${pkgs.libxml2}/bin/xmllint --xpath 'string(configuration/gui/apikey)' "$syndir/config.xml")
        ${pkgs.gnused}/bin/sed -i \
          "s|^connections\\\\1\\\\apiKey=.*|connections\\\\1\\\\apiKey=@ByteArray(''${apikey})|" \
          "$trayini"
        ${pkgs.gnused}/bin/sed -i \
          "s|^connections\\\\1\\\\localPath=.*|connections\\\\1\\\\localPath=${syncthingDir}|" \
          "$trayini"
      fi

      exec ${pkgs.syncthingtray-minimal}/bin/syncthingtray --wait
    '';
  };
in
{
  home.packages = [ syncthingTrayWrapper ];

  systemd.user.services.syncthingtray-minimal.serviceConfig.ExecStart =
    lib.mkForce "${syncthingTrayWrapper}/bin/syncthingtray-managed";
}
