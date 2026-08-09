# Wrap the generated activate script so `./result/activate` accepts the same
# backup flags as `home-manager switch -b backup`.
{
  home.extraBuilderCommands = ''
    mv $out/activate $out/activate-inner
    cp ${./scripts/activate-wrapper.sh} $out/activate
    chmod +x $out/activate
  '';
}
