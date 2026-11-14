{
  pkgs,
  lib,
}:

let
  pname = "t3code-cli";
  version = "0.1.10-nightly.20261114.4682";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  # The CLI is a self-contained Node SEA build. It still loads a handful of
  # native modules and its web client from directories beside the executable,
  # so the whole release tarball has to stay together. Upstream publishes
  # SHA256SUMS for these assets, but fetchurl hashes keep the package
  # independent of the checksum file's format.
  platformPackages = {
    aarch64-darwin = {
      asset = "t3-${version}-darwin-arm64.tar.gz";
      hash = "sha256-qNkx7naY/jy8DJL9I4QsyJXldzxMG06wP89RKLt3CYY=";
    };
    x86_64-linux = {
      asset = "t3-${version}-linux-x64.tar.gz";
      hash = "sha256-qd8s3FoH8kgp/PtP/Zq5HlB/FipVH34cg2miSEUmvCA=";
    };
  };
in
packageUtils.mkPlatformBinary {
  inherit pname version platformPackages;

  src =
    platformPackage:
    packageUtils.fetchGitHubRelease {
      owner = "pingdotgg";
      repo = "t3code";
      inherit version;
      inherit (platformPackage) asset hash;
    };

  updateInfo = {
    source = "github-release";
    owner = "pingdotgg";
    repo = "t3code";
    channel = "nightly";
    tagPrefix = "v";
  };

  nativeBuildInputs = [
    pkgs.makeWrapper
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.patchelf
    pkgs.autoPatchelfHook
  ];
  buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.stdenv.cc.cc.lib
    pkgs.vulkan-loader
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
    # The tarball also carries musl builds of its native modules, which
    # autoPatchelf cannot satisfy against glibc and the launcher never loads
    # on a glibc host. koffi names its variant directory musl_x64 instead of
    # suffixing the package name.
    find "$out/lib/t3code/node_modules" -depth \( -name '*-musl' -o -name 'musl_*' \) -exec rm -rf {} +
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

  meta = {
    description = "Command-line client for the T3 Code control surface";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "t3";
  };
}
