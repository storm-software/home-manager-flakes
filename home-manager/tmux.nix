{
  pkgs,
  pkgsUnstable,
  homeDirectory,
}:

{
  enable = true;
  clock24 = true;
  escapeTime = 0;
  baseIndex = 1;
  keyMode = "vi";
  shortcut = "b";
  shell = "${pkgs.zsh}/bin/zsh";
  extraConfig = (builtins.readFile ./config/tmux.conf);
}
