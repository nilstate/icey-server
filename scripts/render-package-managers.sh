#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eval "$(bash "$ROOT_DIR/scripts/release-context.sh")"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/.stage/package-managers/rendered}"
TEMPLATES_DIR="$ROOT_DIR/packaging/templates"
eval "$(bash "$ROOT_DIR/scripts/release-manifest.sh")"

escape_sed() {
  printf '%s' "$1" | sed -e 's/[\\/&|]/\\&/g'
}

render_template() {
  local src="$1"
  local dst="$2"

  mkdir -p "$(dirname "$dst")"

  sed \
    -e "s|@SERVER_VERSION@|$(escape_sed "$SERVER_VERSION")|g" \
    -e "s|@ICEY_VERSION@|$(escape_sed "$ICEY_VERSION")|g" \
    -e "s|@ICEY_SERVER_SOURCE_URL@|$(escape_sed "$TEMPLATE_SERVER_SOURCE_URL")|g" \
    -e "s|@ICEY_SERVER_SOURCE_SHA256@|$(escape_sed "$TEMPLATE_SERVER_SOURCE_SHA256")|g" \
    -e "s|@ICEY_SERVER_SOURCE_SRI@|$(escape_sed "$TEMPLATE_SERVER_SOURCE_SRI")|g" \
    -e "s|@ICEY_SOURCE_URL@|$(escape_sed "$TEMPLATE_ICEY_SOURCE_URL")|g" \
    -e "s|@ICEY_SOURCE_SHA256@|$(escape_sed "$TEMPLATE_ICEY_SOURCE_SHA256")|g" \
    -e "s|@ICEY_SOURCE_SRI@|$(escape_sed "$TEMPLATE_ICEY_SOURCE_SRI")|g" \
    -e "s|@ICEY_SERVER_SOURCE_DIRNAME@|$(escape_sed "$TEMPLATE_SERVER_SOURCE_DIRNAME")|g" \
    -e "s|@ICEY_SOURCE_DIRNAME@|$(escape_sed "$TEMPLATE_ICEY_SOURCE_DIRNAME")|g" \
    -e "s|@LINUX_TARBALL_URL@|$(escape_sed "$TEMPLATE_LINUX_TARBALL_URL")|g" \
    -e "s|@LINUX_TARBALL_SHA256@|$(escape_sed "$TEMPLATE_LINUX_TARBALL_SHA256")|g" \
    -e "s|@LINUX_ZIP_URL@|$(escape_sed "$TEMPLATE_LINUX_ZIP_URL")|g" \
    -e "s|@LINUX_ZIP_SHA256@|$(escape_sed "$TEMPLATE_LINUX_ZIP_SHA256")|g" \
    -e "s|@DEB_URL@|$(escape_sed "$TEMPLATE_DEB_URL")|g" \
    -e "s|@DEB_SHA256@|$(escape_sed "$TEMPLATE_DEB_SHA256")|g" \
    -e "s|@WINDOWS_ZIP_URL@|$(escape_sed "$TEMPLATE_WINDOWS_ZIP_URL")|g" \
    -e "s|@WINDOWS_ZIP_SHA256@|$(escape_sed "$TEMPLATE_WINDOWS_ZIP_SHA256")|g" \
    -e "s|@APT_BASE_URL@|$(escape_sed "$APT_BASE_URL")|g" \
    -e "s|@APT_SUITE@|$(escape_sed "$APT_SUITE")|g" \
    -e "s|@APT_COMPONENT@|$(escape_sed "$APT_COMPONENT")|g" \
    "$src" > "$dst"
}

TEMPLATE_SERVER_SOURCE_URL="${ICEY_SERVER_SOURCE_URL:-$SERVER_SOURCE_URL}"
TEMPLATE_ICEY_SOURCE_URL="${ICEY_SOURCE_URL}"
TEMPLATE_SERVER_SOURCE_SHA256="${SERVER_SOURCE_SHA256:-}"
TEMPLATE_ICEY_SOURCE_SHA256="${ICEY_SOURCE_SHA256:-}"
TEMPLATE_SERVER_SOURCE_SRI="${SERVER_SOURCE_SRI:-}"
TEMPLATE_ICEY_SOURCE_SRI="${ICEY_SOURCE_SRI:-}"
TEMPLATE_SERVER_SOURCE_DIRNAME="$SERVER_SOURCE_DIRNAME"
TEMPLATE_ICEY_SOURCE_DIRNAME="$ICEY_SOURCE_DIRNAME"
TEMPLATE_LINUX_TARBALL_URL="$LINUX_TARBALL_URL"
TEMPLATE_LINUX_TARBALL_SHA256="${LINUX_TARBALL_SHA256:-}"
TEMPLATE_LINUX_ZIP_URL="$LINUX_ZIP_URL"
TEMPLATE_LINUX_ZIP_SHA256="${LINUX_ZIP_SHA256:-}"
TEMPLATE_DEB_URL="$DEB_URL"
TEMPLATE_DEB_SHA256="${DEB_SHA256:-}"
TEMPLATE_WINDOWS_ZIP_URL="$WINDOWS_ZIP_URL"
TEMPLATE_WINDOWS_ZIP_SHA256="${WINDOWS_ZIP_SHA256:-}"
APT_BASE_URL="${APT_BASE_URL:-https://apt.0state.com/icey}"
APT_SUITE="${APT_SUITE:-stable}"
APT_COMPONENT="${APT_COMPONENT:-main}"

