{
  pkgs,
  lib,
}:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "delta";
  version = "0.19.2";

  src = pkgs.fetchurl {
    url = "https://releases.delta.dev/releases/stable/${version}/macos/aarch64/Delta.app.zip";
    hash = "sha256-K5FcED9/Bx7nJhs1XZoDcCtaQWPin2K6FSa/SvPejT4=";
  };

  nativeBuildInputs = [
    pkgs.unzip
    pkgs.makeWrapper
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # Keep the official app bundle intact so its code signature remains valid.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    unzip -q "$src" -d "$out/Applications" -x '*/._*'
    makeWrapper "$out/Applications/Delta.app/Contents/MacOS/delta" "$out/bin/delta" \
      --set DELTA_UPDATE_EXPLANATION \
        "Delta is managed by Nix; update your package definition to install a newer release."

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test -x "$out/Applications/Delta.app/Contents/MacOS/delta-app"
    test -x "$out/Applications/Delta.app/Contents/MacOS/delta"
    test -x "$out/bin/delta"
    /usr/bin/codesign --verify --deep --strict "$out/Applications/Delta.app"

    runHook postInstallCheck
  '';

  meta = {
    description = "Delta, the AI coding assistant";
    homepage = "https://delta.dev";
    license = lib.licenses.unfree;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "delta";
  };
}
