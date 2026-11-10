{
  pkgs,
  lib,
}:

let
  pname = "fnox";
  version = "1.42.1";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  platformPackages = {
    aarch64-darwin = {
      assetName = "fnox-aarch64-apple-darwin.tar.gz";
      hash = "sha256-Bs0A4GaVjUnZauE38hYrks+wpm5Otanm760yowa/i5U=";
    };
    # musl (static) so the binary runs on NixOS without autoPatchelf.
    x86_64-linux = {
      assetName = "fnox-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-bsAaDI3FfabQuI1x6mtPZcf47jx0x0BTLQi4mwlMun8=";
    };
  };

in
packageUtils.mkPlatformBinary {
  inherit pname version platformPackages;

  src =
    platformPackage:
    packageUtils.fetchGitHubRelease {
      owner = "jdx";
      repo = "fnox";
      asset = platformPackage.assetName;
      inherit version;
      inherit (platformPackage) hash;
    };

  updateInfo = {
    source = "github-release";
    owner = "jdx";
    repo = "fnox";
    tagPrefix = "v";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 fnox $out/bin/fnox

    runHook postInstall
  '';

  meta = {
    description = "Flexible secret management tool supporting multiple providers and encryption methods";
    homepage = "https://github.com/jdx/fnox";
    license = lib.licenses.mit;
    mainProgram = "fnox";
  };
}
