{
  lib,
  rustPlatform,
  src,
}:

rustPlatform.buildRustPackage {
  pname = "rtk";
  version = (lib.importTOML "${src}/Cargo.toml").package.version;
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  doCheck = false;

  meta = {
    description = "Rust Token Killer - CLI proxy to minimize LLM token consumption";
    homepage = "https://github.com/rtk-ai/rtk";
    license = lib.licenses.mit;
    mainProgram = "rtk";
  };
}
