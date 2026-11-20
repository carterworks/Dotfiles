{
  pkgs,
  lib,
  kladSource,
}:

let
  pname = "klad";
  version = "0.4.0";
  inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux system;

  # skia-bindings' build script downloads a prebuilt Skia, which the sandbox
  # cannot, so fetch the one it picks for skia-safe's default features. The key
  # changes with each skia-bindings release; the assert below catches a klad
  # release that moves to a new one.
  skia = {
    version = "0.157.0";
    key = "30669978c3f39a73e8a7";
    hashes = {
      aarch64-darwin = "sha256-bmWZUfp7KbocpM2I9/QxEqSDjv00IHFzJJhQBLmAoik=";
      x86_64-linux = "sha256-T+k7LrvXRinJAUwyIQu7B3PmFADyDZHqCrpw+Y8ZaZ0=";
    };
  };
  lockedSkia =
    (lib.findFirst (
      crate: crate.name == "skia-bindings"
    ) (throw "klad no longer uses skia-bindings") (lib.importTOML "${kladSource}/Cargo.lock").package)
    .version;
  skiaBinaries = pkgs.fetchurl {
    url = "https://github.com/rust-skia/skia-binaries/releases/download/${skia.version}/skia-binaries-${skia.key}-${pkgs.stdenv.hostPlatform.rust.rustcTarget}-jpegd-jpege-pdf.tar.gz";
    hash = skia.hashes.${system} or (throw "Unsupported system for klad: ${system}");
  };

  # winit and wgpu dlopen these instead of linking them.
  runtimeLibraries = with pkgs; [
    libGL
    libxkbcommon
    vulkan-loader
    wayland
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
  ];
in
assert lib.assertMsg (
  lockedSkia == skia.version
) "klad ${version} locks skia-bindings ${lockedSkia}; update `skia` in nix/packages/klad.nix";
pkgs.rustPlatform.buildRustPackage {
  inherit pname version;
  src = kladSource;
  cargoLock.lockFile = "${kladSource}/Cargo.lock";

  cargoBuildFlags = [
    "-p"
    "klad-cli"
  ];
  # The editor's tests render through wgpu, which needs a GPU the build sandbox
  # does not have.
  doCheck = false;

  env = {
    SKIA_BINARIES_URL = "file://${skiaBinaries}";
    # Otherwise the build script asks git, and the source has no .git.
    KLAD_BUILD = "v${version}";
  };

  nativeBuildInputs = [
    pkgs.pkg-config
    pkgs.python3
  ]
  ++ lib.optional isDarwin pkgs.makeBinaryWrapper;
  buildInputs = [
    pkgs.zstd
  ]
  ++ lib.optionals isLinux [
    pkgs.fontconfig
    pkgs.freetype
  ];

  # klad finds its fonts and samples in ../share/klad next to its binary.
  postInstall = ''
    mkdir -p $out/share/klad
    cp -R fonts $out/share/klad/fonts
    rm $out/share/klad/fonts/update.py
    bash packaging/samples.sh $out/bin/klad $out/share/klad/samples
  ''
  + lib.optionalString isLinux ''
    install -Dm644 packaging/linux/klad.desktop $out/share/applications/klad.desktop
    install -Dm644 packaging/icon/icon.png $out/share/icons/hicolor/512x512/apps/klad.png
  '';

  postFixup =
    lib.optionalString isLinux ''
      patchelf --add-rpath ${lib.makeLibraryPath runtimeLibraries} $out/bin/klad $out/bin/klad-editor
    ''
    # macOS reports the executable by the symlink it was started through, and
    # klad resolves that link for its fonts but not its samples, so through
    # /run/current-system/sw/bin it would find none.
    + lib.optionalString isDarwin ''
      for exe in klad klad-editor; do
        wrapProgram $out/bin/$exe --set-default KLAD_SAMPLES $out/share/klad/samples
      done
    '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$TMPDIR
    $out/bin/klad --version
    grep -qi barlow <<<"$($out/bin/klad fonts)"
    grep -q lantern <<<"$($out/bin/klad samples)"
    runHook postInstallCheck
  '';

  passthru.updateInfo = {
    source = "github-release";
    owner = "klad-app";
    repo = "klad";
    tagPrefix = "v";
    flakeInput = "klad";
    build = "source";
  };

  meta = {
    description = "Painting and animation app shared with a coding agent";
    homepage = "https://klad.studio";
    license = {
      fullName = "PolyForm Internal Use License 1.0.0, with klad's additional permissions";
      url = "https://github.com/klad-app/klad/blob/main/LICENSE";
      free = false;
      redistributable = false;
    };
    mainProgram = "klad";
    platforms = builtins.attrNames skia.hashes;
  };
}
