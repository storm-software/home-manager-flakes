{ system }:

{
    config = {
        allowUnfree = true;
        allowUnsupportedSystem = true;
        experimental-features = "nix-command flakes";
    };
}
