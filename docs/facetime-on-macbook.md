# FaceTime Camera to Browser on a MacBook

Your MacBook's FaceTime camera, in a browser tab. The pipeline is native end to end: AVFoundation on the camera side, a single Mach-O binary in the middle, the browser on the other end. No Docker, no Electron, no Python sidecar, no third-party media services. Motion regions drawn over the video as it moves, a voice-activity meter when someone speaks, a real buffer-delay number ticking in the corner.

If "FaceTime camera" sounds wrong on your machine, that's because Apple has been quietly dropping the FaceTime branding from new MacBook Pros. macOS Settings still calls it "FaceTime HD Camera". `ffmpeg -f avfoundation -list_devices` calls it "MacBook Pro Camera" on M-series. Same hardware. Instructions below work either way.

The pipeline is one process:

```text
FaceTime camera ── icey-server (avfoundation: URL) ──► browser
```

icey-server's `MediaCapture::openFile()` recognises libavdevice URL schemes (`avfoundation:`, `v4l2:`, `dshow:`) and opens the OS camera directly via libavformat's matching input. No relay binary, no RTSP intermediary.

## TL;DR

```bash
brew install cmake pkg-config openssl@3 ffmpeg
git clone https://github.com/nilstate/icey
git clone https://github.com/nilstate/icey-server
cd icey-server
cmake --preset dev && cmake --build --preset dev
(cd web && npm install && npm run build)
make facetime-demo
# open http://localhost:4500/  and click Watch
```

That's it. The rest of this page explains why each step exists, the macOS-specific bear-traps that will bite you, and how to verify it actually works.

## Prerequisites

```bash
brew install cmake pkg-config openssl@3 ffmpeg
```

`cmake` and `pkg-config` to configure the build. `openssl@3` for TLS and DTLS. `ffmpeg` provides the libraries icey links against (`libavformat`, `libavcodec`, `libavdevice`, `libavutil`, `libswscale`, `libswresample`); the `avfoundation` backend is built into Homebrew's libavdevice on macOS, which is what the `avfoundation:` URL scheme dispatches to.

Node 20+ for the web UI build.

## Source layout

icey-server expects a sibling `icey` source tree. The CMake preset hard-codes `${sourceDir}/../icey`:

```bash
cd ~/dev/0state
git clone https://github.com/nilstate/icey
git clone https://github.com/nilstate/icey-server
```

You should now have:

```text
~/dev/0state/
  icey/
  icey-server/
```

If you put them somewhere else, override `ICEY_SOURCE_DIR` when configuring.

## Build the server

From the `icey-server` directory:

```bash
cmake --preset dev
cmake --build --preset dev
```

The output binary lands at `build-dev/src/server/icey-server`. On macOS arm64 it should be `Mach-O 64-bit executable arm64`:

```bash
file build-dev/src/server/icey-server
```

## Build the web UI

```bash
cd web
npm install
npm run build
cd ..
```

Output goes to `web/dist/`. `icey-server` will pick it up via `--web-root web/dist`.

## The fast path: `make facetime-demo`

Once the binary and the web UI are built, the entire stack comes up with one command:

```bash
make facetime-demo
```

This runs `scripts/facetime-demo.sh`, which starts icey-server with the right flags and tears it down on `Ctrl-C`. Open `http://localhost:4500/` and click **Watch** in the side panel.

If you'd rather drive it yourself, the next section walks through what `make facetime-demo` is doing.

## Manual bring-up

### List the camera

```bash
ffmpeg -f avfoundation -list_devices true -i "" 2>&1
```

You should see something like:

```text
[0] MacBook Pro Camera        # or "FaceTime HD Camera" on older Macs
[1] MacBook Pro Desk View Camera
[2] Capture screen 0
[0] MacBook Pro Microphone
```

