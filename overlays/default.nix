{
  buildGoLinux = final: prev: {
    buildGoModule = prev.buildGoModule.override {
      go = prev.go // {
        CGO_ENABLED = 0;
        GOOS = "linux";
        GOARCH = "arm64";
      };
    };
  };

  go = final: prev: {
    go = prev.go_1_25;
  };

  node = final: prev: rec {
    nodejs = prev.nodejs_24;
    pnpm = prev.pnpm.override {
      inherit nodejs;
    };
  };

  rust = final: prev: {
    devRust = prev.pkgs.rust-bin.beta.latest.default;
  };
}
