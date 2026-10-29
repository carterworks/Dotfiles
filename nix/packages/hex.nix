{
  pkgs,
  lib,
}:

let
  version = "0.0.0-dev-213";

  # Hex publishes no stable Linux release, and its flake builds the Rust/Vulkan
  # app from source. The release service serves the same executable under a
  # content-addressed path, so fetch that and skip the compile.
  src = pkgs.fetchurl {
    url = "https://anoma.ly/release/hex/files/842f8ab6eb01a6868bbfe587d2fed8ffcab7ec3ffb06354e9d99fb6f7c29ac86/hex";
    hash = "sha256-hC+KtusBpoaLv+WH0v7Y/8q37D/7BjVOnZn7b3wprIY=";
  };

  # Match upstream's package so the prebuilt binary resolves the same PipeWire
  # and ALSA plugins a source build would.
  alsaPluginDir = pkgs.symlinkJoin {
    name = "hex-alsa-plugins";
    paths = [
      "${pkgs.pipewire}/lib/alsa-lib"
      "${pkgs.alsa-plugins}/lib/alsa-lib"
    ];
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "hex";
  inherit version src;

  nativeBuildInputs = [
    pkgs.autoPatchelfHook
    # After autoPatchElf: it rewrites RPATH wholesale, which would drop the
    # driver path if this hook ran first.
    pkgs.autoAddDriverRunpath
    pkgs.makeWrapper
  ];
  buildInputs = [
    pkgs.alsa-lib
    pkgs.libxkbcommon
    pkgs.stdenv.cc.cc.lib
    pkgs.vulkan-loader
  ];
  # wgpu loads the host's Vulkan driver at runtime.
  runtimeDependencies = [ pkgs.vulkan-loader ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/hex
    # The GlobalShortcuts portal identifies Hex by this desktop entry.
    mkdir -p $out/share/applications
    cat > $out/share/applications/hex.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Hex
    Comment=Local voice dictation
    Exec=$out/bin/hex
    Icon=audio-input-microphone
    Terminal=false
    Categories=Utility;Accessibility;
    StartupNotify=true
    Actions=quit;

    [Desktop Action quit]
    Name=Quit Hex
    Exec=$out/bin/hex quit
    EOF

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/hex \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.curl
          pkgs.wl-clipboard
          pkgs.wtype
        ]
      } \
      --set ALSA_PLUGIN_DIR ${alsaPluginDir}
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/hex" --version
    runHook postInstallCheck
  '';

  meta = {
    description = "Local-first voice dictation (Linux beta)";
    homepage = "https://github.com/anomalyco/hex";
    license = lib.licenses.mit;
    mainProgram = "hex";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
