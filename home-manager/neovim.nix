{ pkgs }:

{
  enable = true;
  package = pkgs.stable.neovim-unwrapped;
  vimAlias = true;

  extraConfig = (builtins.readFile ./config/.vimrc);

  # Neovim plugins
  plugins = with pkgs.stable.vimPlugins; [
    ctrlp
    editorconfig-vim
    gruvbox
    nerdtree
    tabular
    vim-nix
    vim-markdown
  ];
}
