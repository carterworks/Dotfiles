{
  pkgs,
  lib,
}:

let
  pname = "opencode2";
  version = "0.0.0-beta-18999";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  platformPackages = {
    aarch64-darwin = {
      target = "darwin-arm64";
      hash = "sha256-3zjIGdM6OXOuedo012r5c1APH/j8GU8ipsicNoMeemI=";
    };
    # Patchelf invalidates Bun's embedded standalone-program metadata.
    # Keep the glibc artifact unchanged; NixOS provides its loader via nix-ld.
    x86_64-linux = {
      target = "linux-x64";
      hash = "sha256-iU1k9e/OTPk7ZYGJgNLmfNGSzbir1a859LGU1Bvk4Zs=";
    };
  };

in
packageUtils.mkPlatformBinary {
  inherit pname version platformPackages;

  src =
    platformPackage:
    packageUtils.fetchNpmTarball {
      name = "@opencode-ai/cli-${platformPackage.target}";
      inherit version;
      inherit (platformPackage) hash;
    };

  updateInfo = {
    source = "npm";
    package = "@opencode-ai/cli";
    channel = "beta";
  };

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/opencode2 $out/bin/opencode2

    runHook postInstall
  '';

  meta = {
    description = "AI coding agent for the terminal (v2 beta)";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    mainProgram = "opencode2";
  };
}
