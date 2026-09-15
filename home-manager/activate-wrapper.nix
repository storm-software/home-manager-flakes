# Wrap the generated activate script so `./result/activate` accepts the same
# backup flags as `home-manager switch -b backup`.
{
  config,
  pkgs,
  ...
}:
let
  activateWrapper = pkgs.runCommand "activate-wrapper" { } ''
    substitute ${./scripts/activate-wrapper.sh} "$out" \
      --replace-fail '@codex_router_env@' \
      '${config.storm.codex.routerEnvPackage}/bin/codex-router-env'
    chmod +x "$out"
  '';
in
{
  home.extraBuilderCommands = ''
    mv $out/activate $out/activate-inner
    cp ${activateWrapper} $out/activate
    chmod +x $out/activate
  '';
}
