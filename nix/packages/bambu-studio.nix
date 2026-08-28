{
  pkgs,
  lib,
}:

let
  version = "02.08.02.61";
  assetName = "BambuStudio_ubuntu24.04-v02.08.02.61-20260820225108.AppImage";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  # The Ubuntu AppImage has better compatibility than the Fedora build on NixOS.
  appimageSource = packageUtils.fetchGitHubRelease {
    owner = "bambulab";
    repo = "BambuStudio";
    asset = assetName;
    inherit version;
    hash = "sha256-1QGxA/rFQkUT7A6Na8FF+zBxneLH2U1zINcjdAyBp/0=";
  };

  bambu-studio = pkgs.appimageTools.wrapType2 rec {
    pname = "bambu-studio";
    inherit version;

    src = appimageSource;

    passthru.updateInfo = {
      source = "github-release";
      owner = "bambulab";
      repo = "BambuStudio";
      tagPrefix = "v";
      assetPattern = "^BambuStudio_ubuntu-?24\\.04.*\\.AppImage$";
    };

    profile = ''
      export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      export GIO_MODULE_DIR="${pkgs.glib-networking}/lib/gio/modules/"
      export WEBKIT_DISABLE_DMABUF_RENDERER=1
    '';

    extraPkgs =
      pkgs: with pkgs; [
        cacert
        curl
        glib
        glib-networking
        gst_all_1.gst-plugins-bad
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-good
        webkitgtk_4_1
      ];

    extraInstallCommands =
      let
        contents = pkgs.appimageTools.extract {
          inherit pname version;
          src = appimageSource;
        };
      in
      ''
        install -Dm644 ${contents}/BambuStudio.desktop $out/share/applications/BambuStudio.desktop
        substituteInPlace $out/share/applications/BambuStudio.desktop \
          --replace-fail 'Exec=AppRun' 'Exec=bambu-studio' \
          --replace-fail 'Icon=BambuStudio' 'Icon=bambu-studio'

        mkdir -p $out/share/pixmaps
        cp ${contents}/resources/images/BambuStudioLogo.png $out/share/pixmaps/bambu-studio.png 2>/dev/null || \
        cp ${contents}/.DirIcon $out/share/pixmaps/bambu-studio.png 2>/dev/null || true
      '';

    meta = {
      description = "PC Software for BambuLab's 3D printers (AppImage wrapper)";
      homepage = "https://github.com/bambulab/BambuStudio";
      license = lib.licenses.agpl3Plus;
      platforms = [ "x86_64-linux" ];
      mainProgram = "bambu-studio";
    };
  };
in
bambu-studio
