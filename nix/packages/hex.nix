{
  pkgs,
  lib,
  # Hex's source tree, for the desktop entry and icons its release service
  # serves only inside the app bundle.
  hexSource,
}:

let
  pname = "hex";
  version = "3.4.0";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  # Fetch the prebuilt releases and skip the Rust/Vulkan compile.
  platformPackages = {
    aarch64-darwin = {
      asset = "hex-${version}-macos-arm64.zip";
      hash = "sha256-GrAkLcO7ARyIVokDy/Hp0wMQhnpG9RaDCYU9b4tMplA=";
    };
    x86_64-linux = {
      asset = "hex-${version}-linux-x64";
      hash = "sha256-f4EyoiAjOMG1LDYRPSPXQDz5HyILzb2e7IK8cm9fgCk=";
    };
  };
  platformPackage = packageUtils.selectPlatformPackage pname platformPackages;

  src = packageUtils.fetchGitHubRelease {
    owner = "anomalyco";
    repo = "hex";
    inherit version;
    inherit (platformPackage) asset hash;
  };

  # The hex flake input supplies hexSource and must match this release.
  updateInfo = {
    source = "github-release";
    owner = "anomalyco";
    repo = "hex";
    tagPrefix = "v";
    flakeInput = "hex";
  };

  meta = {
    description = "Local-first voice dictation";
    homepage = "https://github.com/anomalyco/hex";
    license = lib.licenses.mit;
    mainProgram = "hex";
    platforms = builtins.attrNames platformPackages;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
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
if pkgs.stdenv.hostPlatform.isDarwin then
  pkgs.stdenvNoCC.mkDerivation {
    inherit
      pname
      version
      src
      meta
      ;

    nativeBuildInputs = [
      pkgs.unzip
      pkgs.makeWrapper
    ];

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    # Keep the notarised bundle byte-identical so its signature stays valid.
    dontFixup = true;

    passthru = { inherit updateInfo; };

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications" "$out/bin"
      unzip -q "$src" -d "$out/Applications" -x '*/._*'
      makeWrapper "$out/Applications/Hex.app/Contents/MacOS/hex" "$out/bin/hex"

      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      test -x "$out/bin/hex"
      /usr/bin/codesign --verify --deep --strict "$out/Applications/Hex.app"

      runHook postInstallCheck
    '';
  }
else
  pkgs.stdenvNoCC.mkDerivation {
    inherit
      pname
      version
      src
      meta
      ;

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
      pkgs.openssl
      pkgs.stdenv.cc.cc.lib
      pkgs.vulkan-loader
    ];
    # wgpu loads the host's Vulkan driver at runtime.
    runtimeDependencies = [ pkgs.vulkan-loader ];

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    passthru = { inherit updateInfo; };

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
  }
