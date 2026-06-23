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
    # bg = "#1e2023";
    hl = "#3be4be";
    "fg+" = "#cdd9e5";
    # "bg+" = "#1e2023";
    "hl+" = "#56d4dd";
    info = "#38bdf8";
    label = "#3be4be";
    prompt = "#39c5cf";
    pointer = "#3be4be";
    marker = "#39c5cf";
    spinner = "#3be4be";
    header = "#3be4be";
    footer = "#3be4be";
    ghost = "#acffec";
  };
  tmux.enableShellIntegration = true;
}
