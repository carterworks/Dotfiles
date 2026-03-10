{ pkgs, lib, ... }:

let
  version = "02.04.00.70";

  # Fetch the Ubuntu AppImage (better compatibility than Fedora on NixOS)
  appimageSource = pkgs.fetchurl {
    url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/Bambu_Studio_ubuntu-24.04_PR-8834.AppImage";
    hash = "sha256-JrwH3MsE3y5GKx4Do3ZlCSAcRuJzEqFYRPb11/3x3r0=";
  };

  # Build the AppImage wrapper
  bambu-studio-appimage = pkgs.appimageTools.wrapType2 rec {
    pname = "bambu-studio";
    inherit version;

    src = appimageSource;

    # Set environment variables for SSL, GIO, and webkit rendering
    profile = ''
      export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      export GIO_MODULE_DIR="${pkgs.glib-networking}/lib/gio/modules/"
      export WEBKIT_DISABLE_DMABUF_RENDERER=1
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export MESA_LOADER_DRIVER_OVERRIDE=nvidia
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
        webkitgtk_4_1 # Provides libwebkit2gtk-4.1.so.0
      ];

    extraInstallCommands =
      let
        contents = pkgs.appimageTools.extractType2 {
          inherit pname version;
          src = appimageSource;
        };
      in
      ''
        # Install desktop file
        install -Dm644 ${contents}/BambuStudio.desktop $out/share/applications/BambuStudio.desktop
        substituteInPlace $out/share/applications/BambuStudio.desktop \
          --replace-fail 'Exec=AppRun' 'Exec=bambu-studio' \
          --replace-fail 'Icon=BambuStudio' 'Icon=bambu-studio'

        # Install icon
        mkdir -p $out/share/pixmaps
        cp ${contents}/resources/images/BambuStudioLogo.png $out/share/pixmaps/bambu-studio.png 2>/dev/null || \
        cp ${contents}/.DirIcon $out/share/pixmaps/bambu-studio.png 2>/dev/null || true
      '';

    meta = {
      description = "PC Software for BambuLab's 3D printers (AppImage wrapper)";
      homepage = "https://github.com/bambulab/BambuStudio";
      license = lib.licenses.agpl3Plus;
      platforms = lib.platforms.linux;
      mainProgram = "bambu-studio";
    };
  };
in
bambu-studio-appimage
