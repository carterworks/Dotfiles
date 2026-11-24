{
  pkgs,
  lib,
}:

let
  pname = "modern-web-guidance";
  version = "1.0.2";
  packageUtils = import ../lib/package-utils.nix { inherit lib pkgs; };

  # The tarball is the whole product: the CLI, the guides, and the offline
  # search index it reads from beside its own script.
  skillDirectory = "lib/modern-web-guidance/skills/modern-web-guidance";
in
pkgs.stdenv.mkDerivation {
  inherit pname version;

  src = packageUtils.fetchNpmTarball {
    name = pname;
    inherit version;
    hash = "sha256-jDRt8XjJYoSmUWkg4YL3B4nUZB8PuKyyITZCWVNsUA0=";
  };

  passthru = {
    skill = "share/agent-skills/modern-web-guidance";
    updateInfo = {
      source = "npm";
      package = pname;
      channel = "latest";
    };
  };

  nativeBuildInputs = [
    pkgs.gawk
    pkgs.gnused
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/modern-web-guidance $out/bin $out/share/agent-skills/modern-web-guidance
    cp -R . $out/lib/modern-web-guidance

    # Upstream reports which guides are searched to Google unless this is set;
    # a search query names what the user is building. Its install, update and
    # uninstall commands run `npx skills`, which would replace this package.
    cat > $out/bin/modern-web-guidance <<EOF
    #!${pkgs.runtimeShell}
    case "\''${1-}" in
      install | update | uninstall)
        echo "modern-web-guidance: Nix manages this installation; \$1 is disabled" >&2
        exit 2
        ;;
    esac
    export DISABLE_TELEMETRY=1
    exec ${lib.getExe pkgs.nodejs_24} $out/${skillDirectory}/modern-web.mjs "\$@"
    EOF
    chmod +x $out/bin/modern-web-guidance

    # Upstream's skill runs `npx -y modern-web-guidance@latest`, which would
    # bypass this pinned CLI and reach the network. Without --skill-version the
    # CLI never tells the agent to upgrade. The grep fails the build when
    # upstream rewords the skill so the rewrite misses.
    sed -E \
      -e 's/npx -y modern-web-guidance@latest/modern-web-guidance/g' \
      -e 's/ --skill-version [^ ]+//g' \
      -e 's/`modern-web-guidance` directly with `npx` using a/`modern-web-guidance` with a/' \
      $out/${skillDirectory}/SKILL.md \
      | awk '
        /^## Using npx \/ pnpx$/ {
          print "## Installed CLI"
          print ""
          print "`modern-web-guidance` is on `PATH` and runs offline; do not fetch it with `npx` or `pnpx`."
          print ""
          skip = 1
          next
        }
        /^## Guidelines$/ { skip = 0 }
        !skip
      ' > $out/share/agent-skills/modern-web-guidance/SKILL.md
    if grep -Eq 'npx -y|pnpx modern|--skill-version|^## Using npx' $out/share/agent-skills/modern-web-guidance/SKILL.md; then
      echo "modern-web-guidance's SKILL.md no longer matches the rewrite" >&2
      exit 1
    fi

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test -x $out/bin/modern-web-guidance
    $out/bin/modern-web-guidance --version
    ! $out/bin/modern-web-guidance install 2>/dev/null
    HOME=$TMPDIR $out/bin/modern-web-guidance search "light dismiss dialog" | grep -q .

    runHook postInstallCheck
  '';

  meta = {
    description = "Modern web platform guidance for coding agents";
    homepage = "https://developer.chrome.com/docs/modern-web-guidance";
    license = lib.licenses.asl20;
    mainProgram = "modern-web-guidance";
  };
}
