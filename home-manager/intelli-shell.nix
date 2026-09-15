{
  config,
  lib,
  pkgs,
  ...
}:

let
  intelliShell = pkgs.rustPlatform.buildRustPackage rec {
    pname = "intelli-shell";
    version = "3.4.5";

    src = pkgs.fetchFromGitHub {
      owner = "lasantosr";
      repo = "intelli-shell";
      rev = "v${version}";
      hash = "sha256-jC5hvyefEEU8odiPaUWtWm8o2oHyS7ZOw4nJdvylb0U=";
    };

    # Package managers should not install a self-updating binary. Keep the
    # useful tldr integration and build its native dependencies reproducibly.
    cargoBuildFlags = [
      "--no-default-features"
      "--features"
      "extra-features,vendored"
    ];
    cargoHash = pkgs.lib.fakeHash;

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.openssl ];

    meta = {
      description = "Like IntelliSense, but for shells";
      homepage = "https://lasantosr.github.io/intelli-shell/";
      license = lib.licenses.apache2;
      mainProgram = "intelli-shell";
    };
  };
in
{
  home.packages = [ intelliShell ];

  xdg.configFile."intelli-shell/config.toml".text = ''
    # IntelliShell AI configuration. The API key is intentionally read from
    # the runtime environment instead of being stored in this file or Nix.
    [ai]
    enabled = true

    [ai.models]
    suggest = "main"
    fix = "main"
    import = "main"
    completion = "main"
    fallback = "fallback"

    [ai.catalog.main]
    provider = "gemini"
    model = "gemini-flash-lite-latest"

    [ai.catalog.fallback]
    provider = "openai"
    model = "deepseek-chat"
    url = "https://api.deepseek.com"
    api_key_env = "DEEPSEEK_API_KEY"
  '';

  programs.zsh.initContent = lib.mkAfter ''
    eval "$(intelli-shell init zsh)"
  '';
}
