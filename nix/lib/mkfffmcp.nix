{ pkgs, lib, src }:

pkgs.rustPlatform.buildRustPackage {
  pname = "fff-mcp";
  version = (lib.importTOML "${src}/crates/fff-mcp/Cargo.toml").package.version;
  inherit src;

  cargoRoot = "crates/fff-mcp";
  cargoLock.lockFile = "${src}/Cargo.lock";
  cargoBuildFlags = [ "--bin" "fff-mcp" ];
  postPatch = ''
    ln -s ../../Cargo.lock crates/fff-mcp/Cargo.lock
  '';

  nativeBuildInputs = [
    pkgs.pkg-config
    pkgs.perl
    pkgs.llvmPackages.libclang.lib
  ];

  buildInputs = [ pkgs.openssl ];
  LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

  preBuild = ''
    export PATH="${pkgs.zig_0_16}/bin:$PATH"
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    mkdir -p "$ZIG_GLOBAL_CACHE_DIR" "$ZIG_LOCAL_CACHE_DIR" "$XDG_CACHE_HOME"
  '';

  doCheck = false;

  meta = {
    description = "FFF MCP server - typo-resistant file search for AI agents";
    homepage = "https://github.com/dmtrKovalenko/fff.nvim";
    license = lib.licenses.mit;
    mainProgram = "fff-mcp";
  };
}
