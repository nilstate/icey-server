#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eval "$(bash "$ROOT_DIR/scripts/release-context.sh")"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build-release}"
REPO_ROOT="${REPO_ROOT:-$ROOT_DIR/.stage/apt-repo}"
REPO_ARCHIVE="${REPO_ARCHIVE:-$APT_REPO_ARCHIVE}"
APT_SUITE="${APT_SUITE:-stable}"
APT_COMPONENT="${APT_COMPONENT:-main}"
APT_PUBLIC_DIR="${APT_PUBLIC_DIR:-$ROOT_DIR/.stage/apt-public}"
APT_KEYRING_NAME="${APT_KEYRING_NAME:-icey-archive-keyring}"
APT_GPG_KEY_ID="${APT_GPG_KEY_ID:-}"
APT_GPG_PASSPHRASE="${APT_GPG_PASSPHRASE:-}"

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
DEB_PATH="${DEB_PATH:-$ROOT_DIR/icey-server_${SERVER_VERSION}_${DEB_ARCH}.deb}"

if [[ ! -f "$DEB_PATH" ]]; then
  ICEY_SOURCE_DIR="$ICEY_SOURCE_DIR" BUILD_DIR="$BUILD_DIR" "$ROOT_DIR/scripts/build-deb.sh"
fi

rm -rf "$REPO_ROOT"
mkdir -p \
  "$REPO_ROOT/pool/$APT_COMPONENT/i/icey-server" \
  "$REPO_ROOT/dists/$APT_SUITE/$APT_COMPONENT/binary-$DEB_ARCH"

cp "$DEB_PATH" "$REPO_ROOT/pool/$APT_COMPONENT/i/icey-server/"

pushd "$REPO_ROOT" >/dev/null
dpkg-scanpackages --multiversion "pool/$APT_COMPONENT" /dev/null \
  > "dists/$APT_SUITE/$APT_COMPONENT/binary-$DEB_ARCH/Packages"
gzip -9fk "dists/$APT_SUITE/$APT_COMPONENT/binary-$DEB_ARCH/Packages"
popd >/dev/null

PACKAGES_REL="dists/$APT_SUITE/$APT_COMPONENT/binary-$DEB_ARCH/Packages"
PACKAGES_GZ_REL="${PACKAGES_REL}.gz"
PACKAGES_PATH="$REPO_ROOT/$PACKAGES_REL"
PACKAGES_GZ_PATH="$REPO_ROOT/$PACKAGES_GZ_REL"
RELEASE_PATH="$REPO_ROOT/dists/$APT_SUITE/Release"

packages_size="$(stat -c '%s' "$PACKAGES_PATH")"
packages_gz_size="$(stat -c '%s' "$PACKAGES_GZ_PATH")"
packages_md5="$(md5sum "$PACKAGES_PATH" | awk '{print $1}')"
packages_gz_md5="$(md5sum "$PACKAGES_GZ_PATH" | awk '{print $1}')"
packages_sha256="$(sha256sum "$PACKAGES_PATH" | awk '{print $1}')"
packages_gz_sha256="$(sha256sum "$PACKAGES_GZ_PATH" | awk '{print $1}')"

cat > "$RELEASE_PATH" <<EOF
Origin: 0state
Label: icey
Suite: $APT_SUITE
Codename: $APT_SUITE
Architectures: $DEB_ARCH
Components: $APT_COMPONENT
Description: icey-server APT repository
Date: $(LC_ALL=C date -Ru)
MD5Sum:
 $packages_md5 $packages_size $APT_COMPONENT/binary-$DEB_ARCH/Packages
 $packages_gz_md5 $packages_gz_size $APT_COMPONENT/binary-$DEB_ARCH/Packages.gz
SHA256:
 $packages_sha256 $packages_size $APT_COMPONENT/binary-$DEB_ARCH/Packages
 $packages_gz_sha256 $packages_gz_size $APT_COMPONENT/binary-$DEB_ARCH/Packages.gz
EOF

if [[ -n "$APT_GPG_KEY_ID" ]]; then
  if ! command -v gpg >/dev/null 2>&1; then
    echo "APT_GPG_KEY_ID is set but gpg is not installed" >&2
    exit 1
  fi

  mkdir -p "$APT_PUBLIC_DIR"
  rm -f \
    "$REPO_ROOT/dists/$APT_SUITE/InRelease" \
    "$REPO_ROOT/dists/$APT_SUITE/Release.gpg" \
    "$APT_PUBLIC_DIR/${APT_KEYRING_NAME}.asc" \
    "$APT_PUBLIC_DIR/${APT_KEYRING_NAME}.gpg"

  gpg_sign_args=(--batch --yes --local-user "$APT_GPG_KEY_ID")
  if [[ -n "$APT_GPG_PASSPHRASE" ]]; then
    gpg_sign_args+=(--pinentry-mode loopback --passphrase "$APT_GPG_PASSPHRASE")
  fi

  gpg "${gpg_sign_args[@]}" \
    --armor --detach-sign \
    --output "$REPO_ROOT/dists/$APT_SUITE/Release.gpg" \
    "$RELEASE_PATH"
  gpg "${gpg_sign_args[@]}" \
    --clearsign \
    --output "$REPO_ROOT/dists/$APT_SUITE/InRelease" \
    "$RELEASE_PATH"

  gpg --batch --yes --armor --export "$APT_GPG_KEY_ID" \
    > "$APT_PUBLIC_DIR/${APT_KEYRING_NAME}.asc"
  gpg --batch --yes --export "$APT_GPG_KEY_ID" \
    > "$APT_PUBLIC_DIR/${APT_KEYRING_NAME}.gpg"
fi

rm -f "$REPO_ARCHIVE"
tar -C "$REPO_ROOT" -czf "$REPO_ARCHIVE" .

echo "Created APT repository: $REPO_ROOT"
echo "Created APT repository archive: $REPO_ARCHIVE"
