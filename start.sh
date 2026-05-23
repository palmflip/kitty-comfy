#!/bin/bash
set -e

mkdir -p /workspace/user/default/workflows
mkdir -p /workspace/output
mkdir -p /workspace/input
mkdir -p /workspace/models/{checkpoints,loras/anna_tatsii,vae,unet/flux,text_encoders,upscale_models,controlnet,clip_vision,embeddings}
mkdir -p /workspace/.cache/huggingface

# Download models on first start if missing
if [ ! -f /workspace/models/unet/flux/flux-2-klein-9b-fp8.safetensors ]; then
    echo "First start — downloading models in background (tail -f /workspace/download.log)"
    bash /opt/comfyui/download_models.sh &
fi

# Link output/input/user to workspace volume
rm -rf /opt/comfyui/output /opt/comfyui/input /opt/comfyui/user
ln -sfn /workspace/output /opt/comfyui/output
ln -sfn /workspace/input  /opt/comfyui/input
ln -sfn /workspace/user   /opt/comfyui/user

exec python3 main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --preview-method auto \
    --enable-cors-header
