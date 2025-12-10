{ homeDirectory, pkgs }:

{
    # git-sync = {
    #     enable = true;
    #     package = pkgs.git-sync;
    #     repositories = {
    #         storm-ops = {
    #             path = "${homeDirectory}/repos/storm-ops";
    #             uri = "git@github.com:storm-software/storm-ops.git";
    #             interval = 1000;
    #         };
    #         stryke = {
    #             path = "${homeDirectory}/repos/stryke";
    #             uri = "git@github.com:storm-software/stryke.git";
    #             interval = 1000;
    #         };
    #         powerlines = {
    #             path = "${homeDirectory}/repos/powerlines";
    #             uri = "git@github.com:storm-software/powerlines.git";
    #             interval = 1000;
    #         };
    #         earthquake = {
    #             path = "${homeDirectory}/repos/earthquake";
    #             uri = "git@github.com:storm-software/earthquake.git";
    #             interval = 1000;
    #         };
    #         acidic = {
    #             path = "${homeDirectory}/repos/acidic";
    #             uri = "git@github.com:storm-software/acidic.git";
    #             interval = 1000;
    #         };
    #     };
    # };

    gpg-agent = {
        enable = true;
        defaultCacheTtl = 1800;
        maxCacheTtl = 7200;
        maxCacheTtlSsh = 7200;
        grabKeyboardAndMouse = true;
        pinentry = {
            package = pkgs.pinentry-gnome3;
            program = "pinentry-gnome3";
        };
        enableSshSupport = true;
        enableZshIntegration = true;
    };
}
