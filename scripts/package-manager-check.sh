#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
release_context="$(bash "$ROOT_DIR/scripts/release-context.sh")"
eval "$release_context"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build-release}"
RENDERED_DIR="$ROOT_DIR/.stage/package-managers/rendered"
APT_PUBLIC_DIR="$ROOT_DIR/.stage/apt-public"

ICEY_SOURCE_DIR="$ICEY_SOURCE_DIR" BUILD_DIR="$BUILD_DIR" bash "$ROOT_DIR/scripts/build-source-archives.sh"
ICEY_SOURCE_DIR="$ICEY_SOURCE_DIR" BUILD_DIR="$BUILD_DIR" bash "$ROOT_DIR/scripts/package-release.sh"
ICEY_SOURCE_DIR="$ICEY_SOURCE_DIR" BUILD_DIR="$BUILD_DIR" bash "$ROOT_DIR/scripts/build-deb.sh"
ICEY_SOURCE_DIR="$ICEY_SOURCE_DIR" BUILD_DIR="$BUILD_DIR" bash "$ROOT_DIR/scripts/build-apt-repo.sh"

OUT_DIR="$RENDERED_DIR" \
ICEY_SOURCE_DIR="$ICEY_SOURCE_DIR" \
  bash "$ROOT_DIR/scripts/render-package-managers.sh"

tar -tzf "$LINUX_TARBALL" >/dev/null
unzip -Z1 "$LINUX_ZIP" >/dev/null
tar -tzf "$LATEST_LINUX_TARBALL" >/dev/null
unzip -Z1 "$LATEST_LINUX_ZIP" >/dev/null
dpkg-deb --contents "$DEB_PATH" >/dev/null
tar -tzf "$APT_REPO_ARCHIVE" >/dev/null

test -f "$RENDERED_DIR/homebrew/icey-server.rb"
test -f "$RENDERED_DIR/aur/PKGBUILD"
test -f "$RENDERED_DIR/apt/icey-server.list"
test -f "$RENDERED_DIR/nix/default.nix"
test -f "$RENDERED_DIR/SHA256SUMS.txt"
test -f "$ROOT_DIR/flake.nix"

if [[ -f "$WINDOWS_ZIP" ]]; then
  test -f "$RENDERED_DIR/scoop/icey-server.json"
  test -f "$RENDERED_DIR/chocolatey/icey-server.nuspec"
  test -f "$RENDERED_DIR/winget/0state.IceyServer.installer.yaml"
fi

if rg -n "REPLACE_WITH_" "$RENDERED_DIR" >/dev/null; then
  echo "Rendered package manager outputs still contain placeholder values" >&2
  exit 1
fi

if [[ -n "${APT_GPG_KEY_ID:-}" ]]; then
  test -f "$ROOT_DIR/.stage/apt-repo/dists/stable/InRelease"
  test -f "$ROOT_DIR/.stage/apt-repo/dists/stable/Release.gpg"
  test -f "$APT_PUBLIC_DIR/icey-archive-keyring.asc"
  test -f "$APT_PUBLIC_DIR/icey-archive-keyring.gpg"
fi

echo "Package manager cutover artifacts validated."
