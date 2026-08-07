{
  pkgs,
  lib,
}:

let
  version = "0.10.3";

  platformPackages = {
    aarch64-darwin = {
      assetName = "fff-mcp-aarch64-apple-darwin";
      hash = "sha256-jFKs8elVQPAs9VV5Em6/WAz0ivFcduHJAwHCyMWsvPk=";
    };
    # musl (static) so the binary runs on NixOS without autoPatchelf.
    x86_64-linux = {
      assetName = "fff-mcp-x86_64-unknown-linux-musl";
      hash = "sha256-iCNHZpmXfz2/41GGLwgxY4EPZmVlIgB8u2W+FAxxmUw=";
    };
  };

  platformPackage =
    platformPackages.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for fff-mcp: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "fff-mcp";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/dmtrKovalenko/fff/releases/download/v${version}/${platformPackage.assetName}";
    inherit (platformPackage) hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/fff-mcp

    runHook postInstall
  '';

  meta = {
    description = "MCP server for fff, the fast file search toolkit for AI agents";
    homepage = "https://github.com/dmtrKovalenko/fff";
    license = lib.licenses.mit;
    mainProgram = "fff-mcp";
    platforms = builtins.attrNames platformPackages;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
