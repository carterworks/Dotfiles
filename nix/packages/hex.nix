{
  pkgs,
  lib,
  # Hex's source tree, for the desktop entry and icons its release service
  # serves only inside the app bundle.
  hexSource,
}:

let
  version = "3.3.0";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  # Fetch the prebuilt release executable and skip the Rust/Vulkan compile.
  src = packageUtils.fetchGitHubRelease {
    owner = "anomalyco";
    repo = "hex";
    asset = "hex-${version}-linux-x64";
    inherit version;
    hash = "sha256-6MezouvrHX2l1idtXyUUWJHVIXjjY2NHyzrDMfdmJiI=";
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

  # PipeWire's client-side module-rt gives Hex's audio threads a zero
  # RLIMIT_RTTIME on this host, so the kernel SIGKILLs Hex as soon as the
  # ALSA plugin promotes one. Dictation needs no realtime scheduling, so use
  # the stock client config without module-rt. The server keeps its own RT.
  pipewireClientConfig = pkgs.runCommand "hex-pipewire-client.conf" { } ''
    install -Dm644 ${pkgs.pipewire}/share/pipewire/client.conf $out/client.conf
    substituteInPlace $out/client.conf \
      --replace-fail '{ module.rt = !false }' '{ module.rt = false }'
  '';
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

  # The hex flake input supplies hexSource and must match this release.
  passthru.updateInfo = {
    source = "github-release";
    owner = "anomalyco";
    repo = "hex";
    tagPrefix = "v";
    flakeInput = "hex";
  };

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/hex
    # The GlobalShortcuts portal identifies Hex by its reverse-DNS app id,
    # anomaly.hex, which this entry has to be named after.
    install -Dm644 ${hexSource}/packaging/anomaly.hex.desktop \
      $out/share/applications/anomaly.hex.desktop
    substituteInPlace $out/share/applications/anomaly.hex.desktop \
      --replace-fail '@HEX_BIN@' "$out/bin/hex"
    mkdir -p $out/share/icons
    cp -R ${hexSource}/packaging/linux/icons/hicolor $out/share/icons/hicolor

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
      --set ALSA_PLUGIN_DIR ${alsaPluginDir} \
      --set PIPEWIRE_CONFIG_DIR ${pipewireClientConfig} \
      --set PIPEWIRE_CONFIG_NAME client.conf
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
