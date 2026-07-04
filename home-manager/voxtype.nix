{ pkgs }:

{
  enable = true;
  package = pkgs.stable.voxtype-vulkan;
  loadModels = [
    "tiny.en"
  ];
  settings = {
    #     "model.base.en" = {
    #       "voice" = "en_us_001";
    #       "speed" = 1.0;
    #       "pitch" = 1.0;
    #       "volume" = 1.0;
    #       "language" = "en-US";
    #       "voice_id" = "en_us_001";
    #       "voice_name" = "en_us_001";
    #       "voice_gender" = "male";
    #     };

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
