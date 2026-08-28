{
  pkgs,
  lib,
}:

let
  pname = "opencode2";
  version = "0.0.0-beta-18414";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  platformPackages = {
    aarch64-darwin = {
      target = "darwin-arm64";
      hash = "sha256-uNQdXEoKTrxyOk4Sw5TcO2mBuh8EqkKe/uZ1uFK+w3w=";
    };
    # Patchelf invalidates Bun's embedded standalone-program metadata.
    # Use the glibc artifact unchanged and start it with Nix's loader.
    x86_64-linux = {
      target = "linux-x64";
      hash = "sha256-CF56/bFAM+ZzaNFpo+L6RgYzrgyMBqRsX73PMzQ+LoU=";
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

  nativeBuildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    ${
      if pkgs.stdenv.hostPlatform.isLinux then
        ''
          install -Dm755 bin/opencode2 $out/libexec/opencode2
          makeWrapper ${pkgs.stdenv.cc.bintools.dynamicLinker} $out/bin/opencode2 \
            --add-flags $out/libexec/opencode2
        ''
      else
        ''
          install -Dm755 bin/opencode2 $out/bin/opencode2
        ''
    }

    runHook postInstall
  '';

  meta = {
    description = "AI coding agent for the terminal (v2 beta)";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    mainProgram = "opencode2";
  };
}
