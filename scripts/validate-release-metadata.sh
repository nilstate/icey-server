#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
release_context="$(bash "$ROOT_DIR/scripts/release-context.sh")"
eval "$release_context"

expected_tag="${1:-}"
if [[ -n "$expected_tag" && "$expected_tag" != "$SERVER_TAG" ]]; then
  echo "expected release tag $SERVER_TAG, got $expected_tag" >&2
  exit 1
fi

if [[ -n "$expected_tag" ]]; then
  if [[ -n "${GITHUB_EVENT_PATH:-}" && -f "$GITHUB_EVENT_PATH" ]]; then
    if python3 - "$GITHUB_EVENT_PATH" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as event_file:
    sys.exit(0 if json.load(event_file).get("forced") else 1)
PY
    then
      echo "refusing force-updated release tag $SERVER_TAG" >&2
      exit 1
    fi
  fi
  head_commit="$(git -C "$ROOT_DIR" rev-parse HEAD)"
  local_tag_commit="$(git -C "$ROOT_DIR" rev-parse "refs/tags/${SERVER_TAG}^{commit}" 2>/dev/null || true)"
  remote_tag_commit="$(git -C "$ROOT_DIR" ls-remote --tags origin "refs/tags/${SERVER_TAG}^{}" | awk 'NR == 1 {print $1}')"
  if [[ -z "$remote_tag_commit" ]]; then
    remote_tag_commit="$(git -C "$ROOT_DIR" ls-remote --refs --tags origin "refs/tags/${SERVER_TAG}" | awk 'NR == 1 {print $1}')"
  fi
  if [[ "$head_commit" != "$local_tag_commit" || "$head_commit" != "$remote_tag_commit" ]]; then
    echo "release tag $SERVER_TAG must point to the checked-out commit on origin" >&2
    exit 1
  fi
  git -C "$ROOT_DIR" fetch origin main --no-tags
  if ! git -C "$ROOT_DIR" merge-base --is-ancestor "$head_commit" origin/main; then
    echo "release tag $SERVER_TAG must be reachable from origin/main" >&2
    exit 1
  fi
fi

if ! grep -Eq "^## ${SERVER_VERSION} - " "$ROOT_DIR/CHANGELOG.md"; then
  echo "CHANGELOG.md is missing a section for ${SERVER_VERSION}" >&2
  exit 1
fi

section="$(
  awk '/^## '"$SERVER_VERSION"' - /{found=1; next} /^## /{if(found) exit} found{print}' "$ROOT_DIR/CHANGELOG.md"
)"
printf '%s\n' "$section" | grep -Eq '[^[:space:]]' || {
  echo "CHANGELOG.md section for ${SERVER_VERSION} is empty" >&2
  exit 1
}

echo "release metadata is valid for ${SERVER_TAG} (icey ${ICEY_VERSION})"
