{
  lib,
  pkgs,
}:

let
  selectPlatformPackage =
    pname: platformPackages:
    platformPackages.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for ${pname}: ${pkgs.stdenv.hostPlatform.system}");
in
{
  inherit selectPlatformPackage;

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

  # A prebuilt per-platform binary. Any other attribute is passed through to
  # mkDerivation.
  mkPlatformBinary =
    {
      pname,
      platformPackages,
      src,
      meta,
      updateInfo,
      ...
    }@args:
    pkgs.stdenvNoCC.mkDerivation (
      removeAttrs args [
        "platformPackages"
        "updateInfo"
      ]
      // {
        src = src (selectPlatformPackage pname platformPackages);

        passthru = (args.passthru or { }) // {
          inherit updateInfo;
        };

        meta = meta // {
          platforms = builtins.attrNames platformPackages;
          sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
        };
      }
    );
}
