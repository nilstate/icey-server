#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${APT_GPG_PRIVATE_KEY:-}" ]]; then
  echo "APT_GPG_PRIVATE_KEY is required to publish the signed APT repository" >&2
  exit 1
fi

GNUPGHOME="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/icey-apt-gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
export GNUPGHOME
printf '%s\n' "$APT_GPG_PRIVATE_KEY" | gpg --batch --import
APT_GPG_KEY_ID="$(gpg --batch --with-colons --list-secret-keys | awk -F: '/^sec:/ { print $5; exit }')"
if [[ -z "$APT_GPG_KEY_ID" ]]; then
  echo "Failed to discover imported APT signing key" >&2
  exit 1
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "GNUPGHOME=$GNUPGHOME" >> "$GITHUB_ENV"
  echo "APT_GPG_KEY_ID=$APT_GPG_KEY_ID" >> "$GITHUB_ENV"
else
  echo "GNUPGHOME=$GNUPGHOME"
  echo "APT_GPG_KEY_ID=$APT_GPG_KEY_ID"
fi
