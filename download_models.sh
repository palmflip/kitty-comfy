#!/bin/bash
# Downloads all models needed for kitty-comfy to /workspace/models
# Runs on first pod start if models are missing.
# HF_TOKEN env var required for gated models (set in RunPod template).
set -e

M=/workspace/models
LOG=/workspace/download.log
HF=https://huggingface.co

mkdir -p \
  $M/unet/flux \
  $M/text_encoders \
  $M/vae \
  $M/checkpoints \
  $M/loras/anna_tatsii \
  $M/upscale_models

echo "=== Model download started $(date) ===" | tee -a $LOG

dl() {
  local url=$1 out=$2
  if [ -f "$out" ]; then
    echo "SKIP (exists): $out" | tee -a $LOG
    return 0
  fi
  echo "-> $(basename $out)" | tee -a $LOG
  curl -L --fail --retry 5 --retry-delay 10 -C - \
    ${HF_TOKEN:+-H "Authorization: Bearer $HF_TOKEN"} \
    -o "$out" "$url" >> $LOG 2>&1 \
    && echo "OK: $out" | tee -a $LOG \
    || echo "FAIL: $out" | tee -a $LOG
}

# ── Klein 9B UNET ───────────────────────────────────────────────────────────
dl "$HF/black-forest-labs/FLUX.2-klein-9b-fp8/resolve/main/flux-2-klein-9b-fp8.safetensors" \
   $M/unet/flux/flux-2-klein-9b-fp8.safetensors &

# ── Text encoder (Qwen3 8B FP8) ─────────────────────────────────────────────
dl "$HF/Comfy-Org/vae-text-encorder-for-flux-klein-9b/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors" \
   $M/text_encoders/qwen_3_8b_fp8mixed.safetensors &

# ── VAE ─────────────────────────────────────────────────────────────────────
dl "$HF/Comfy-Org/vae-text-encorder-for-flux-klein-9b/resolve/main/split_files/vae/flux2-vae.safetensors" \
   $M/vae/flux2_vae.safetensors &

# ── SUPIR upscaler ───────────────────────────────────────────────────────────
dl "$HF/Kijai/SUPIR_pruned/resolve/main/SUPIR-v0Q_fp16.safetensors" \
   $M/checkpoints/SUPIR-v0Q_fp16.safetensors &

# ── SDXL base (SUPIR needs it for CLIP+VAE) ─────────────────────────────────
dl "$HF/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" \
   $M/checkpoints/sd_xl_base_1.0.safetensors &

# ── 4x upscale model ────────────────────────────────────────────────────────
dl "$HF/Phips/4xRealWebPhoto_v4_dat2/resolve/main/4xRealWebPhoto_v4.pth" \
   $M/upscale_models/4xRealWebPhoto_v4.pth &

wait
echo "=== Model download finished $(date) ===" | tee -a $LOG

# ── LoRA (personal, must be uploaded manually) ──────────────────────────────
# Place anna_tatsii_klein9b_v4_5000.safetensors at:
# /workspace/models/loras/anna_tatsii/anna_tatsii_klein9b_v4_5000.safetensors
if [ ! -f "$M/loras/anna_tatsii/anna_tatsii_klein9b_v4_5000.safetensors" ]; then
  echo "WARNING: LoRA not found. Upload it manually to $M/loras/anna_tatsii/" | tee -a $LOG
fi
