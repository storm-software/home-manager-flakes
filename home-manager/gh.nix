{ gitUser }:

{
  gitCredentialHelper = {
    enable = true;
  };

  prompt = "enabled";

  settings = {
    git_protocol = "https";
    editor = "code";
  };

  hosts = {
    "github.com" = {
      gitProtocol = "https";
      user = gitUser.name;
    };
  };
}
