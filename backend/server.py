#!/usr/bin/env python3
"""godot-parakeet PoC backend — engine-agnostic STT sidecar.

Serves on-device speech-to-text over localhost HTTP so any game engine
(Godot today, Unity/Unreal next) can use the same core:

    POST /transcribe   body: WAV bytes  ->  {"text": ..., "audio_sec": ..., "decode_sec": ..., "rtf": ...}
    GET  /health       -> {"status": "ok", "model": ...}

Engine-agnostic by design: the recognizer (sherpa-onnx + Parakeet TDT)
knows nothing about Godot. Engine wrappers are thin clients of this API
until the native GDExtension (roadmap) replaces the sidecar in exported
builds.

Usage:
    python3 server.py --model-dir ./models/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8 --port 8765
"""
import argparse
import io
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import soundfile as sf
import sherpa_onnx

RECOGNIZER = None
MODEL_NAME = ""


def load_recognizer(model_dir: str, threads: int):
    global RECOGNIZER, MODEL_NAME
    MODEL_NAME = model_dir.rstrip("/").split("/")[-1]
    t0 = time.time()
    RECOGNIZER = sherpa_onnx.OfflineRecognizer.from_transducer(
        encoder=f"{model_dir}/encoder.int8.onnx",
        decoder=f"{model_dir}/decoder.int8.onnx",
        joiner=f"{model_dir}/joiner.int8.onnx",
        tokens=f"{model_dir}/tokens.txt",
        num_threads=threads,
        model_type="nemo_transducer",
        debug=False,
    )
    print(f"[godot-parakeet] model loaded in {time.time() - t0:.2f}s: {MODEL_NAME}", flush=True)
    # Warmup so the first real request is not the slow one.
    import numpy as np

    stream = RECOGNIZER.create_stream()
    stream.accept_waveform(16000, np.zeros(16000, dtype="float32"))
    RECOGNIZER.decode_stream(stream)
    print("[godot-parakeet] warmup done", flush=True)


def transcribe(wav_bytes: bytes) -> dict:
    audio, sr = sf.read(io.BytesIO(wav_bytes), dtype="float32", always_2d=False)
    if audio.ndim > 1:
        audio = audio[:, 0]
    dur = len(audio) / sr
    stream = RECOGNIZER.create_stream()
    stream.accept_waveform(sr, audio)
    t0 = time.time()
    RECOGNIZER.decode_stream(stream)
    elapsed = time.time() - t0
    return {
        "text": stream.result.text,
        "audio_sec": round(dur, 3),
        "decode_sec": round(elapsed, 3),
        "rtf": round(elapsed / dur, 3) if dur > 0 else None,
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):  # keep stdout clean
        pass

    def do_GET(self):
        if self.path == "/health":
            self._json(200, {"status": "ok", "model": MODEL_NAME})
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/transcribe":
            self._json(404, {"error": "not found"})
            return
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        try:
            self._json(200, transcribe(body))
        except Exception as e:  # surface decode errors to the engine client
            self._json(400, {"error": str(e)})

    def _json(self, code, payload):
        data = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", required=True)
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--threads", type=int, default=4)
    args = ap.parse_args()
    load_recognizer(args.model_dir, args.threads)
    print(f"[godot-parakeet] listening on http://127.0.0.1:{args.port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
