{
  pkgs,
  lib,
}:

let
  pname = "t3code-nightly";
  version = "0.1.1-nightly.20261020.3411";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  appName = "T3 Code (Nightly)";

  # Upstream ships fully self-contained desktop builds (bundled Electron, server
  # and web client), so this fetches the release artifact and wraps it; nothing
  # is compiled. The nightly SHA256SUMS only covers the `t3-*` CLI tarballs
  # (`install.sh` verifies those), so these hashes come from the assets.
  platformPackages = {
    aarch64-darwin = {
      asset = "T3-Code-${version}-arm64.zip";
      hash = "sha256-/zr+dXtbffznNcN/PGFzekNEqhH88XH22GueIlSzLLk=";
    };
    x86_64-linux = {
      asset = "T3-Code-${version}-x86_64.AppImage";
      hash = "sha256-Xbj0TU7u/EGJIJf5PSWMfgMcJAcl0krZjKTt0LPthxA=";
    };
  };

  platformPackage =
    platformPackages.${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for ${pname}: ${pkgs.stdenv.hostPlatform.system}");

  src = packageUtils.fetchGitHubRelease {
    owner = "pingdotgg";
    repo = "t3code";
    inherit version;
    inherit (platformPackage) asset hash;
  };

  # t3code discovers provider CLIs (codex, opencode, ...) by reading the user's
  # login shell environment, so system-wide providers stay visible to a Finder
  # launch without baking a PATH into the app.
  meta = {
    description = "Nightly desktop control surface for local coding agents";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "t3code-desktop";
    platforms = builtins.attrNames platformPackages;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };

  updateInfo = {
    source = "github-release-channel";
    owner = "pingdotgg";
    repo = "t3code";
    channel = "nightly";
    tagPrefix = "v";
  };
in
if pkgs.stdenv.hostPlatform.isDarwin then
  pkgs.stdenvNoCC.mkDerivation {
    inherit
      pname
      version
      src
      meta
      ;

    nativeBuildInputs = [
      pkgs.unzip
      pkgs.makeWrapper
    ];

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    # Keep the notarised bundle byte-identical so its signature stays valid.
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications" "$out/bin"
      unzip -q "$src" -d "$out/Applications"
      makeWrapper "$out/Applications/${appName}.app/Contents/MacOS/${appName}" \
        "$out/bin/t3code-desktop"

      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      test -x "$out/Applications/${appName}.app/Contents/MacOS/${appName}"
      test -x "$out/bin/t3code-desktop"
      /usr/bin/codesign --verify --deep --strict "$out/Applications/${appName}.app"

      runHook postInstallCheck
    '';

    passthru = { inherit updateInfo; };
  }
else
  let
    # The desktop entry only exists on Linux; keep the extraction next to its
    # only consumer so Darwin evaluation never touches appimageTools.
    contents = pkgs.appimageTools.extract { inherit pname version src; };
  in
  pkgs.appimageTools.wrapType2 {
    inherit
      pname
      version
      src
      meta
      ;

    executableName = "t3code-desktop";

    # The AppImage's own Exec line points at an unwrapped path, and upstream
    # registers its icon under the generic `t3code` name.
    extraInstallCommands = ''
      for icon in ${contents}/usr/share/icons/hicolor/*/apps/t3code.png; do
        [ -e "$icon" ] || continue
        size="$(basename "$(dirname "$(dirname "$icon")")")"
        install -Dm644 "$icon" "$out/share/icons/hicolor/$size/apps/t3code-nightly.png"
      done

      mkdir -p "$out/share/applications"
      {
        echo '[Desktop Entry]'
        echo 'Name=T3 Code (Nightly)'
        echo 'Comment=Nightly desktop control surface for local coding agents'
        echo 'Exec=t3code-desktop %U'
        echo 'TryExec=t3code-desktop'
        echo 'Terminal=false'
        echo 'Type=Application'
        echo 'Icon=t3code-nightly'
        echo 'StartupWMClass=t3code'
        echo 'Categories=Development;'
        echo 'MimeType=x-scheme-handler/t3code;'
      } > "$out/share/applications/t3code-nightly.desktop"
    '';

    passthru = { inherit updateInfo; };
  }
