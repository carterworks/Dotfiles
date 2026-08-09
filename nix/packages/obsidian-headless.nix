{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
  gnutar,
  gzip,
}:

let
  version = "0.0.14";
  sourceArchive = fetchurl {
    url = "https://registry.npmjs.org/obsidian-headless/-/obsidian-headless-${version}.tgz";
    hash = "sha256-73UpjtOjVtyypN6Yxu/hCyrGSwBVYAcRi2rHBTXnMVY=";
  };
  source = runCommand "obsidian-headless-source-${version}" { } ''
    mkdir -p "$out"
    ${gnutar}/bin/tar -xzf ${sourceArchive} --strip-components=1 -C "$out"
    cp ${./obsidian-headless/package.json} "$out/package.json"
    cp ${./obsidian-headless/package-lock.json} "$out/package-lock.json"
  '';
in
buildNpmPackage {
  pname = "obsidian-headless";
  inherit version;
  src = source;

  npmDepsHash = "sha256-AI9Jlr0Zy3rEoBsa6k8xGhK4u/XutLaEm5BKeubl3PI=";
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/node_modules/obsidian-headless" "$out/bin"
    cp -r . "$out/lib/node_modules/obsidian-headless/"
    ln -s "$out/lib/node_modules/obsidian-headless/cli.js" "$out/bin/ob"
    runHook postInstall
  '';

  meta = {
    description = "Headless client for Obsidian Sync and Publish";
    homepage = "https://obsidian.md/help/headless";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "ob";
    platforms = lib.platforms.linux;
  };
}
