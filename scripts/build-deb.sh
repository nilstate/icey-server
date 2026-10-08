#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eval "$(bash "$ROOT_DIR/scripts/release-context.sh")"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build-release}"
STAGE_DIR="${STAGE_DIR:-$ROOT_DIR/.stage/debian}"
CONTROL_TEMPLATE="$ROOT_DIR/packaging/templates/debian/control.in"

map_arch() {
  case "$(uname -m)" in
    x86_64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)
      echo "Unsupported Debian architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

DEB_ARCH="${DEB_ARCH:-$(map_arch)}"
DEB_DEPENDS="${DEB_DEPENDS:-ffmpeg, libssl3, libc6, libstdc++6}"
PACKAGE_NAME="icey-server_${SERVER_VERSION}_${DEB_ARCH}"
PACKAGE_ROOT="$STAGE_DIR/$PACKAGE_NAME"
PACKAGE_PATH="${PACKAGE_PATH:-$ROOT_DIR/${PACKAGE_NAME}.deb}"

if [[ ! -f "$ICEY_SOURCE_DIR/CMakeLists.txt" ]]; then
  echo "ICEY_SOURCE_DIR does not point to an icey source tree: $ICEY_SOURCE_DIR" >&2
  exit 1
fi

if [[ ! -f "$CONTROL_TEMPLATE" ]]; then
  echo "Debian control template missing: $CONTROL_TEMPLATE" >&2
  exit 1
fi

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DICEY_SOURCE_DIR="$ICEY_SOURCE_DIR"
cmake --build "$BUILD_DIR" -j1 --target icey-server

npm --prefix "$ROOT_DIR/web" ci
npm --prefix "$ROOT_DIR/web" run build

rm -rf "$PACKAGE_ROOT"
mkdir -p "$PACKAGE_ROOT/DEBIAN"

cmake --install "$BUILD_DIR" --prefix "$PACKAGE_ROOT/usr" --component apps

sed \
  -e "s|@DEB_PACKAGE_NAME@|icey-server|g" \
  -e "s|@SERVER_VERSION@|$SERVER_VERSION|g" \
  -e "s|@DEB_ARCH@|$DEB_ARCH|g" \
  -e "s|@DEB_DEPENDS@|$DEB_DEPENDS|g" \
  "$CONTROL_TEMPLATE" > "$PACKAGE_ROOT/DEBIAN/control"

chmod 0755 "$PACKAGE_ROOT"
chmod 0644 "$PACKAGE_ROOT/DEBIAN/control"

rm -f "$PACKAGE_PATH"
dpkg-deb --build --root-owner-group "$PACKAGE_ROOT" "$PACKAGE_PATH" >/dev/null

echo "Created Debian package: $PACKAGE_PATH"
