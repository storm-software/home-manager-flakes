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
      --replace-fail '@codex_secrets_env@' \
      '${config.storm.codex.secretsEnvPackage}/bin/codex-secrets-env' \
      --replace-fail '@mindctl_router_setup@' \
      '${config.storm.mindctl.setupPackage}/bin/mindctl-router-setup' \
      --replace-fail '@storm_agent_setup_mode@' \
      '${pkgs.bash}/bin/bash ${./scripts/storm-agent-setup-mode.sh}'
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
