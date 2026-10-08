# Package Managers

This repo ships package-manager inputs for the full public distribution surface:

- Homebrew
- AUR
- Debian / APT
- Nix
- winget
- Scoop
- Chocolatey

The package model is split intentionally:

- `Homebrew`, `AUR`, and `Nix` are source-build package managers. They build
  `icey-server` from `icey-server` plus the matching `icey` source archive.
- `Debian / APT` consumes the generated Linux `amd64` binary package.
- Published APT repositories can also ship a signing key plus
  `InRelease` / `Release.gpg` metadata when `APT_GPG_KEY_ID` is configured.
- `winget`, `Scoop`, and `Chocolatey` consume the planned Windows portable zip
  artifact.

The pinned `icey` dependency release lives in [`ICEY_VERSION`](../ICEY_VERSION). CI and release workflows check out that exact `icey` tag.

## Tracked Files

- Templates live under `packaging/templates/`.
- Generated local manifests are written to `.stage/package-managers/rendered/`.

## Generator Scripts

- `scripts/build-source-archives.sh`
- `scripts/package-release.sh`
- `scripts/build-deb.sh`
- `scripts/build-apt-repo.sh`
- `scripts/render-package-managers.sh`
- `scripts/package-manager-check.sh`

## Local Validation

Run:

```bash
make package-managers
```

That validates the Linux release artifacts, Debian package, APT repo archive,
and rendered manifests for every package manager that has a real artifact.

## Release Convention

The manifests assume release assets named like:

- `icey-server-<version>-source.tar.gz`
- `icey-<version>-source.tar.gz`
- `icey-server-<version>-Linux-x86_64.tar.gz`
- `icey-server-<version>-Linux-x86_64.zip`
- `icey-server_<version>_amd64.deb`
- `icey-server-apt-repo-<version>.tar.gz`
- `icey-server-<version>-Windows-x86_64.zip`

Windows-facing manifests are rendered only when a real Windows release artifact
and checksum exist. Placeholder package-manager outputs are no longer emitted.
