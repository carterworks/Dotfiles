{
  pkgs,
  lib,
}:

let
  # Upstream names releases by version and commit, e.g. 3.6.6-8b85519e.
  version = "3.6.6-8b85519e";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  platformPackages = {
    aarch64-darwin = {
      arch = "arm64";
      hash = "sha256-jN9/iiTYQ/bwvs0rjqPHaoGmP9CeoROl7K4ka6qNB8k=";
    };
    x86_64-darwin = {
      arch = "x64";
      hash = "sha256-TiYf1f6czYSQlVii/y1mb6S4wKWWfJqM2weAZh4+OMc=";
    };
  };
in
packageUtils.mkPlatformBinary {
  pname = "github-desktop";
  inherit version platformPackages;

  src =
    platformPackage:
    pkgs.fetchurl {
      url = "https://desktop.githubusercontent.com/releases/${version}/GitHubDesktop-${platformPackage.arch}.zip";
      inherit (platformPackage) hash;
    };

  updateInfo = {
    source = "redirect";
    url = "https://central.github.com/deployments/desktop/desktop/latest/darwin-arm64";
    pattern = "/releases/(?<version>[^/]+)/";
  };

  nativeBuildInputs = [
    pkgs.unzip
    pkgs.makeWrapper
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # Keep the official app bundle intact so its code signature remains valid.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications" "$out/bin"
    # AppleDouble sidecars in the ZIP are not signed app resources.
    unzip -q "$src" -d "$out/Applications" -x '*/._*'
    makeWrapper /usr/bin/open "$out/bin/github-desktop" \
      --add-flags "-a \"$out/Applications/GitHub Desktop.app\" --args"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test -x "$out/Applications/GitHub Desktop.app/Contents/MacOS/GitHub Desktop"
    test -x "$out/bin/github-desktop"
    /usr/bin/codesign --verify --deep --strict "$out/Applications/GitHub Desktop.app"

    runHook postInstallCheck
  '';

  meta = {
    description = "Desktop client for GitHub repositories";
    homepage = "https://desktop.github.com/";
    license = lib.licenses.mit;
    mainProgram = "github-desktop";
  };
}
