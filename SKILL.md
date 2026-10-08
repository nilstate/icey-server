---
name: icey-server-operator
description: Safely build, validate, package, release, and operate the icey-server CLI and media server surface.
---

# icey-server Operator Workflow

This is a portable skill document for agents working in `nilstate/icey-server`.
Use it to preserve the repo's build, validation, packaging, and operator bring-up conventions.

The file is useful as plain project documentation. Tools that understand `SKILL.md`, including runx, can optionally pair it with execution, verification, and receipts.

## Evidence Sources

This workflow is grounded in these repo files:

- `README.md`: native quick start, Docker demo path, repo workflow, runtime modes, endpoints, browser smoke notes, and bring-up order.
- `CMakeLists.txt`: C++20 project shape, `ICEY_SOURCE_DIR`, icey component requirements, install layout, and web UI install destination.
- `CMakePresets.json`: `dev` and `release` configure/build presets using a sibling `../icey` checkout.
- `Makefile`: canonical wrapper targets for configure, build, web, install, package, release, Docker, package-manager validation, and the macOS-only `facetime-demo` helper.
- `web/package.json`: Vite build and Playwright smoke commands for Chromium, Firefox, WebKit, and Docker smoke.
- `.github/workflows/ci.yml`: Linux CI contract using Ubuntu 24.04, GCC 13, pinned `ICEY_VERSION`, web build, staged install, browser smoke, and package-manager cutover.
- `.github/workflows/release.yml`: release package, Docker image, GitHub release assets, and optional package-manager publication flow.
- `.github/workflows/publish-package-managers.yml`: Homebrew, AUR, APT, and rendered manifest publication gates.
- `packaging/README.md`: package-manager model, artifact names, generator scripts, and validation expectations.
- `docker/README.md`: fastest demo path, host-networking assumptions, runtime overrides, and Compose source path.
- `docs/facetime-on-macbook.md`: macOS realtime path. Single-process bring-up via the `avfoundation:` URL scheme dispatched by `MediaCapture::openFile`. Covers permission prompts, audio resampler bring-up, and the speaker default-mute.
- `scripts/facetime-demo.sh`: one-command single-process bring-up of `icey-server --source 'avfoundation:0:none'` on macOS, fronted by the `make facetime-demo` target.
- `VERSION` and `ICEY_VERSION`: release context for this repo and the pinned core `nilstate/icey` dependency.

For the current versions, read `VERSION` (icey-server) and `ICEY_VERSION` (the pinned core icey dependency) rather than relying on numbers in this file.

## When To Use This Skill

Use this skill when an agent needs to:

- change `icey-server` C++ server behavior, CLI flags, config handling, operator endpoints, or install layout
- update the bundled web UI or browser smoke expectations
- validate native builds against a sibling `nilstate/icey` checkout
- modify Docker demo behavior or runtime environment variables
- modify packaging, release metadata, package-manager manifests, or publication workflows
- help an operator bring up `stream`, `record`, `relay`, TURN, RTSP, or TLS paths without mixing failure domains

Do not use this skill to change core media primitives in `nilstate/icey`; that belongs in the core repo. This repo consumes the pinned core release through `ICEY_VERSION`.

## Inputs To Inspect First

Always inspect these before planning changes:

- `README.md` for the public operator contract and CLI option list
- `Makefile` for preferred local commands
- `CMakePresets.json` and `CMakeLists.txt` for build shape and dependency wiring
- `ICEY_VERSION` before assuming core API behavior
- `.github/workflows/ci.yml` before changing validation expectations
- `web/package.json` before changing browser smoke behavior
- `packaging/README.md` and `scripts/*release*` before changing release or package-manager output
- `docker/README.md` and `docker/*` before changing demo behavior

If a requested change touches release output, inspect `VERSION`, `CHANGELOG.md`, `scripts/validate-release-metadata.sh`, and `scripts/package-manager-check.sh` in the same pass.

## Safe Operating Rules

