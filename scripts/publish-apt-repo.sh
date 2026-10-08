#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APT_REPO_ROOT="${APT_REPO_ROOT:-$ROOT_DIR/.stage/apt-repo}"
PACKAGES_REPO_DIR="${PACKAGES_REPO_DIR:?Set PACKAGES_REPO_DIR to the checked out package repository}"
APT_REPO_PATH="${APT_REPO_PATH:-icey}"
APT_PUBLIC_DIR="${APT_PUBLIC_DIR:-$ROOT_DIR/.stage/apt-public}"
APT_LIST_SOURCE="${APT_LIST_SOURCE:-$ROOT_DIR/.stage/package-managers/rendered/apt/icey-server.list}"
APT_BASE_URL="${APT_BASE_URL:-https://apt.0state.com/icey}"
DEST_DIR="$PACKAGES_REPO_DIR/$APT_REPO_PATH"

if [[ ! -d "$APT_REPO_ROOT/dists" ]]; then
  echo "APT repository root missing or incomplete: $APT_REPO_ROOT" >&2
  exit 1
fi

if [[ ! -d "$PACKAGES_REPO_DIR/.git" ]]; then
  echo "Package repository root missing or not a git checkout: $PACKAGES_REPO_DIR" >&2
  exit 1
fi

for required in \
  "$APT_REPO_ROOT/dists/stable/InRelease" \
  "$APT_REPO_ROOT/dists/stable/Release.gpg" \
  "$APT_REPO_ROOT/dists/stable/Release" \
  "$APT_PUBLIC_DIR/icey-archive-keyring.gpg" \
  "$APT_PUBLIC_DIR/icey-archive-keyring.asc"; do
  if [[ ! -f "$required" ]]; then
    echo "Signed APT repository is incomplete: $required" >&2
    exit 1
  fi
done
gpgv --keyring "$APT_PUBLIC_DIR/icey-archive-keyring.gpg" \
  "$APT_REPO_ROOT/dists/stable/Release.gpg" \
  "$APT_REPO_ROOT/dists/stable/Release"
gpgv --keyring "$APT_PUBLIC_DIR/icey-archive-keyring.gpg" \
  "$APT_REPO_ROOT/dists/stable/InRelease"

mkdir -p "$PACKAGES_REPO_DIR"
touch "$PACKAGES_REPO_DIR/.nojekyll"

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"
cp -R "$APT_REPO_ROOT"/. "$DEST_DIR/"

if [[ -d "$APT_PUBLIC_DIR" ]]; then
  find "$APT_PUBLIC_DIR" -maxdepth 1 -type f \
    \( -name '*.asc' -o -name '*.gpg' \) \
    -exec cp {} "$DEST_DIR/" \;
fi

if [[ -f "$APT_LIST_SOURCE" ]]; then
  cp "$APT_LIST_SOURCE" "$DEST_DIR/icey-server.list"
fi

cat > "$PACKAGES_REPO_DIR/index.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>0state Packages</title>
  </head>
  <body>
    <main>
      <h1>0state Packages</h1>
      <p>Static package repositories for 0state distributions.</p>
      <ul>
        <li><a href="./icey/">Icey APT repository</a></li>
      </ul>
    </main>
  </body>
</html>
EOF

cat > "$DEST_DIR/index.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Icey APT Repository</title>
  </head>
  <body>
    <main>
      <h1>Icey APT Repository</h1>
      <p>This path hosts the static APT repository for <code>icey-server</code>.</p>
      <p>Canonical base URL: <code>APT_BASE_URL_PLACEHOLDER</code></p>
      APT_INSTALL_BLOCK_PLACEHOLDER
    </main>
  </body>
</html>
EOF

python3 - <<PY
from pathlib import Path
path = Path(r"$DEST_DIR/index.html")
text = path.read_text().replace("APT_BASE_URL_PLACEHOLDER", r"$APT_BASE_URL")
install_block = """<p>Install the signing key:</p>
      <pre><code>curl -fsSL APT_BASE_URL_PLACEHOLDER/icey-archive-keyring.gpg | \\
sudo tee /usr/share/keyrings/icey-archive-keyring.gpg >/dev/null</code></pre>
      <p>Add the repository:</p>
      <pre><code>curl -fsSL APT_BASE_URL_PLACEHOLDER/icey-server.list | \\
sudo tee /etc/apt/sources.list.d/icey-server.list >/dev/null
sudo apt update</code></pre>
      <ul>
        <li><a href="./icey-server.list">icey-server.list</a></li>
        <li><a href="./icey-archive-keyring.gpg">icey-archive-keyring.gpg</a></li>
        <li><a href="./icey-archive-keyring.asc">icey-archive-keyring.asc</a></li>
      </ul>"""
text = text.replace("APT_INSTALL_BLOCK_PLACEHOLDER", install_block)
text = text.replace("APT_BASE_URL_PLACEHOLDER", r"$APT_BASE_URL")
path.write_text(text)
PY

echo "Published APT repository to $DEST_DIR"
