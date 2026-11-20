{
  pkgs,
  lib,
}:

let
  pname = "ardia";
  version = "0.2.47-nightly.6";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  # Only nightlies ship a Linux build, and not every one does; the updater
  # leaves this at the last nightly that has one.
  src = packageUtils.fetchGitHubRelease {
    owner = "ardia-browser";
    repo = "ardia";
    inherit version;
    asset = "Ardia-${version}-linux-x64.AppImage";
    hash = "sha256-OQ7E753mIe/Uepa0j/I6v6Tdzxaxj5SnCubEJILo+KU=";
  };

  contents = pkgs.appimageTools.extract { inherit pname version src; };
in
pkgs.appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm644 ${contents}/share/icons/hicolor/256x256/apps/ardia.png \
      $out/share/icons/hicolor/256x256/apps/ardia.png
    install -Dm644 ${contents}/ardia.desktop $out/share/applications/ardia.desktop
    substituteInPlace $out/share/applications/ardia.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=ardia'
  '';

  passthru.updateInfo = {
    source = "github-release";
    owner = "ardia-browser";
    repo = "ardia";
    channel = "nightly";
    tagPrefix = "v";
  };

  meta = {
    description = "Chromium browser with Arc's sidebar and Dia's polish";
    homepage = "https://ardia.dev";
    changelog = "https://github.com/ardia-browser/ardia/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
