{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "ship-of-harkinian";
  version = "9.3.1";

  src = fetchurl {
    url = "https://github.com/HarbourMasters/Shipwright/releases/download/${version}/SoH-Dewey-Bravo.appimage";
    hash = "sha256-5Lt3XJoMNinrrFfktsy6bQtiHXGrIB6RBazu+RQa0fQ=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

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
