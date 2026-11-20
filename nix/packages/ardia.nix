{
  pkgs,
  lib,
}:

let
  pname = "ardia";
  version = "0.2.47-nightly.9";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  # Only nightlies ship a Linux build, so both platforms follow them.
  platformPackages = {
    aarch64-darwin = {
      asset = "Ardia-${version}.zip";
      hash = "sha256-kYDEpJE7qE9mMcd2r6i72uJu4Yf+AdkIfAxKsEr2bdU=";
    };
    x86_64-linux = {
      asset = "Ardia-${version}-linux-x64.AppImage";
      hash = "sha256-Iav2Aq2RNQV6dtZq2ox0RxYt4WtPcKbMHwzbKPR9miw=";
    };
  };

  src = packageUtils.fetchGitHubRelease {
    owner = "ardia-browser";
    repo = "ardia";
    inherit version;
    inherit (packageUtils.selectPlatformPackage pname platformPackages) asset hash;
  };

  meta = {
    description = "Chromium browser with Arc's sidebar and Dia's polish";
    homepage = "https://ardia.dev";
    changelog = "https://github.com/ardia-browser/ardia/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    mainProgram = pname;
    platforms = builtins.attrNames platformPackages;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };

  passthru.updateInfo = {
    source = "github-release";
    owner = "ardia-browser";
    repo = "ardia";
    channel = "nightly";
    tagPrefix = "v";
    # Not every nightly has a Linux build; wait for one that has both.
    requiredAssets = [
      "\\.zip$"
      "-linux-x64\\.AppImage$"
    ];
  };
in
if pkgs.stdenv.hostPlatform.isDarwin then
  pkgs.stdenvNoCC.mkDerivation {
    inherit
      pname
      version
      src
      meta
      passthru
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

    # Upstream names the bundle Netnyahoo.app; the signature does not cover
    # the bundle's own name.
    installPhase = ''
      runHook preInstall

      unzip -q "$src" -d unpacked
      mkdir -p "$out/Applications" "$out/bin"
      mv unpacked/*.app "$out/Applications/Ardia.app"
      makeWrapper "$out/Applications/Ardia.app/Contents/MacOS/Ardia" "$out/bin/ardia"

      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      /usr/bin/codesign --verify --deep --strict "$out/Applications/Ardia.app"

      runHook postInstallCheck
    '';
  }
else
  let
    contents = pkgs.appimageTools.extract { inherit pname version src; };
  in
  pkgs.appimageTools.wrapType2 {
    inherit
      pname
      version
      src
      meta
      passthru
      ;

    extraInstallCommands = ''
      install -Dm644 ${contents}/share/icons/hicolor/256x256/apps/ardia.png \
        $out/share/icons/hicolor/256x256/apps/ardia.png
      install -Dm644 ${contents}/ardia.desktop $out/share/applications/ardia.desktop
      substituteInPlace $out/share/applications/ardia.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=ardia'
    '';
  }
