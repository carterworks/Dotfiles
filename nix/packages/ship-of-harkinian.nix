{
  pkgs,
  lib,
}:

let
  version = "9.3.1";
  assetName = "SoH-Dewey-Bravo.appimage";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  appimageSource = packageUtils.fetchGitHubRelease {
    owner = "HarbourMasters";
    repo = "Shipwright";
    tag = version;
    asset = assetName;
    inherit version;
    hash = "sha256-5Lt3XJoMNinrrFfktsy6bQtiHXGrIB6RBazu+RQa0fQ=";
  };

  appimageContents = pkgs.appimageTools.extract {
    inherit version;
    pname = "ship-of-harkinian";
    src = appimageSource;
  };
in
pkgs.appimageTools.wrapType2 rec {
  pname = "ship-of-harkinian";
  inherit version;

  src = appimageSource;

  passthru.updateInfo = {
    source = "github-release";
    owner = "HarbourMasters";
    repo = "Shipwright";
    assetPattern = "^SoH-.*\\.appimage$";
  };

  extraInstallCommands = ''
    install -Dm644 ${appimageContents}/sohIcon.png $out/share/icons/hicolor/512x512/apps/sohIcon.png
    install -Dm644 ${appimageContents}/soh.desktop $out/share/applications/soh.desktop
    substituteInPlace $out/share/applications/soh.desktop \
      --replace-fail 'Exec=soh.elf' "Exec=$out/bin/${pname}"
  '';

  meta = {
    description = "PC port of Ocarina of Time with widescreen, high-resolution, and more";
    homepage = "https://www.shipofharkinian.com";
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
    license = with lib.licenses; [
      mit
      unfree
    ];
  };
}
