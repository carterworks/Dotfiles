{
  pkgs,
  lib,
}:

let
  pnpm = pkgs.pnpm_10;
in
pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "sdcpp-webui";
  version = "0-unstable-2026-08-24";

  src = pkgs.fetchFromGitHub {
    owner = "leejet";
    repo = "sdcpp-webui";
    rev = "c4bce3d6b3f236614cca21014f076083b7270ba8";
    hash = "sha256-vBb6uXZGRKu8CcECZeMXvPBuLeJ7dtCNll3Yvhq4hBY=";
  };

  passthru.updateInfo = {
    source = "github-branch";
    owner = "leejet";
    repo = "sdcpp-webui";
    branch = "master";
    strategy = "pnpm-git";
  };

  pnpmDeps = pkgs.fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 3;
    hash = "sha256-ocImnMPFHhnuJj3gUN8WsfSur/peLIKiozpPDHU1tAA=";
  };

  nativeBuildInputs = [
    pkgs.nodejs
    pnpm
    pkgs.pnpmConfigHook
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 dist/index.html "$out/index.html"
    runHook postInstall
  '';

  meta = {
    description = "Official web interface for stable-diffusion.cpp";
    homepage = "https://github.com/leejet/sdcpp-webui";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
