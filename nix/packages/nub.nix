{
  pkgs,
  lib,
}:

let
  version = "0.6.0";

  platformPackages = {
    aarch64-darwin = {
      packageName = "nub-darwin-arm64";
      hash = "sha256-9JWxc0FOLfYIxmoZUG++y52LnLV6djLGv2y4Ar4eg3k=";
    };
    x86_64-linux = {
      packageName = "nub-linux-x64";
      hash = "sha256-hKIH/lXf9dHD8XgMvhusYkpTLt8FO8F9YYgdT1BppQY=";
    };
  };

  platformPackage =
    platformPackages.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for nub: ${pkgs.stdenv.hostPlatform.system}");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "nub";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@nubjs/${platformPackage.packageName}/-/${platformPackage.packageName}-${version}.tgz";
    inherit (platformPackage) hash;
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/nub $out/bin
    cp -R . $out/lib/nub
    chmod 755 $out/lib/nub/bin/nub $out/lib/nub/bin/nubx
    ln -s $out/lib/nub/bin/nub $out/bin/nub
    ln -s $out/lib/nub/bin/nubx $out/bin/nubx

    runHook postInstall
  '';

  meta = {
    description = "Fast TypeScript-first runtime and pnpm-compatible package manager for Node";
    homepage = "https://nubjs.com";
    license = lib.licenses.mit;
    mainProgram = "nub";
    platforms = builtins.attrNames platformPackages;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
