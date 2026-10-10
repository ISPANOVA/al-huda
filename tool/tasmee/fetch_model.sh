#!/usr/bin/env bash
# Downloads the Tasmee model (Quran-Lab/zipformer_p-arabic-v3, NPL licence,
# gated on Hugging Face: the account behind HF_TOKEN accepted its terms) into
# assets/tasmee/. Without HF_TOKEN nothing is downloaded and the app keeps
# the device's speech recognition for the Tasmee.
set -euo pipefail
OUT="${1:-assets/tasmee}"
REPO="Quran-Lab/zipformer_p-arabic-v3"
if [ -z "${HF_TOKEN:-}" ]; then
  echo "::warning::HF_TOKEN is not set: the Tasmee model is not bundled."
  exit 0
fi
H="Authorization: Bearer $HF_TOKEN"
TREE=$(curl -sSf -H "$H" "https://huggingface.co/api/models/$REPO/tree/main?recursive=true") || {
  echo "::error::Cannot list $REPO (accept the model's terms on Hugging Face with the account of HF_TOKEN)."
  exit 1
}
FILES=$(python3 -c 'import json,sys; print("\n".join(f["path"] for f in json.loads(sys.stdin.read()) if f.get("type")=="file"))' <<<"$TREE")
echo "$FILES" | grep -Ei "onnx|tokens" || true
# TASMEE_MODEL: v3 (default) or v3.1; each with its own tokens.
case "${TASMEE_MODEL:-v3}" in
  v3.1) MODEL=$(echo "$FILES" | grep -xE 'zipformer_p_arabic_v3\.1\.int8\.onnx' | head -1)
        TOKENS=$(echo "$FILES" | grep -xE 'sdk/v3\.1/tokens\.txt' | head -1) ;;
  *)    MODEL=$(echo "$FILES" | grep -xE 'zipformer_p_arabic_v3\.int8\.onnx' | head -1)
        TOKENS=$(echo "$FILES" | grep -xE 'tokens\.txt' | head -1) ;;
esac
if [ -z "$MODEL" ] || [ -z "$TOKENS" ]; then
  echo "::error::Model files not found in $REPO"
  exit 1
fi
echo "model: $MODEL  tokens: $TOKENS"
mkdir -p "$OUT"
curl -sSfL -H "$H" -o "$OUT/model.int8.onnx" "https://huggingface.co/$REPO/resolve/main/$MODEL"
curl -sSfL -H "$H" -o "$OUT/tokens.txt" "https://huggingface.co/$REPO/resolve/main/$TOKENS"
ls -la "$OUT"
