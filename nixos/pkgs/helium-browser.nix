{
  stdenv,
  lib,
  appimageTools,
  fetchurl,
  makeDesktopItem,
  copyDesktopItems,
}:
let
  pname = "helium-browser";
  version = "0.9.4.1"; # https://github.com/imputnet/helium/releases
  architectures = {
    "x86_64-linux" = {
      arch = "x86_64";
      hash = "sha256-N5gdWuxOrIudJx/4nYo4/SKSxakpTFvL4zzByv6Cnug=";
    };
  };
  src =
    let
      inherit (architectures.${stdenv.hostPlatform.system}) arch hash;
    in
    fetchurl {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-${arch}.AppImage";
      inherit hash;
    };
in
appimageTools.wrapType2 {
  inherit pname version src;
  nativeBuildInputs = [ copyDesktopItems ];
  desktopItems = [
    (makeDesktopItem {
      name = "helium-browser";
      desktopName = "Helium Browser";
      exec = "helium-browser";
      icon = "helium-browser";
      comment = "Private, fast, and honest web browser";
      categories = [ "Network" "WebBrowser" ];
      mimeTypes = [ "text/html" "x-scheme-handler/http" "x-scheme-handler/https" ];
    })
  ];
  meta = {
    description = "Private, fast, and honest web browser";
    homepage = "https://helium.computer";
    platforms = lib.attrNames architectures;
  };
}
