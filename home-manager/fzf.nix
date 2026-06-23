{
  enable = true;
  enableZshIntegration = true;
  defaultOptions = [
    "--height 60%"
    "--border"
    "--style full"
  ];
  colors = {
    fg = "#adbac7";
    hl = "#3be4be";
    "fg+" = "#ffffff";
    "hl+" = "#3be4be";
    info = "#3be4be";
    label = "#3be4be";
    prompt = "#3be4be";
    pointer = "#3be4be";
    marker = "#3be4be";
    spinner = "#3be4be";
    header = "#3be4be";
    footer = "#3be4be";
    ghost = "#acffec";
  };
  tmux.enableShellIntegration = true;
}
