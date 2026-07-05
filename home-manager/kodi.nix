{ pkgs, user }:

{
  enable = true;
  # On this standalone Home Manager setup on a foreign distro (Manjaro), the
  # Nix-built `kodi-wayland` crashes at startup with
  # "failed to get EGL display (EGL_SUCCESS)" because Nix's mesa/EGL cannot
  # locate the host GPU driver ICD for the Wayland platform (no nixGL wrapper).
  # The X11 build starts reliably and runs via XWayland under Sway.
  package = pkgs.stable.kodi;
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
