{ pkgs }:

{
  enable = true;
  autostart = true;
  package = pkgs.keepassxc;
  settings = {
    General.ConfigVersion = 2;
    Browser.Enabled = true;
    GUI = {
      AdvancedSettings = true;
      ApplicationTheme = "dark";
      CompactMode = true;
      HidePasswords = true;
    };
    SSHAgent.Enabled = true;
  };
}
