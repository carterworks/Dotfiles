{ pkgs, lib }:

let
  version = "0.6.4";
  assets = {
    x86_64-linux = {
      url = "https://github.com/dmtrKovalenko/fff.nvim/releases/download/v${version}/fff-mcp-x86_64-unknown-linux-gnu";
      hash = "sha256-7uPDVWQ6l6134OlUgQGvuWzWm0x1GXmTOWHrLgX9zt4=";
    };
    aarch64-darwin = {
      url = "https://github.com/dmtrKovalenko/fff.nvim/releases/download/v${version}/fff-mcp-aarch64-apple-darwin";
      hash = "sha256-6esM7FhW14swOCyT5Uv7/mhUe6p6Wvh06XWqWcSQElI=";
    };
  };

  asset = assets.${pkgs.stdenv.hostPlatform.system}
    or (throw "Unsupported system for fff-mcp binary: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "fff-mcp";
  inherit version;

  src = pkgs.fetchurl asset;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m755 $src $out/bin/fff-mcp
    runHook postInstall
  '';

  meta = {
    description = "FFF MCP server - typo-resistant file search for AI agents";
    homepage = "https://github.com/dmtrKovalenko/fff.nvim";
    license = lib.licenses.mit;
    mainProgram = "fff-mcp";
    platforms = builtins.attrNames assets;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
