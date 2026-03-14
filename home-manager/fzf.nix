{
  enable = true;
  enableZshIntegration = true;
  defaultOptions = [
    "--height 60%"
    "--border"
    "--scheme history"
    "--style full"
  ];
  colors = {
    fg = "#adbac7";
    bg = "#22272e";
    hl = "#3be4be";
    "fg+" = "#cdd9e5";
    "bg+" = "#2d333b";
    "hl+" = "#56d4dd";
    info = "#1fb2a6";
    label = "#1fb2a6";
    prompt = "#39c5cf";
    pointer = "#1fb2a6";
    marker = "#39c5cf";
    spinner = "#1fb2a6";
    header = "#1fb2a6";
    footer = "#1fb2a6";
    ghost = "#a3f2e0";
  };
  tmux.enableShellIntegration = true;
}
