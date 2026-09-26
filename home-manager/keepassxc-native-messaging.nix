{ pkgs, pkgsUnstable, ... }:

let
  hostName = "org.keepassxc.keepassxc_browser";
  hostFile = "${hostName}.json";
  browserProxy = "${pkgsUnstable.keepassxc}/bin/keepassxc-proxy";
  vivaldiProxy = pkgs.writeTextFile {
    name = "keepassxc-vivaldi-proxy";
    executable = true;
    text = "#!/bin/sh\n" + ''
      unset LD_PRELOAD
      exec ${browserProxy} "$@"
    '';
  };
  chromiumOrigins = [
    "chrome-extension://pdffhmdngciaglkoonimfcmckehcpafo/"
    "chrome-extension://oboonakemofpalcgghocfoadofidjkkk/"
  ];
  chromiumManifest =
    proxy:
    builtins.toJSON {
      name = hostName;
      description = "KeePassXC integration with native messaging support";
      path = proxy;
      type = "stdio";
      allowed_origins = chromiumOrigins;
    };
  otherChromiumBrowsers = [
    "chromium"
    "BraveSoftware/Brave-Browser"
    "microsoft-edge"
  ];
in
{
  xdg.configFile =
    builtins.listToAttrs (
      map (browser: {
        name = "${browser}/NativeMessagingHosts/${hostFile}";
        value = {
          force = true;
          text = chromiumManifest browserProxy;
        };
      }) otherChromiumBrowsers
    )
    // {
      "vivaldi/NativeMessagingHosts/${hostFile}" = {
        force = true;
        text = chromiumManifest "${vivaldiProxy}";
      };
    };

  home.file.".mozilla/native-messaging-hosts/${hostFile}" = {
    force = true;
    text = builtins.toJSON {
      name = hostName;
      description = "KeePassXC integration with native messaging support";
      path = browserProxy;
      type = "stdio";
      allowed_extensions = [ "keepassxc-browser@keepassxc.org" ];
    };
  };
}
