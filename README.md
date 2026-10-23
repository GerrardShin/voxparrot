# VoxParrot

**On-device speech-to-text for game engines — voice chat transcription and voice commands. No cloud. No API key.**

VoxParrot is one engine-agnostic recognition core with thin per-engine
wrappers. The first wrapper is **VoxParrot for Godot** (Godot 4):

Godot has built-in text-to-speech, but no speech-to-text. This addon fixes that:
drop one node into your scene, hold a key, speak, and get text (or a game
command) back — recognized locally by NVIDIA's Parakeet TDT model via
sherpa-onnx, on the player's own machine.

> ⭐ Useful to you? Star the repo — it decides whether the native
> GDExtension version gets built next.

## Why not Whisper / cloud STT?

| | This addon (Parakeet TDT v3, int8) | Whisper large-v3 | Cloud STT APIs |
|---|---|---|---|
| Runs offline | ✅ fully on-device | ✅ | ❌ |
| API key / per-minute cost | none | none | required / billed |
| Model download | ~640 MB | ~9.3 GB (large-v3) | — |
| Word error rate (Open ASR avg) | 4.94% (v3 family, vendor-reported) | 6.04% | varies |
| CPU speed | faster than realtime on 2 cores (measured, see below) | heavy on CPU | network-bound |

Measured in this repo's PoC backend on a 2-core VM (no GPU): 3.8 s clip
decoded in ~1.1 s end-to-end over HTTP (RTF ≈ 0.30). On Apple Silicon,
published sherpa-onnx benchmarks put Parakeet v3 int8 at ~24× realtime.

## Features (v0.1 PoC)

- 🎙️ Push-to-talk microphone capture (`ParakeetVoice` node)
- 🗨️ Voice-chat style transcription — `transcription_received(text, info)` signal
- 🎮 Voice commands — `register_command("end turn", "end_turn")`, get `command_recognized`
- 🌍 25 European languages with automatic detection (the v3 model), incl. English, Spanish, French, German
- 🔒 Private by design: audio never leaves the player's machine
- 🧩 Engine-agnostic core: the recognizer backend is a small localhost
  service speaking plain HTTP/JSON, so Unity and Unreal wrappers can share
  it (roadmap below)


## Repository layout

- `core/` — the engine-agnostic recognizer: a small localhost service
  speaking plain HTTP/JSON (sherpa-onnx + Parakeet TDT). Every engine
  wrapper talks to this same contract.
- `engines/godot/` — **VoxParrot for Godot**: the Godot 4 addon
  (`addons/godot_parakeet`) and a demo project (`examples/voice_demo`).
- `engines/unity/`, `engines/unreal/` — planned wrappers on the same core.

## Quick start

1. **Backend** (dev machine / shipped as a sidecar for now):
   ```bash
   cd core
   pip install -r requirements.txt
   ./download_model.sh          # ~640 MB, CC-BY 4.0 model, not in this repo
   python3 server.py --model-dir models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8
   ```
2. **Godot**: copy `engines/godot/addons/godot_parakeet` into your project's `addons/`,
   enable the plugin, add a `ParakeetVoice` node.
3. **Use it** (3 lines):
   ```gdscript
   $ParakeetVoice.register_command("end turn", "end_turn")
   $ParakeetVoice.command_recognized.connect(func(cmd, _text): print("voice command: ", cmd))
   # hold/release a key -> start_recording() / stop_recording_and_transcribe()
   ```

Demo: `engines/godot/examples/voice_demo` — windowed push-to-talk demo plus a headless
end-to-end test (`run_demo.sh sample.wav` prints the transcript from inside
Godot).

## Languages & Korean

Parakeet TDT v3 covers 25 European languages — **not** Korean/Japanese/
Chinese. Because the backend is sherpa-onnx, other models plug into the same
API: a SenseVoice preset (zh/en/ja/**ko**/yue) is planned as a selectable
model profile, which is also how VoxParrot avoids being an English-only tool.

## Roadmap

- [ ] Native GDExtension backend (sherpa-onnx C API) — no Python sidecar in exports
- [ ] In-editor model downloader (models stay out of the addon package)
- [ ] SenseVoice preset for Korean/Japanese/Chinese
- [ ] Streaming partial transcripts + VAD endpointing (Silero)
- [ ] Unity wrapper (same backend contract)
- [ ] Unreal wrapper (same backend contract)
- [ ] Android export support

## The 163 MB question

This project started from Underdog's Bark 3.0 announcement (163 MB,
Whisper-beating). Bark 3.0's own weights are distributed inside their app and
were **not** publicly downloadable as of 2026-10-22, so VoxParrot targets
its open base model — Parakeet TDT 0.6B v3 — in int8 form (~640 MB). If/when
a Bark-class distilled model ships openly, it drops into the same backend.

## Licenses

- **This project's code: MIT** (see `LICENSE`).
- **Model weights: CC-BY 4.0** (NVIDIA Parakeet TDT; sherpa-onnx conversion).
  Attribution is required, including in games you ship with the model —
  see `THIRD_PARTY_NOTICE.md`. Models are downloaded separately and are
  never bundled in this repo or the Asset Library package.
- Runtime: sherpa-onnx (Apache-2.0), ONNX Runtime (MIT).

Not affiliated with NVIDIA, k2-fsa, or Underdog/Conway. "Parakeet" names
the underlying model family; "VoxParrot" is this project's own brand.
