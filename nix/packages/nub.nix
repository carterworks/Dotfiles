{
  pkgs,
  lib,
}:

let
  pname = "nub";
  version = "0.9.4";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  platformPackages = {
    aarch64-darwin = {
      packageName = "nub-darwin-arm64";
      hash = "sha256-O0lzaIfoV10D1PH7TpRR79DnKCUhObxe8gzYJxypKkA=";
    };
    x86_64-linux = {
      packageName = "nub-linux-x64";
      hash = "sha256-Vx+nIS3P7nRSIFx2nH703aU7N09salqTTvpukJXpK+E=";
    };
  };

in
packageUtils.mkPlatformBinary {
  inherit pname version platformPackages;

  src =
    platformPackage:
    packageUtils.fetchNpmTarball {
      name = "@nubjs/${platformPackage.packageName}";
      inherit version;
      inherit (platformPackage) hash;
    };

  updateInfo = {
    source = "npm";
    package = "@nubjs/nub-darwin-arm64";
    channel = "latest";
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
  };
}
