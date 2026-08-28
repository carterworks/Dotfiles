{
  pkgs,
  lib,
}:

let
  pname = "fff-mcp";
  version = "0.10.5";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  platformPackages = {
    aarch64-darwin = {
      assetName = "fff-mcp-aarch64-apple-darwin";
      hash = "sha256-Lxp1wkAeXff1oQgn+c6f6EAfKQ/5nD8/FCPH17FW2Ek=";
    };
    # musl (static) so the binary runs on NixOS without autoPatchelf.
    x86_64-linux = {
      assetName = "fff-mcp-x86_64-unknown-linux-musl";
      hash = "sha256-arT0Ee7ug+fjkARQsju1AXLk+T0k3HICZRJvDDobHyM=";
    };
  };

in
packageUtils.mkPlatformBinary {
  inherit pname version platformPackages;

  src =
    platformPackage:
    packageUtils.fetchGitHubRelease {
      owner = "dmtrKovalenko";
      repo = "fff";
      asset = platformPackage.assetName;
      inherit version;
      inherit (platformPackage) hash;
    };

  updateInfo = {
    source = "github-release";
    owner = "dmtrKovalenko";
    repo = "fff";
    tagPrefix = "v";
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
  };
}
