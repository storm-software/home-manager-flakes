{
  themes = {
    storm-software = {
      background = "#22272e";
      foreground = "#adbac7";
      selection-background = "#3be4be";
      selection-foreground = "#22272e";
      cursor-color = "#1fb2a6";
      cursor-text = "#3be4be";
      palette = [
        "0=#545d68"
        "1=#f47067"
        "2=#3be4be"
        "3=#c69026"
        "4=#539bf5"
        "5=#b083f0"
        "6=#39c5cf"
        "7=#909dab"
        "8=#636e7b"
        "9=#ff938a"
        "10=#6bc46d"
        "11=#daaa3f"
        "12=#6cb6ff"
        "13=#dcbdfb"
        "14=#56d4dd"
        "15=#cdd9e5"

      ];
    };

    settings = {
      theme = "storm-software";
      font-size = 12;
      keybind = [
        "ctrl+h=goto_split:left"
        "ctrl+l=goto_split:right"
      ];
      title-report = true;
    };

    systemd.enable = true;
    enableZshIntegration = true;
    enable = true;
  };
}
