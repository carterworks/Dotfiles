{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "0.6.4";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/dmtrKovalenko/fff.nvim/releases/download/v${version}/fff-mcp-aarch64-apple-darwin";
      hash = "sha256-6esM7FhW14swOCyT5Uv7/mhUe7p6Wvh06XWqWcSQElI=";
    };
    "x86_64-linux" = {
      url = "https://github.com/dmtrKovalenko/fff.nvim/releases/download/v${version}/fff-mcp-x86_64-unknown-linux-gnu";
      hash = "sha256-7uPDVWQ6l6134OlUgQGvuWzWm0x1GXmTOWHrLgX9zt4=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "fff-mcp: no prebuilt binary for ${stdenv.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "fff-mcp";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  dontUnpack = true;
  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/fff-mcp
    runHook postInstall
  '';

  meta = {
    description = "FFF MCP server - typo-resistant file search for AI agents";
    homepage = "https://github.com/dmtrKovalenko/fff.nvim";
    license = lib.licenses.mit;
    mainProgram = "fff-mcp";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
}
