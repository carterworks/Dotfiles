{ pkgs, lib }:

let
  version = "0.1.0-1541";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "rex-client";
  inherit version;

  src = pkgs.requireFile {
    name = "Rex-${version}.dmg";
    hash = "sha256-suZYPZxvEZVHg9QDAjWxAIv+VrXU2sf9AwcM2SIHw/M=";
    message = "Configure private Rex sources outside the repository, then run ./update --fetch rex-client. See docs/rex.md.";
  };

  nativeBuildInputs = [
    pkgs.undmg
    pkgs.makeWrapper
  ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  # Preserve the signed bundle, including the embedded server and frameworks.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin"
    cp -R "Rex Beta.app" "$out/Applications/"
    makeWrapper /usr/bin/open "$out/bin/rex-client" \
      --add-flags "-a \"$out/Applications/Rex Beta.app\" --args"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x "$out/Applications/Rex Beta.app/Contents/MacOS/Rex"
    test -x "$out/bin/rex-client"
    /usr/bin/codesign --verify --deep --strict "$out/Applications/Rex Beta.app"
    runHook postInstallCheck
  '';

  passthru.updateInfo = {
    source = "sparkle";
    strategy = "require-file";
    privateUrlKey = "rex.clientFeedUrl";
    privateUrlTemplateKey = "rex.clientUrlTemplate";
    fileName = "Rex-{version}.dmg";
  };

  meta = {
    description = "Rex terminal multiplexer for macOS";
    homepage = "https://www.superlogical.com/rex";
    license = lib.licenses.unfree;
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "rex-client";
  };
}
