#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
release_context="$(bash "$SCRIPT_DIR/release-context.sh")"
eval "$release_context"

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

sri_sha256_file() {
  local base64_hash
  base64_hash="$(openssl dgst -sha256 -binary "$1" | openssl base64 -A)"
  printf 'sha256-%s' "$base64_hash"
}

emit_if_present() {
  local name="$1"
  local value="$2"
  printf '%s=%q\n' "$name" "$value"
}

if [[ -f "$SERVER_SOURCE_ARCHIVE" ]]; then
  emit_if_present SERVER_SOURCE_SHA256 "$(sha256_file "$SERVER_SOURCE_ARCHIVE")"
  emit_if_present SERVER_SOURCE_SRI "$(sri_sha256_file "$SERVER_SOURCE_ARCHIVE")"
fi

if [[ -f "$ICEY_SOURCE_ARCHIVE" ]]; then
  emit_if_present ICEY_SOURCE_SHA256 "$(sha256_file "$ICEY_SOURCE_ARCHIVE")"
  emit_if_present ICEY_SOURCE_SRI "$(sri_sha256_file "$ICEY_SOURCE_ARCHIVE")"
fi

if [[ -f "$LINUX_TARBALL" ]]; then
  emit_if_present LINUX_TARBALL_SHA256 "$(sha256_file "$LINUX_TARBALL")"
fi

if [[ -f "$LINUX_ZIP" ]]; then
  emit_if_present LINUX_ZIP_SHA256 "$(sha256_file "$LINUX_ZIP")"
fi

if [[ -f "$DEB_PATH" ]]; then
  emit_if_present DEB_SHA256 "$(sha256_file "$DEB_PATH")"
fi

if [[ -f "$APT_REPO_ARCHIVE" ]]; then
  emit_if_present APT_REPO_SHA256 "$(sha256_file "$APT_REPO_ARCHIVE")"
fi

if [[ -f "$WINDOWS_ZIP" ]]; then
  emit_if_present WINDOWS_ZIP_SHA256 "$(sha256_file "$WINDOWS_ZIP")"
fi
