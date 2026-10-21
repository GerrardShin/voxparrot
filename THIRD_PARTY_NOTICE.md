# Third-party notices

## Model: NVIDIA Parakeet TDT 0.6B v3
- Source: https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3
- sherpa-onnx conversion used by the backend:
  https://github.com/k2-fsa/sherpa-onnx/releases (asr-models)
- License: **CC-BY 4.0** — https://creativecommons.org/licenses/by/4.0/
- Changes made: converted to ONNX and quantized to int8 by the sherpa-onnx
  project; no changes to the model architecture.
- **If you ship a game using this model, keep this attribution in your
  game's credits / notices.** CC-BY attribution travels with the model.

## Runtime: sherpa-onnx
- https://github.com/k2-fsa/sherpa-onnx — Apache-2.0

## Inspiration / related model family
- Underdog Bark 3.0 (Conway Research) is built on parakeet-tdt-0.6b-v3
  (NVIDIA) and parakeet-ultra (Moondream), both CC-BY 4.0:
  https://underdog.ai/bark — Bark 3.0 weights themselves are not used here.

## Engine
- Godot Engine — MIT. This is a community addon, not an official Godot product.
