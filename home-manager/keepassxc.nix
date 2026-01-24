{ pkgs }:

{
  enable = true;
  autostart = true;
  package = pkgs.keepassxc;
  settings = {
    General = {
      ConfigVersion = 2;
      BackupBeforeSave = true;
      BackupFilePathPattern = "{DB_FILENAME}.backup.kdbx";
    };
    Browser = {
      Enabled = true;
      Browser_AllowLocalhostWithPasskeys = true;
    };
    GUI = {
      AdvancedSettings = true;
      ApplicationTheme = "dark";
      HidePasswords = true;
      CheckForUpdatesIncludeBetas = true;
    };
    SSHAgent.Enabled = true;
    Security = {
      HideTotpPreviewPanel = true;
      IconDownloadFallback = true;
    };
    KeeShare = {
      QuietSuccess = true;
    };
    FdoSecrets = {
      Enabled = true;
    };
  };
}
