{
  pkgs,
  lib,
}:

let
  pname = "t3code-cli";
  version = "0.1.7-nightly.20261031.3991";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  # The CLI is a self-contained Node SEA build. It still loads a handful of
  # native modules and its web client from directories beside the executable,
  # so the whole release tarball has to stay together. Upstream publishes
  # SHA256SUMS for these assets, but fetchurl hashes keep the package
  # independent of the checksum file's format.
  platformPackages = {
    aarch64-darwin = {
      asset = "t3-${version}-darwin-arm64.tar.gz";
      hash = "sha256-OEMPkO48aPYqOLsOJ7Scr7Y7LZi41p2AA+dNokQP3ro=";
    };
    x86_64-linux = {
      asset = "t3-${version}-linux-x64.tar.gz";
      hash = "sha256-NBvcJD5O3usXom3UFtQyQ4YeelhZFWL8dr3oruFWKWI=";
    };
  };

  platformPackage =
    platformPackages.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for ${pname}: ${pkgs.stdenv.hostPlatform.system}");

  # patchelf 0.18 and newer corrupt the Node SEA launcher's program headers,
  # so the packaged binary segfaults on startup. Keep the last known-good
  # release until upstream handles this layout.
  patchelf015 = pkgs.patchelf.overrideAttrs (_: {
    version = "0.15.2";
    src = pkgs.fetchurl {
      url = "https://github.com/NixOS/patchelf/releases/download/0.15.2/patchelf-0.15.2.tar.bz2";
      hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
    };
  });

  src = packageUtils.fetchGitHubRelease {
    owner = "pingdotgg";
    repo = "t3code";
    inherit version;
    inherit (platformPackage) asset hash;
  };

  meta = {
    description = "Command-line client for the T3 Code control surface";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "t3";
    platforms = builtins.attrNames platformPackages;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };

  updateInfo = {
    source = "github-release-channel";
    owner = "pingdotgg";
    repo = "t3code";
    channel = "nightly";
    tagPrefix = "v";
  };
in
pkgs.stdenvNoCC.mkDerivation {
  inherit
    pname
    version
    src
    meta
    ;

  # patchelf015 has to precede the hook so auto-patchelf picks it from PATH.
  nativeBuildInputs = [
    pkgs.makeWrapper
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    patchelf015
    pkgs.autoPatchelfHook
  ];
  buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.stdenv.cc.cc.lib
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # Stripping breaks the Node SEA payload embedded in the launcher.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/t3code" "$out/bin"
    tar -xzf "$src" --strip-components=1 -C "$out/lib/t3code"
    makeWrapper "$out/lib/t3code/t3" "$out/bin/t3"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test -x "$out/lib/t3code/t3"
    test -x "$out/bin/t3"
    "$out/bin/t3" --version

    runHook postInstallCheck
  '';

  passthru = { inherit updateInfo; };
}
