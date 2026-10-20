{
  pkgs,
  lib,
}:

let
  pname = "t3code-cli";
  version = "0.1.1-nightly.20261019.3373";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  # The CLI is a self-contained Node SEA build. It still loads a handful of
  # native modules and its web client from directories beside the executable,
  # so the whole release tarball has to stay together. Upstream publishes
  # SHA256SUMS for these assets, but fetchurl hashes keep the package
  # independent of the checksum file's format.
  platformPackages = {
    aarch64-darwin = {
      asset = "t3-${version}-darwin-arm64.tar.gz";
      hash = "sha256-nx+7HyibkMuDWBvfiKorjsxFsUoyn5paO2088Kfa/5w=";
    };
    x86_64-linux = {
      asset = "t3-${version}-linux-x64.tar.gz";
      hash = "sha256-OrPekVT9FyS+SAD6AdPfCQb/o1+j56ftHE1xELnHqGY=";
    };
  };

  platformPackage =
    platformPackages.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for ${pname}: ${pkgs.stdenv.hostPlatform.system}");

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

  nativeBuildInputs = [
    pkgs.makeWrapper
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];
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
