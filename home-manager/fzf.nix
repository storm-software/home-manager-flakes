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
    info = "#539bf5";
    prompt = "#6cb6ff";
    pointer = "#f47067";
    marker = "#39c5cf";
    spinner = "#b083f0";
    header = "#1fb2a6";
  };
  tmux.enableShellIntegration = true;
}
