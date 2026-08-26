{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  hermes = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  stableDiffusionCpp = pkgs.stable-diffusion-cpp-vulkan;
  stableDiffusionWebui = self.packages.${pkgs.stdenv.hostPlatform.system}.sdcpp-webui;
  stableDiffusionModels = "${config.xdg.dataHome}/stable-diffusion.cpp/models";
  fetchStableDiffusionModels = pkgs.writeShellApplication {
    name = "fetch-stable-diffusion-models";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.python3Packages.huggingface-hub
    ];
    text = ''
      install -d -m 0755 \
        "${stableDiffusionModels}" \
        "${stableDiffusionModels}/loras" \
        "${stableDiffusionModels}/upscalers"

      hf download leejet/FLUX.2-klein-9B-GGUF \
        flux-2-klein-9b-Q4_0.gguf \
        --revision cc588497a95ffc2937ebbd6b9b3916a11ada6e5b \
        --local-dir "${stableDiffusionModels}"

      hf download unsloth/Qwen3-8B-GGUF \
        Qwen3-8B-Q4_K_M.gguf \
        --revision a6adef130ffb23ddaf1a62fec9dced968c9bc482 \
        --local-dir "${stableDiffusionModels}"

      hf download Comfy-Org/vae-text-encorder-for-flux-klein-4b \
        split_files/vae/flux2-vae.safetensors \
        --revision a9e4ca87c16db4c4e1a16406a9ddb300ab0ae246 \
        --local-dir "${stableDiffusionModels}"

      test -s "${stableDiffusionModels}/flux-2-klein-9b-Q4_0.gguf"
      test -s "${stableDiffusionModels}/Qwen3-8B-Q4_K_M.gguf"
      test -s "${stableDiffusionModels}/split_files/vae/flux2-vae.safetensors"
    '';
  };
  runStableDiffusion = pkgs.writeShellApplication {
    name = "run-stable-diffusion-cpp";
    text = ''
      ${lib.getExe fetchStableDiffusionModels}
      exec ${lib.getExe' stableDiffusionCpp "sd-server"} \
        --diffusion-model "${stableDiffusionModels}/flux-2-klein-9b-Q4_0.gguf" \
        --llm "${stableDiffusionModels}/Qwen3-8B-Q4_K_M.gguf" \
        --vae "${stableDiffusionModels}/split_files/vae/flux2-vae.safetensors" \
        --serve-html-path "${stableDiffusionWebui}/index.html" \
        --listen-ip 0.0.0.0 \
        --listen-port 7860 \
        --auto-fit \
        --max-vram -1 \
        --vae-tiling \
        --width 1024 \
        --height 1024 \
        --steps 4 \
        --cfg-scale 1.0 \
        --sampling-method euler
    '';
  };
in
{
  home.packages = [
    hermes
    stableDiffusionCpp
  ];

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

  xdg.dataFile."applications/stable-diffusion-cpp.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=stable-diffusion.cpp
    GenericName=AI Image Generator
    Exec=brave http://127.0.0.1:7860/
    Terminal=false
    Categories=Graphics;2DGraphics;
  '';

  systemd.user.services.stable-diffusion-cpp = {
    Unit = {
      Description = "stable-diffusion.cpp Vulkan server";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe' pkgs.fnox "fnox"} exec --non-interactive -- ${lib.getExe runStableDiffusion}";
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "HF_HOME=${config.xdg.cacheHome}/huggingface"
      ];
      Restart = "on-failure";
      RestartSec = "10s";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.hermes-agent = {
    Unit = {
      Description = "Hermes Agent Gateway";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = "${config.home.homeDirectory}/.hermes/config.yaml";
    };
    Service = {
      ExecStart = "${lib.getExe' pkgs.fnox "fnox"} exec --non-interactive -- ${hermes}/bin/hermes gateway run --replace";
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "HERMES_HOME=${config.home.homeDirectory}/.hermes"
        "MESSAGING_CWD=${config.home.homeDirectory}"
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      Restart = "always";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.hermes-dashboard = {
    Unit = {
      Description = "Hermes Agent Web Dashboard";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      ConditionPathExists = "${config.home.homeDirectory}/.hermes/config.yaml";
    };
    Service = {
      ExecStart = "${hermes}/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open";
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "HERMES_HOME=${config.home.homeDirectory}/.hermes"
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
