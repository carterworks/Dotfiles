{
  pkgs,
  lib,
}:

let
  version = "0.0.0-beta-18155";

  platformPackages = {
    aarch64-darwin = {
      target = "darwin-arm64";
      hash = "sha256-A7yOErS3BHPVHKdsBuR5r1AEiIajhN1UPeHmQHbNQGY=";
    };
    # The musl artifact is dynamically linked and requires GNU libstdc++.
    # Use the glibc artifact and patch its loader/RPATH for NixOS.
    x86_64-linux = {
      target = "linux-x64";
      hash = "sha256-1Bf8t3ay5Nj5m53ZlEWNK2Mk8BAI8FsfC37pqsRkzlc=";
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

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];

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
