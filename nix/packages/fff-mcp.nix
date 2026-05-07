{
  pkgs,
  lib,
  fffMcpAssets,
}:

let
  version = "latest";

  platformAsset =
    fffMcpAssets.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for fff-mcp: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "fff-mcp";
  inherit version;

  src = platformAsset;

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
    platforms = builtins.attrNames fffMcpAssets;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
