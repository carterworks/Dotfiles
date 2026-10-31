{
  pkgs,
  lib,
}:

let
  version = "0.38.0";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "cua-driver";
  inherit version;

  # Upstream ships the driver as a glibc-linked Rust binary with no source
  # packaging; autoPatchelf rewrites it for the NixOS loader.
  src = pkgs.fetchurl {
    url = "https://github.com/trycua/cua/releases/download/cua-driver-rs-v${version}/cua-driver-rs-${version}-linux-x86_64-binary.tar.gz";
    hash = "sha256-MauXCd2RznNnfkm58+dcbw0+TZYlwobJ5YJiv76mmN0=";
  };

  nativeBuildInputs = [
    pkgs.autoPatchelfHook
    pkgs.makeWrapper
  ];
  buildInputs = [
    # dlopen'd for the agent cursor overlay and accessibility bridges.
    pkgs.gtk3
    pkgs.gtk4
    pkgs.libX11
    pkgs.libXi
    pkgs.libxkbcommon
    pkgs.stdenv.cc.cc.lib
  ];

  sourceRoot = ".";

  # Keep the sibling payload next to the executable: the driver resolves the
  # cursor theme and cursor renderer relative to its own directory.
  installPhase = ''
    runHook preInstall

    install -d $out/libexec/cua-driver
    cp -a ./. $out/libexec/cua-driver/
    mkdir -p $out/bin
    ln -s $out/libexec/cua-driver/cua-driver $out/bin/cua-driver
    ln -s $out/libexec/cua-driver/cua-cursor-theme $out/bin/cua-cursor-theme

    runHook postInstall
  '';

  # The binary shells out to these for screenshots, synthetic input, and
  # trajectory recording; it also offers to download ffmpeg on first use.
  postFixup = ''
    wrapProgram $out/libexec/cua-driver/cua-driver \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.ffmpeg
          pkgs.grim
          pkgs.wtype
        ]
      }
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/cua-driver --version
    runHook postInstallCheck
  '';

  meta = {
    description = "Background desktop driver that lets an AI agent operate native apps";
    homepage = "https://cua.ai/docs/cua-driver";
    license = lib.licenses.mit;
    mainProgram = "cua-driver";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
