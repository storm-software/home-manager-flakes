{
  pkgs,
  pkgsUnstable,
  homeDirectory,
}:

{
  enable = true;
  autostart = true;
  package = pkgsUnstable.keepassxc;
  settings = {
    General = {
      ConfigVersion = 2;
      BackupBeforeSave = true;
      DefaultDatabaseFileName = "${homeDirectory}/sync/vault/vault.kdbx";
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
