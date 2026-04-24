#!/usr/bin/env bash
set -euo pipefail

REPO="dmtrKovalenko/fff.nvim"
NIX_FILE="$(cd "$(dirname "$0")" && pwd)/fff-mcp.nix"

latest=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name' | sed 's/^v//')
current=$(grep -E 'version = "[^"]+"' "$NIX_FILE" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

if [ "$latest" = "$current" ]; then
  echo "fff-mcp already at $current"
  exit 0
fi

echo "fff-mcp: $current -> $latest"

fetch_sri() {
  local target=$1
  local url="https://github.com/$REPO/releases/download/v${latest}/fff-mcp-${target}.sha256"
  local hex
  hex=$(curl -fsSL "$url" | awk '{print $1}')
  nix hash convert --hash-algo sha256 --to sri "$hex"
}

darwin_hash=$(fetch_sri aarch64-apple-darwin)
linux_hash=$(fetch_sri x86_64-unknown-linux-gnu)

sed -i.bak -E "s|version = \"[^\"]+\"|version = \"${latest}\"|" "$NIX_FILE"
sed -i.bak -E "/aarch64-darwin/,/};/ s|hash = \"sha256-[^\"]+\"|hash = \"${darwin_hash}\"|" "$NIX_FILE"
sed -i.bak -E "/x86_64-linux/,/};/ s|hash = \"sha256-[^\"]+\"|hash = \"${linux_hash}\"|" "$NIX_FILE"
rm -f "$NIX_FILE.bak"

echo "Updated $NIX_FILE"
