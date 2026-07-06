{ pkgs, user }:

let
  stable = pkgs.stable;

  # This is standalone Home Manager on a foreign distro (Manjaro) running a
  # Wayland session (KWin + XWayland). Two problems had to be solved:
  #
  # 1. Nix-built Kodi couldn't initialise OpenGL/EGL ("failed to get egl
  #    display") because Nix's mesa can't locate the host GPU driver ICD.
  #    -> nixGLIntel wraps the launcher and exports the correct GL driver
  #       paths before exec'ing Kodi; child processes inherit them.
  #
  # 2. Kodi's X11/GLX backend crashes under XWayland ("Visual ... is not
  #    suitable", "GLX Error: vInfo is NULL!" -> SIGSEGV) because GLX visual
  #    selection is broken on XWayland.
  #    -> Use the native Wayland backend (kodi-wayland), which talks to the
  #       compositor directly via EGL and avoids the broken GLX path.
  kodiPackage = stable.kodi-wayland;
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
    fullscreen = "false";
  };

  sources = {
    video = {
      default = "movies";
      source = [
        {
          name = "movies";
          path = "${user.system.homeDirectory}/media/movies";
          allowsharing = "true";
        }
        {
          name = "tv";
          path = "${user.system.homeDirectory}/media/tv";
          allowsharing = "true";
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

  #   addonSettings = {
  #     "service.xbmc.versioncheck" = {
  #       versioncheck_enable = "false";
  #     };
  #   };
}
