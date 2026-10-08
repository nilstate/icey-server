# icey-server

[Project homepage](https://0state.com/icey)

Single C++ binary: WebRTC media streaming + Symple signalling + TURN relay + web UI.

Icey Server is the runnable product built on the [Icey C++ library](https://github.com/nilstate/icey).
The executable, release archives, container image, and package listings use
the `icey-server` name.

No Node.js runtime, no third-party services. One binary, two ports (HTTP/WS + TURN).

## icey Demo

If you need the shortest end-to-end path, use the [Docker demo path](docker/README.md):

```bash
docker run --rm --network host 0state/icey-server:latest
```

Then open `http://localhost:4500` and click `Watch` on the `icey` peer.

That is the express path. For the source-backed path, use the local `docker/` directory in this repo or build `icey-server` natively against an `icey` source tree.

## Native Quick Start

```bash
# Build the C++ server
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DICEY_SOURCE_DIR=/path/to/icey
cmake --build build --target icey-server

# Build the web UI
cd web
npm install
npm run build

# Run
./build/src/server/icey-server --web-root web/dist --source /path/to/video.mp4
```

Open `http://localhost:4500` in a browser.

Validated browser smoke:
- Chromium engine via Playwright using the system Google Chrome binary
- Firefox via Playwright

WebKit smoke is wired in the test harness, but the Playwright WebKit/WPE runtime on this Linux host is not treated as authoritative for publish-path support. Do not claim Safari support until it has been validated on Apple platforms.

The `icey-server` target is built when the `webrtc` prerequisites are available: OpenSSL and FFmpeg must be installed or discoverable by CMake, and libdatachannel is fetched automatically.

For a machine-readable preflight before startup, run:

```bash
./build/src/server/icey-server --doctor
```

## Repo Workflow

```bash
# Configure and build with the sibling icey checkout
cmake --preset dev
cmake --build --preset dev

# Or use the thin wrappers
make configure
make build
make web-install
make web-build
make install
make package
make package-deb
make package-apt
make package-managers
make release-metadata-check
make release-check
```

`make install` stages the distributable layout under `.stage/`, and `make package`
emits versioned `.tar.gz` and `.zip` artifacts from the staged app layout.

## Package Managers

The repo now includes packaging inputs for every first-class package manager
surface:

- Homebrew
- AUR
- Debian / APT
- Nix
- winget
- Scoop
- Chocolatey

The tracked templates live under [packaging/](packaging/README.md), and the local rendered outputs are generated into `.stage/package-managers/rendered/`.

The exact `icey` dependency release is pinned in [ICEY_VERSION](ICEY_VERSION). Release and CI jobs now build against that exact tag instead of a floating checkout.

Use:

```bash
make package-managers
```

If the AUR SSH edge is not reachable from GitHub Actions, the local fallback is:

```bash
make publish-aur AUR_REPO_DIR=/path/to/aur-icey-server
```

That generates and validates:

- `icey-server-<version>-source.tar.gz`
- `icey-<version>-source.tar.gz`
- `icey-server-<version>-Linux-x86_64.tar.gz`
- `icey-server-<version>-Linux-x86_64.zip`
- `icey-server_<version>_amd64.deb`
- `icey-server-apt-repo-<version>.tar.gz`
- rendered manifests for Homebrew, AUR, Debian/APT, and Nix
- Windows-facing manifests only when a real Windows release archive exists

## Canonical RTSP Path

The launch wedge is `RTSP -> browser`.

The repo ships a ready-to-edit example at `config.rtsp.example.json`:

```bash
cp config.rtsp.example.json config.local.json
$EDITOR config.local.json
./build/src/server/icey-server --config config.local.json --doctor
./build/src/server/icey-server --config config.local.json
```

The installed layout also ships both `config.example.json` and
`config.rtsp.example.json` under `share/icey-server/`.

## Modes

- **stream** (default): server pushes file/camera to browser via WebRTC (H.264 + Opus)
- **record**: browser sends H.264 video to the server, which decodes it and writes MP4 files to disk
- **relay**: the first active caller becomes the live source; later callers receive that source via server-side encoded relay fanout

## Mode Behavior

| Mode | Browser sends | Server sends | Notes |
| --- | --- | --- | --- |
| `stream` | call control | H.264 + Opus | source comes from the local file or device configured with `--source` |
| `record` | H.264 video | call control | output goes to timestamped MP4 files under `--record-dir` |
| `relay` | one active source call | encoded media to viewers | first active caller becomes source; later callers become viewers |

## Features

- **Video + Audio**: H.264 Constrained Baseline (browser-safe) + Opus at 48kHz
- **Embedded TURN**: RFC 5766 relay on port 3478 — works through symmetric NATs
- **Adaptive bitrate**: REMB feedback adjusts encoder bitrate in real-time
- **Per-session isolation**: each peer gets its own capture/encoder pipeline in stream mode and its own recorder pipeline in record mode
- **Server-side relay**: relay mode forwards one active browser source to all connected viewers without decoding/re-encoding
- **Server-side recording**: record mode writes timestamped MP4 files under `--record-dir`
- **Zero latency**: `ultrafast` preset + `zerolatency` tune for real-time H.264

## CLI options

```text
icey-server [options]
  -c, --config <path>     Config file (default: ./config.json)
  --host <host>           Bind host (default from config)
  --port <port>           HTTP/WS port (default: 4500)
  --tls-cert <path>       TLS certificate for direct HTTPS/WSS serving
  --tls-key <path>        TLS private key for direct HTTPS/WSS serving
  --turn-port <port>      TURN port (default: 3478)
  --turn-external-ip <ip> Public IP advertised by TURN
  --mode <mode>           stream|record|relay
  --source <path-or-url>  Media source file, device, or RTSP URL
  --record-dir <path>     Output directory for record mode (default: ./recordings)
  --web-root <path>       Path to web UI dist/ directory (packaged installs auto-fallback to share/icey-server/web)
  --log-level <level>     trace|debug|info|warn|error (default: info)
  --loop                  Enable looping in stream mode
  --no-loop               Disable looping in stream mode
  --no-turn               Disable embedded TURN server
  --doctor                Print preflight diagnostics and exit
  --version               Print version and exit
  -h, --help              Show this help and exit
```

## Browser Counterpart

The intended counterpart is the bundled web UI. It handles:

- Symple presence and discovery
- call placement
- SDP and ICE transport
- playback or source publishing depending on mode

If the browser cannot even see the server peer, you have a signalling problem, not a media problem.

## Operator Endpoints

- `GET /api/health` returns a basic liveness payload
- `GET /api/ready` returns preflight readiness and reports `503` when the runtime is not ready to serve
- `GET /api/status` returns readiness, mode, version, peer identity, session counts, `uptimeSec`, and intelligence state
- `GET /api/config` returns browser-facing ICE/TURN config plus runtime mode/version

The binary also now supports `--help`, `--version`, and `--doctor`, and exposes `--host`, `--turn-external-ip`, `--loop`, and `--no-loop` for operator bring-up without editing JSON first.

## Configuration

Settings resolve with the precedence `built-in defaults < config file < environment variables < CLI flags`. Every general setting is reachable without a config file:

| Setting | Config key | Environment | Flag |
|---|---|---|---|
| Config file path | — | `ICEY_CONFIG` | `-c, --config` |
| Bind host | `http.host` | `ICEY_HOST` | `--host` |
| HTTP/WS port | `http.port` | `ICEY_PORT` | `--port` |
| TURN port | `turn.port` | `ICEY_TURN_PORT` | `--turn-port` |
| TURN external IP | `turn.externalIp` | `ICEY_TURN_EXTERNAL_IP` | `--turn-external-ip` |
| TURN enabled | `turn.enabled` | `ICEY_TURN` (true/false) | `--no-turn` |
| Mode | `media.mode` | `ICEY_MODE` | `--mode` |
| Source | `media.source` | `ICEY_SOURCE` | `--source` |
| Record dir | `media.recordDir` | `ICEY_RECORD_DIR` | `--record-dir` |
| Loop | `media.loop` | `ICEY_LOOP` (true/false/auto) | `--loop` / `--no-loop` |
| Web root | `webRoot` | `ICEY_WEB_ROOT` | `--web-root` |
| TLS cert / key | `tls.cert` / `tls.key` | `ICEY_TLS_CERT` / `ICEY_TLS_KEY` | `--tls-cert` / `--tls-key` |
| Log level | — | `ICEY_LOG_LEVEL` | `--log-level` |
| API/WS auth token | `auth.token` | `ICEY_AUTH_TOKEN` | — |
| TURN HMAC secret | `turn.secret` | `ICEY_TURN_SECRET` | — |

Secrets (`ICEY_AUTH_TOKEN`, `ICEY_TURN_SECRET`) are environment-or-file only by design so they never appear in process listings. Unknown config keys produce startup warnings, out-of-range ports and invalid modes are rejected, and an explicitly passed `--config` path that does not exist is an error rather than a silent fall-back to defaults.

When `auth.token` is set, the HTTP API (everything except `/api/health`), WebSocket signalling, and `/artifacts/` downloads (recordings, snapshots, clips) all require it — via `Authorization: Bearer`, `X-Icey-Token`, or a `token` query parameter for plain links.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | success (or `--doctor` ready) |
| 1 | runtime failure (or `--doctor` not ready) |
| 2 | usage error (bad flag or value) |
| 3 | config error (missing or invalid config file) |
| 4 | startup preflight failure (including port conflicts) |

## Web UI development

```bash
cd web
npm run dev
```

Vite dev server runs on port 5173 and proxies `/ws` and `/api` to the C++ server on port 4500. Run both in parallel for hot-reload development.

## Bring-Up Order

If you are bringing the full stack up from scratch, do it in this order:

1. `stream` mode with a local source file and `--no-turn`
2. `record` mode
3. `relay` mode
4. TURN-enabled external/NAT testing

That keeps signalling, send path, receive path, relay, and public addressing problems separated instead of mixing them together on day one.

## Architecture

```text
Browser ─── WSS /ws ──── Symple v4 (signalling, presence, rooms)
        ─── GET /   ──── Static files (Vite build output)
        ─── GET /api ─── REST status
        ─── WebRTC  ──── Media (stream: H.264 + Opus out, record: H.264 in, relay: one browser in -> many browsers out)
        ─── TURN    ──── NAT traversal (embedded, port 3478)
```

## Dependencies

All existing icey modules:

```text
icey-server
├── webrtc (libdatachannel, track, mediabridge)
├── symple (server, protocol)
├── turn (server, allocations)
├── av (MediaCapture, VideoPacketEncoder, AudioPacketEncoder)
├── http (Server, WebSocket)
├── stun (STUN message parsing)
├── net, crypto, json, base
```

Frontend: `symple-client` + `symple-player` (npm, bundled with Vite).

## License

`icey-server` is licensed under `AGPL-3.0-or-later`. Commercial licensing is
available from 0state; see [LICENSE.md](LICENSE.md).

## See Also

- [icey source-to-browser stack recipe](https://github.com/nilstate/icey/blob/main/docs/recipes/media-server-stack.md)
- [icey WebRTC guide](https://github.com/nilstate/icey/blob/main/docs/modules/webrtc.md)
- [icey TURN guide](https://github.com/nilstate/icey/blob/main/docs/modules/turn.md)
