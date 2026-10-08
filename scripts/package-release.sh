#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eval "$(bash "$ROOT_DIR/scripts/release-context.sh")"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build-release}"
PACKAGE_NAME="icey-server-${SERVER_VERSION}-$(uname -s)-$(uname -m)"
STAGE_ROOT="${STAGE_ROOT:-$ROOT_DIR/.stage/package-release}"
PACKAGE_ROOT="$STAGE_ROOT/$PACKAGE_NAME"
PACKAGE_PATH="$ROOT_DIR/${PACKAGE_NAME}.tar.gz"
ZIP_PATH="$ROOT_DIR/${PACKAGE_NAME}.zip"
LATEST_PACKAGE_PATH="$ROOT_DIR/icey-server-$(uname -s)-$(uname -m).tar.gz"
LATEST_ZIP_PATH="$ROOT_DIR/icey-server-$(uname -s)-$(uname -m).zip"

if [[ ! -f "$ICEY_SOURCE_DIR/CMakeLists.txt" ]]; then
  echo "ICEY_SOURCE_DIR does not point to an icey source tree: $ICEY_SOURCE_DIR" >&2
  exit 1
fi

cmake -S "$ROOT_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DICEY_SOURCE_DIR="$ICEY_SOURCE_DIR"
cmake --build "$BUILD_DIR" -j1 --target icey-server

npm --prefix "$ROOT_DIR/web" ci
npm --prefix "$ROOT_DIR/web" run build

rm -rf "$PACKAGE_ROOT"
mkdir -p "$STAGE_ROOT"

cmake --install "$BUILD_DIR" --prefix "$PACKAGE_ROOT" --component apps

if [[ ! -x "$PACKAGE_ROOT/bin/icey-server" ]]; then
  echo "Packaged binary missing from staged layout: $PACKAGE_ROOT/bin/icey-server" >&2
  exit 1
fi

if [[ ! -f "$PACKAGE_ROOT/share/icey-server/web/index.html" ]]; then
  echo "Packaged web UI missing from staged layout: $PACKAGE_ROOT/share/icey-server/web/index.html" >&2
  exit 1
fi

rm -f "$PACKAGE_PATH"
tar -C "$STAGE_ROOT" -czf "$PACKAGE_PATH" "$PACKAGE_NAME"
rm -f "$ZIP_PATH"
(
  cd "$STAGE_ROOT"
  zip -qr "$ZIP_PATH" "$PACKAGE_NAME"
)
cp "$PACKAGE_PATH" "$LATEST_PACKAGE_PATH"
cp "$ZIP_PATH" "$LATEST_ZIP_PATH"

echo "Created package: $PACKAGE_PATH"
echo "Created package: $ZIP_PATH"
echo "Created stable alias: $LATEST_PACKAGE_PATH"
echo "Created stable alias: $LATEST_ZIP_PATH"
