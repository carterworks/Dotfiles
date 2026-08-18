{
  pkgs,
  lib,
}:

let
  version = "0.7.5";

  platformPackages = {
    aarch64-darwin = {
      packageName = "nub-darwin-arm64";
      hash = "sha256-u41jnjbsiMhwWxHWvdKxiONEA2HBw+sal7RethV5DUE=";
    };
    x86_64-linux = {
      packageName = "nub-linux-x64";
      hash = "sha256-5QeyWvWg/yeZW4kLAgF8ywLLH0jlY06KQp+hLFB8pyc=";
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
    chmod 755 $out/lib/nub/bin/nub
    ln -s $out/lib/nub/bin/nub $out/bin/nub
    # 0.7.0+ ships one multi-call binary; the nub/nubx verb is chosen by argv[0].
    ln -s $out/lib/nub/bin/nub $out/bin/nubx

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
