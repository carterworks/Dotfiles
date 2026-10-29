{
  lib,
  ...
}:

{
  programs.mangohud = {
    enable = true;
    settings = {
      fps = true;
      fps_metrics = "avg,0.01";
      frametime = true;
      frame_timing = lib.mkForce false;
      frame_timing_detailed = false;
      dynamic_frame_timing = false;

      cpu_stats = true;
      cpu_temp = true;
      cpu_load_change = true;
      cpu_load_value = "60,90";
      core_load = true;
      core_load_change = true;
      core_bars = true;

      gpu_stats = true;
      gpu_temp = true;
      gpu_load_change = true;
      gpu_load_value = "60,90";

      ram = true;
      vram = true;

      fsr = true;
      refresh_rate = true;

      position = "top-right";
      table_columns = 3;
      toggle_hud = "Shift_L+F10";
      background_alpha = lib.mkForce 0.25;
      background_color = lib.mkForce "000000";
      text_outline = lib.mkForce false;
    };
  };

  xdg.dataFile."applications/brave-agent.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=Brave Browser (Agent)
    GenericName=Web Browser with CDP
    Exec=brave --password-store=kwallet6 --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 %U
    TryExec=brave
    Terminal=false
    Categories=Network;WebBrowser;
    MimeType=text/html;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
  '';
}
