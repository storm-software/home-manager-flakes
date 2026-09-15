{ config, lib, ... }:

let
  reposDirectory = "${config.home.homeDirectory}/repos";

  repoDirectories =
    if builtins.pathExists reposDirectory then
      lib.attrNames (
        lib.filterAttrs (_: fileType: fileType == "directory") (builtins.readDir reposDirectory)
      )
    else
      [ ];

  repoDirectorySettings = lib.listToAttrs (
    lib.imap0 (index: directory: {
      # dircolors settings use glob patterns for filename-specific colors.
      name = "*${directory}";
      value = "38;5;${toString (16 + index)}";
    }) repoDirectories
  );
in
{
  programs.dircolors = {
    enable = true;
    settings = repoDirectorySettings;
  };
}
