{ pkgs, user }:

let
  stable = pkgs.stable;

  # On this standalone Home Manager setup on a foreign distro (Manjaro), the
  # Nix-built Kodi fails to initialize OpenGL/EGL ("failed to get egl display",
  # "GLX Error: vInfo is NULL!") because Nix's mesa cannot locate the host GPU
  # driver ICD. nixGLIntel wraps the launcher so it exports the correct GL
  # driver paths before exec'ing Kodi; child processes (kodi-x11) inherit them.
  kodiPackage = stable.kodi;
  kodiWrapped = stable.symlinkJoin {
    name = "kodi-nixgl-${kodiPackage.version}";
    paths = [ kodiPackage ];
    nativeBuildInputs = [ stable.makeWrapper ];
    postBuild = ''
      rm -f "$out/bin/kodi"
      makeWrapper "${stable.nixgl.nixGLIntel}/bin/nixGLIntel" "$out/bin/kodi" \
        --add-flags "${kodiPackage}/bin/kodi"
    '';
  };
in
{
  enable = true;
  package = kodiWrapped;
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
