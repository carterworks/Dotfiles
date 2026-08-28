{
  lib,
  pkgs,
}:

{
  fetchGitHubRelease =
    {
      owner,
      repo,
      version,
      asset,
      hash,
      tag ? "v${version}",
    }:
    pkgs.fetchurl {
      url = "https://github.com/${owner}/${repo}/releases/download/${tag}/${asset}";
      inherit hash;
    };

  fetchNpmTarball =
    {
      name,
      version,
      hash,
    }:
    let
      basename = lib.last (lib.splitString "/" name);
    in
    pkgs.fetchurl {
      url = "https://registry.npmjs.org/${name}/-/${basename}-${version}.tgz";
      inherit hash;
    };

  mkPlatformBinary =
    {
      pname,
      version,
      platformPackages,
      src,
      installPhase,
      meta,
      updateInfo,
      dontUnpack ? false,
      nativeBuildInputs ? [ ],
    }:
    let
      platformPackage =
        platformPackages.${pkgs.stdenv.hostPlatform.system}
          or (throw "Unsupported system for ${pname}: ${pkgs.stdenv.hostPlatform.system}");
    in
    pkgs.stdenvNoCC.mkDerivation {
      inherit
        dontUnpack
        installPhase
        nativeBuildInputs
        pname
        version
        ;

      src = src platformPackage;

      passthru.updateInfo = updateInfo;

      meta = meta // {
        platforms = builtins.attrNames platformPackages;
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
    };
}