- Keep the express demo path simple: `docker run --rm --network host 0state/icey-server:latest`, then `http://localhost:4500`.
- Do not claim Safari support from Linux Playwright WebKit results; the README explicitly withholds that claim until Apple-platform validation exists.
- Keep runtime bring-up staged: local `stream` without TURN, then `record`, then `relay`, then TURN-enabled external or NAT testing.
- Treat `--doctor` as the first machine-readable preflight for operator-facing runtime changes.
- Preserve the pinned `ICEY_VERSION` model. Do not silently float to `nilstate/icey` main in release or CI paths.
- Keep package-manager output tied to real artifacts. Do not emit placeholder manifests for package managers without a matching archive and checksum.
- Do not weaken CI coverage when changing C++, web UI, packaging, or release surfaces.
- Do not add hosted service assumptions; the README positions the app as one binary plus local ports.

## Workflow

### 1. Classify The Change

Map the request to one or more surfaces:

- `server`: C++ server, CLI flags, config, endpoints, runtime modes
- `web`: Vite UI, Symple client/player integration, browser smoke
- `docker`: published image, Compose source path, host-networking demo
- `packaging`: staged layout, tar/zip/deb/APT/package-manager manifests
- `release`: VERSION, ICEY_VERSION, changelog, GitHub release assets, Docker Hub
- `docs`: README, docker README, packaging README, operator instructions

If the change crosses surfaces, plan validation for each touched surface before editing.

### 2. Build Or Configure Locally

Preferred source-backed path with the sibling `icey` checkout:

```bash
cmake --preset dev
cmake --build --preset dev
```

Equivalent Makefile path:

```bash
make configure
make build
```

If the sibling checkout is not at `../icey`, pass `ICEY_SOURCE_DIR=/path/to/icey` explicitly.

### 3. Validate Runtime Readiness

Use `--doctor` before claiming the server is runnable:

```bash
./build-dev/src/server/icey-server --doctor
```

For RTSP paths, start from the tracked example:

```bash
cp config.rtsp.example.json config.local.json
$EDITOR config.local.json
./build-dev/src/server/icey-server --config config.local.json --doctor
./build-dev/src/server/icey-server --config config.local.json
```

For a browser-visible local app, build the web UI first:

```bash
make web-install
make web-build
./build-dev/src/server/icey-server --web-root web/dist --source /path/to/video.mp4
```

### 4. Validate Browser And Demo Paths

For UI changes or media-path claims, run the Chromium smoke path that CI treats as authoritative:

```bash
npm --prefix web ci
npm --prefix web run build
npm --prefix web run test:smoke:chromium
```

For the published-image demo contract, keep the public command stable:

```bash
docker run --rm --network host 0state/icey-server:latest
```

For local source-backed Docker validation:

```bash
docker compose -f docker/compose.yaml up --build
```

For the macOS realtime FaceTime path, exercise the dedicated helper. It runs a single icey-server process that opens AVFoundation directly via the `avfoundation:` URL scheme; `Ctrl-C` tears it down:

```bash
make facetime-demo
```

That target wraps `scripts/facetime-demo.sh`. macOS-only because of the avfoundation input. Setup details, including the device permission prompt, the audio capture default, and the speaker default-mute, are documented in `docs/facetime-on-macbook.md`.

### 5. Validate Packaging Or Release Changes

For staged app layout changes:

```bash
make install
```

For release metadata only:

```bash
make release-metadata-check
```

For the full package-manager cutover contract:

```bash
make package-managers
```

This must validate Linux tar/zip archives, Debian package contents, APT repo archive, Homebrew formula, AUR PKGBUILD, Nix expression, SHA256SUMS, and Windows-facing manifests only when real Windows artifacts exist.

### 6. Report Results

A useful agent result should report:

- changed surfaces
- commands run
- whether `ICEY_VERSION` was relevant
- browser engine used for smoke validation
- package artifacts validated, if any
- runtime mode tested: `stream`, `record`, `relay`, TURN, RTSP, or TLS
- any skipped validation and the concrete reason

Do not collapse failures into generic language. If a check fails, preserve the exact command, exit behavior, and likely surface.

## Expected Outputs

For implementation work, produce a concise change summary plus validation evidence. For operator help, produce an ordered bring-up path with the first command the operator should run next. For packaging or release work, name every artifact family affected.

## Optional Compatible Tooling Note

This file is a portable `SKILL.md`. Agents and tools that understand `SKILL.md` can use it as repo workflow context. runx can optionally pair it with a registry binding for execution, verification, and receipts, but this repo does not require runx to use the file.

