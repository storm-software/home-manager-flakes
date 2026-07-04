{ pkgs, user }:

{
  enable = true;
  package = pkgs.kodi-wayland;
  datadir = "${user.system.homeDirectory}/.kodi";

  # package = pkgs.kodi.withPackages (exts: [ exts.pvr-iptvsimple ]);

  settings = {
    videolibrary = {
      showemptytvshows = "true";
      moviefolderfirst = "true";
    };
    audiolibrary = {
      albumsortingmethod = "1";
    };
  };

  sources = {
    video = {
      default = "movies";
      source = [
        {
          name = "movies";
          path = "${user.system.homeDirectory}/media/movies";
          allowsharing = "false";
        }
        {
          name = "tv";
          path = "${user.system.homeDirectory}/media/tv";
          allowsharing = "false";
        }
      ];
    };
    music = {
      default = "music";
      source = [
        {
          name = "music";
          path = "${user.system.homeDirectory}/media/music";
          allowsharing = "false";
        }
      ];
    };
  };

  # addonSettings = {
  #   "service.xbmc.versioncheck" = {
  #     versioncheck_enable = "false";
  #   };
  # };
}
