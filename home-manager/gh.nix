{ currentUser }:

{
  gitCredentialHelper = {
    enable = true;
  };

  settings = {
    git_protocol = "https";
    editor = "code-insiders";
  };

  hosts = {
    "github.com" = {
      gitProtocol = "https";
      user = currentUser.name;
    };
  };
}
