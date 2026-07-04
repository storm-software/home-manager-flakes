{ pkgs }:

{
  enable = true;
  package = pkgs.stable.voxtype-vulkan;
  loadModels = [
    "tiny.en"
  ];
  settings = {
    output = {
      fallback_to_clipboard = true;
      mode = "type";
    };
    whisper = {
      language = "en";
      model = "tiny.en";
      context_window_optimization = true;
    };
    hotkey = {
      key = "SPACE";
      modifiers = "LEFTCTRL";
    };
  };
  wayland.display = "wayland-1";
}
