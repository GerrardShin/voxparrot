#!/usr/bin/env bash
# Download the default model: NVIDIA Parakeet TDT 0.6B v3 (int8, sherpa-onnx build).
# ~640 MB total. The model is CC-BY 4.0 (NVIDIA) — see THIRD_PARTY_NOTICE.md.
# It is downloaded separately and is NOT part of this repository.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p models
cd models
FILE="sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8"
if [ ! -d "$FILE" ]; then
  wget -c "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${FILE}.tar.bz2"
  tar xjf "${FILE}.tar.bz2"
  rm "${FILE}.tar.bz2"
fi
echo "Model ready: models/${FILE}"
