{
  pkgs,
  lib,
}:

let
  version = "3.4.3";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };
  src = packageUtils.fetchGitHubRelease {
    owner = "vorssaint";
    repo = "vorssaint-utils";
    inherit version;
    asset = "Vorssaint-${version}.dmg";
    hash = "sha256-0dWUNflJU5lorcvJqiVFprkGELdTv4Q9gRPIVhWiA5Y=";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "vorssaint";
  inherit version src;

  nativeBuildInputs = [ pkgs.undmg ];

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R "Vorssaint.app" "$out/Applications/"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -d "$out/Applications/Vorssaint.app"
    /usr/bin/codesign --verify --deep --strict "$out/Applications/Vorssaint.app"
    runHook postInstallCheck
  '';

  passthru.updateInfo = {
    source = "github-release";
    owner = "vorssaint";
    repo = "vorssaint-utils";
    tagPrefix = "v";
  };

  meta = {
    description = "Free and open-source macOS menu bar toolkit";
    homepage = "https://github.com/vorssaint/vorssaint-utils";
    license = lib.licenses.gpl3Plus;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
