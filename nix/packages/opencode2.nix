{
  pkgs,
  lib,
}:

let
  version = "0.0.0-beta-17595";

  platformPackages = {
    aarch64-darwin = {
      target = "darwin-arm64";
      hash = "sha256-gHyepNRxN6C/k/5gqsQ4duLpkp3GlkYWb/tmf+xrFRY=";
    };
    # musl (static) so the binary runs on NixOS without autoPatchelf.
    x86_64-linux = {
      target = "linux-x64-musl";
      hash = "sha256-KOoYj7b/ejbVwzTDfNjPv6w5ZR6j5vPTEJFXEcblkHs=";
    };
  };

  platformPackage =
    platformPackages.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for opencode2: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "opencode2";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@opencode-ai/cli-${platformPackage.target}/-/cli-${platformPackage.target}-${version}.tgz";
    inherit (platformPackage) hash;
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
    platforms = builtins.attrNames platformPackages;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