The first run also triggers macOS to prompt for camera (and microphone, if you're capturing audio) access. Grant it to your terminal app (Terminal, iTerm, Ghostty, etc.) in `System Settings → Privacy & Security`. Until that's granted, the device open fails with `Operation not permitted`.

### Run icey-server

```bash
./build-dev/src/server/icey-server \
  --source 'avfoundation:0:none' \
  --web-root web/dist \
  --no-turn
```

`avfoundation:0:none` is video device 0 (the FaceTime camera) and no audio. Use `0:0` to also capture the built-in mic. On a single-Mac demo, video-only is recommended: the mic would otherwise pick up the laptop speakers playing back the audio and create a feedback loop. The browser-side speaker is default-muted to mitigate this, but headphones or `0:none` are the clean answers.

`--no-turn` skips the embedded TURN server. Not needed for a browser on the same machine. Add it back when you start testing across networks.

Open `http://localhost:4500/` and click **Watch** on the icey peer. Within a second or two, the FaceTime camera lands in the browser tab.

## What you should see

Top-right of the video, the `latency` badge ticks around 5 to 30ms. This is the average time each frame spends in the browser's jitter buffer (post-network, pre-display) — a subset of end-to-end latency, not glass-to-glass. True glass-to-glass via the abs-capture-time RTP extension is in flight upstream and will activate the same badge in a future release.

Top edge of the page, a thin green pulse line flickers per arriving frame. It dims to amber if frames stall.

Bottom-left, a voice-activity ring pulses green and a level meter when icey detects speech in the audio stream (when audio capture is enabled).

On the video itself, green bounding boxes with corner ticks are drawn over moving regions, fading after about 600ms. Driven by icey's motion detector.

Top-right also shows live `fps`, `codec`, and `bitrate`.

The right rail has the peer list, scrolling event timeline, pipeline stats (source fps, sampled fps, vision queue depth, dropped count, vision latency, snapshot and clip counts), and the configured source.

The combination is the differentiator. Plain camera-to-browser is solved. The live intelligence overlays plus a real buffer number plus the single-binary single-process delivery is what you can't get without icey.

## Verify

```bash
curl -s http://localhost:4500/api/health
curl -s http://localhost:4500/api/ready
curl -s http://localhost:4500/api/status | jq
curl -s http://localhost:4500/api/config | jq '.source'
```

`/api/status` reports mode, peer identity, session counts, and intelligence state. `/api/config` reports the configured source, including its kind (`device` for `avfoundation:` / `v4l2:` / `dshow:`). If `ready=false`, run `--doctor` for a preflight diagnostic:

```bash
./build-dev/src/server/icey-server --doctor
```

## Troubleshooting

**Device open fails with `Operation not permitted`.**
Camera (and microphone, if you're capturing audio) permission for the terminal app is missing. macOS won't surface the prompt again until you toggle the permission in `System Settings → Privacy & Security → Camera`.

**`libavdevice input format not available on this build: avfoundation`.**
icey was built without libavdevice linked. Confirm `brew install ffmpeg` succeeded and that the cmake configure log shows `HAVE_FFMPEG_AVDEVICE`. On a clean reconfigure (`cmake --preset dev`), libavdevice is detected if libavformat is, so this usually means a stale build directory; remove `build-dev/` and rebuild.

**Browser plays for a couple of seconds then freezes.**
This was a real bug fixed in icey 2.4.7. `MediaCapture::run` treated `AVERROR(EAGAIN)` from `av_read_frame` as fatal, which AVFoundation returns whenever its internal frame queue is momentarily empty (1s internal timeout). The capture loop would tear itself down at the first hiccup and the browser would see only the initial buffered frames. If you're hitting this on an older build, rebuild against the current source.

**Audio sounds garbled, chipmunky, or wrong-channel.**
icey's audio encoder must call `AudioContext::open()` after `create()` so the resampler is set up. Without it, the source's planar samples get written to the opus encoder's interleaved FIFO and the channels mis-interleave. Fixed in `icey/src/av/src/audiopacketencoder.cpp` from icey 2.4.6 on. Rebuild after applying.

**You hear yourself echoing on the demo.**
The FaceTime mic is capturing the laptop speakers playing back the icey audio. The browser-side speaker is **default-muted** specifically to avoid this. If you've unmuted it, put on headphones, or run video-only with `AUDIO_DEVICE=none` (the demo script's default), or accept the loop. There is no browser-side AEC fix because the mic isn't browser-owned.

**You see the page but clicking the icey peer doesn't start a call.**
Hard-refresh (Cmd+Shift+R). The action button isn't the only target; the entire peer row is clickable.

**The sidebar shows "(no source configured)".**
You're on a build before icey-server 0.2.1. `/api/config` started emitting `source.value` in 0.2.1; older builds left the sidebar empty. Pull and rebuild.

## What's next

Once stream mode is working, walk through the rest of icey's mode matrix in the same shell layout.

1. **record**. Point a browser at a running `icey-server --mode record`, send H.264 from the browser, get timestamped MP4 files under `--record-dir`.
2. **relay**. First browser to call becomes the source. Later callers receive that source via server-side fanout, with no decode/re-encode in the middle.
3. TURN. Drop `--no-turn` and put the server behind a NAT to exercise the embedded RFC 5766 relay on `:3478`.

That ordering keeps signalling, send path, receive path, relay, and public addressing failures separated. Mixing them on day one is how people end up debugging the wrong layer.
