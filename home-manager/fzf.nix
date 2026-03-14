{
  enable = true;
  enableZshIntegration = true;
  defaultOptions = [
    "--height 40%"
    "--border"
  ];
  colors = {
    fg = "#adbac7";
    bg = "#22272e";
    hl = "#3be4be";
    "fg+" = "#cdd9e5";
    "bg+" = "#2d333b";
    "hl+" = "#56d4dd";
    info = "#1fb2a6";
    prompt = "#39c5cf";
    pointer = "#1fb2a6";
    marker = "#39c5cf";
    spinner = "#1fb2a6";
    header = "#1fb2a6";
  };
  tmux.enableShellIntegration = true;
}