for required in \
  TEMPLATE_SERVER_SOURCE_SHA256 \
  TEMPLATE_ICEY_SOURCE_SHA256 \
  TEMPLATE_SERVER_SOURCE_SRI \
  TEMPLATE_ICEY_SOURCE_SRI \
  TEMPLATE_LINUX_TARBALL_SHA256 \
  TEMPLATE_LINUX_ZIP_SHA256 \
  TEMPLATE_DEB_SHA256 \
  APT_REPO_SHA256
do
  if [[ -z "${!required:-}" ]]; then
    echo "missing required release metadata: $required" >&2
    exit 1
  fi
done

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

render_template \
  "$TEMPLATES_DIR/homebrew/icey-server.rb.in" \
  "$OUT_DIR/homebrew/icey-server.rb"

render_template \
  "$TEMPLATES_DIR/aur/PKGBUILD.in" \
  "$OUT_DIR/aur/PKGBUILD"

cat > "$OUT_DIR/aur/.SRCINFO" <<EOF
pkgbase = icey-server
	pkgdesc = Self-hosted source-to-browser server built on icey
	pkgver = $SERVER_VERSION
	pkgrel = 1
	url = https://0state.com/icey/
	arch = x86_64
	license = AGPL3
	makedepends = cmake
	makedepends = gcc
	makedepends = make
	makedepends = nodejs
	makedepends = npm
	makedepends = pkgconf
	depends = ffmpeg
	depends = openssl
	source = icey-server-${SERVER_VERSION}.tar.gz::$TEMPLATE_SERVER_SOURCE_URL
	source = icey-${ICEY_VERSION}.tar.gz::$TEMPLATE_ICEY_SOURCE_URL
	sha256sums = $TEMPLATE_SERVER_SOURCE_SHA256
	sha256sums = $TEMPLATE_ICEY_SOURCE_SHA256

pkgname = icey-server
EOF

render_template \
  "$TEMPLATES_DIR/apt/icey-server.list.in" \
  "$OUT_DIR/apt/icey-server.list"

render_template \
  "$TEMPLATES_DIR/nix/default.nix.in" \
  "$OUT_DIR/nix/default.nix"

if [[ -n "${TEMPLATE_WINDOWS_ZIP_SHA256:-}" ]]; then
  render_template \
    "$TEMPLATES_DIR/scoop/icey-server.json.in" \
    "$OUT_DIR/scoop/icey-server.json"

  render_template \
    "$TEMPLATES_DIR/chocolatey/icey-server.nuspec.in" \
    "$OUT_DIR/chocolatey/icey-server.nuspec"
  render_template \
    "$TEMPLATES_DIR/chocolatey/tools/chocolateyinstall.ps1.in" \
    "$OUT_DIR/chocolatey/tools/chocolateyinstall.ps1"
  render_template \
    "$TEMPLATES_DIR/chocolatey/tools/chocolateyuninstall.ps1.in" \
    "$OUT_DIR/chocolatey/tools/chocolateyuninstall.ps1"

  render_template \
    "$TEMPLATES_DIR/winget/0state.IceyServer.yaml.in" \
    "$OUT_DIR/winget/0state.IceyServer.yaml"
  render_template \
    "$TEMPLATES_DIR/winget/0state.IceyServer.locale.en-US.yaml.in" \
    "$OUT_DIR/winget/0state.IceyServer.locale.en-US.yaml"
  render_template \
    "$TEMPLATES_DIR/winget/0state.IceyServer.installer.yaml.in" \
    "$OUT_DIR/winget/0state.IceyServer.installer.yaml"
fi

cat > "$OUT_DIR/SHA256SUMS.txt" <<EOF
$TEMPLATE_SERVER_SOURCE_SHA256  $(basename "$SERVER_SOURCE_ARCHIVE")
$TEMPLATE_ICEY_SOURCE_SHA256  $(basename "$ICEY_SOURCE_ARCHIVE")
$TEMPLATE_LINUX_TARBALL_SHA256  $(basename "$LINUX_TARBALL")
$TEMPLATE_LINUX_ZIP_SHA256  $(basename "$LINUX_ZIP")
$TEMPLATE_DEB_SHA256  $(basename "$DEB_PATH")
$APT_REPO_SHA256  $(basename "$APT_REPO_ARCHIVE")
EOF

if [[ -n "${TEMPLATE_WINDOWS_ZIP_SHA256:-}" ]]; then
  printf '%s  %s\n' "$TEMPLATE_WINDOWS_ZIP_SHA256" "$(basename "$WINDOWS_ZIP")" >> "$OUT_DIR/SHA256SUMS.txt"
fi

echo "Rendered package manager manifests: $OUT_DIR"
