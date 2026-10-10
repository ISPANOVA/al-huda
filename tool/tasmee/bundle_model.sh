#!/usr/bin/env bash
# Puts the Tasmee model in assets/tasmee/ before the app is built: from the
# public release of ISPANOVA/al-huda-files, checked against its SHA-256.
# Quran-Lab/zipformer_p-arabic-v3.1 (NPL-1.2: free apps only).
set -euo pipefail
OUT="${1:-assets/tasmee}"
SRC=https://github.com/ISPANOVA/al-huda-files/releases/download/tasmee-model-v3.1
mkdir -p "$OUT"
curl -sSfL --retry 4 -o "$OUT/model.int8.onnx" "$SRC/model.int8.onnx"
curl -sSfL --retry 4 -o "$OUT/tokens.txt" "$SRC/tokens.txt"
cd "$OUT"
sha256sum -c - <<'SUMS'
31755836528da336a6192121cd7bc82cb41752dddb65566fd000b89c8686da6b  model.int8.onnx
252c10687e442aa9291973065fae19fa39bcd681c4f5612ec496a647e20b43a1  tokens.txt
SUMS
