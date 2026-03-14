{ pkgs }:

{
  enable = true;
  autostart = true;
  package = pkgs.keepassxc;
  settings = {
    General = {
      ConfigVersion = 2;
      BackupBeforeSave = true;
      OpenPreviousDatabasesOnStartup = true;
      RememberLastDatabases = true;
      RememberLastKeyFiles = true;
      NumberOfRememberedLastDatabases = 5;
      BackupFilePathPattern = "{DB_FILENAME}.backup.kdbx";
    };
    Browser = {
      Enabled = true;
      Browser_AllowLocalhostWithPasskeys = true;
    };
    GUI = {
      AdvancedSettings = true;
      ApplicationTheme = "light";
      HidePasswords = true;
      CheckForUpdatesIncludeBetas = true;
      LaunchAtStartup = true;
    };
    SSHAgent = {
      Enabled = true;
      UseOpenSSH = true;
    };
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
