{ homeDirectory, substituteAll }:

{
    enable = true;
    enableCompletion = true;
    enableVteIntegration = true;

    autosuggestion.enable = false;

    history = {
        append = true;
        share = true;
        save = 90000;
        size = 90000;
        ignoreDups = true;
        saveNoDups = true;
        extended = true;
    };

    initExtra = (builtins.readFile ./scripts/init.sh);
    shellAliases = (import ./aliases.nix { inherit homeDirectory; }).shell;
}

