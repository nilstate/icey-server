#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eval "$(bash "$ROOT_DIR/scripts/release-context.sh")"
SERVER_ARCHIVE="${SERVER_ARCHIVE:-$SERVER_SOURCE_ARCHIVE}"
ICEY_ARCHIVE="${ICEY_ARCHIVE:-$ICEY_SOURCE_ARCHIVE}"
SERVER_ARCHIVE_REF="${SERVER_ARCHIVE_REF:-HEAD}"
ICEY_ARCHIVE_REF="${ICEY_ARCHIVE_REF:-HEAD}"

if [[ "$(git -C "$ROOT_DIR" rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]]; then
  echo "icey-server source tree is not a git repository: $ROOT_DIR" >&2
  exit 1
fi

if [[ "$(git -C "$ICEY_SOURCE_DIR" rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]]; then
  echo "ICEY_SOURCE_DIR does not point to an icey git repository: $ICEY_SOURCE_DIR" >&2
  exit 1
fi

git -C "$ROOT_DIR" archive \
  --format=tar.gz \
  --prefix="${SERVER_SOURCE_DIRNAME}/" \
  -o "$SERVER_ARCHIVE" \
  "$SERVER_ARCHIVE_REF"

git -C "$ICEY_SOURCE_DIR" archive \
  --format=tar.gz \
  --prefix="${ICEY_SOURCE_DIRNAME}/" \
  -o "$ICEY_ARCHIVE" \
  "$ICEY_ARCHIVE_REF"

echo "Created source archive: $SERVER_ARCHIVE"
echo "Created source archive: $ICEY_ARCHIVE"
