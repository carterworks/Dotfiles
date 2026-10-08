{
  pkgs,
  lib,
}:

let
  version = "3.6.6";
  release = "${version}-8b85519e";
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
  platformPackage =
    platformPackages.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for github-desktop: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "github-desktop";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://desktop.githubusercontent.com/releases/${release}/GitHubDesktop-${platformPackage.arch}.zip";
    inherit (platformPackage) hash;
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
    platforms = builtins.attrNames platformPackages;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "github-desktop";
  };
}
