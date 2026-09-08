{
  pkgs,
  lib,
}:

let
  pname = "nub";
  version = "0.9.0";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  platformPackages = {
    aarch64-darwin = {
      packageName = "nub-darwin-arm64";
      hash = "sha256-VurO7jA5cclvN4zOVdq79lrRYF4D9/aU5Bc5YpwCxfY=";
    };
    x86_64-linux = {
      packageName = "nub-linux-x64";
      hash = "sha256-U6ltfZmI2YQvRNERAbxuS/u/STcx9kLlgwljlO49WLQ=";
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
