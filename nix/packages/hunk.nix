{ pkgs, lib }:

let
  version = "0.10.0";

  platformPackages = {
    aarch64-darwin = {
      name = "hunkdiff-darwin-arm64";
      hash = "sha512-oJALanUcIFp19LQbTTNKEk/RA0QIeeqwXzUciTzBlze1IA5GPe+rq+OLy66fFUA5tiO6qj6sXf1UqK9cL8o0Mw==";
    };
    x86_64-darwin = {
      name = "hunkdiff-darwin-x64";
      hash = "sha512-5sVwIN7OQ4x6/K1TfP4n0wUZinL9nPKmbZ/oHJWhMD6FScGuOOYYZQtN+q2j3ahzlu36Iio7OXajuyQZulwU4A==";
    };
    aarch64-linux = {
      name = "hunkdiff-linux-arm64";
      hash = "sha512-h3yY1cxEmer3StCppvQ4kZyK10971t6dMO76jMnWNhREWML2H2hCiPrNw5Yjx0tI0AyI1P4D3guNCcvylLmO4A==";
    };
    x86_64-linux = {
      name = "hunkdiff-linux-x64";
      hash = "sha512-me3Pl6Tqb46yoZP930iCUdE3pE5lDOtfsWUcCZXqEpsg0WPbW6PjO6tjX7MRnkLFPacPDrqfPZpEHr2bxK0X9A==";
    };
  };

  platformPackage =
    platformPackages.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for hunk: ${pkgs.stdenv.hostPlatform.system}");

  hunkdiffSrc = pkgs.fetchurl {
    url = "https://registry.npmjs.org/hunkdiff/-/hunkdiff-${version}.tgz";
    hash = "sha512-GfUYNCzEnZ0OTdg340YRFbW1SvvwgRMyQmn44t2GKoSjYqiXGaDCeOG66fpIzU8WRdbUi2uzdGIVkEsCps8TeA==";
  };

  prebuiltSrc = pkgs.fetchurl {
    url = "https://registry.npmjs.org/${platformPackage.name}/-/${platformPackage.name}-${version}.tgz";
    inherit (platformPackage) hash;
  };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "hunk";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/node_modules" "$out/bin" wrapper prebuilt

    tar -xzf ${hunkdiffSrc} -C wrapper
    cp -R wrapper/package "$out/lib/node_modules/hunkdiff"

    tar -xzf ${prebuiltSrc} -C prebuilt
    mkdir -p "$out/lib/node_modules/hunkdiff/node_modules/${platformPackage.name}"
    cp -R prebuilt/package/. "$out/lib/node_modules/hunkdiff/node_modules/${platformPackage.name}"
    chmod +x "$out/lib/node_modules/hunkdiff/node_modules/${platformPackage.name}/bin/hunk"

    makeWrapper ${lib.getExe pkgs.nodejs} "$out/bin/hunk" \
      --add-flags "$out/lib/node_modules/hunkdiff/bin/hunk.cjs"

    runHook postInstall
  '';

  meta = {
    description = "Review-first terminal diff viewer for agent-authored changesets";
    homepage = "https://github.com/modem-dev/hunk";
    license = lib.licenses.mit;
    mainProgram = "hunk";
    platforms = builtins.attrNames platformPackages;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
