#!/bin/bash
# kitty-comfy bootstrap
# Run: bash <(curl -sSL https://raw.githubusercontent.com/palmflip/kitty-comfy/main/bootstrap.sh)
set -e

COMFY=/workspace/ComfyUI
M=/workspace/models
LOG=/workspace/bootstrap.log
REPO=https://raw.githubusercontent.com/palmflip/kitty-comfy/main

export UV_CACHE_DIR=/workspace/.cache/uv

echo "=== kitty-comfy bootstrap $(date) ===" | tee $LOG

# ── SSH (docker-args bypasses RunPod entrypoint, sshd never starts) ──────────
apt-get install -y openssh-server -qq 2>/dev/null || true
ssh-keygen -A 2>/dev/null || true
mkdir -p /root/.ssh && chmod 700 /root/.ssh
[ -n "$PUBLIC_KEY" ] && echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
service ssh start 2>/dev/null || true
echo "SSH started" | tee -a $LOG

# ── Detect torch & CUDA ──────────────────────────────────────────────────────
TORCH_VER=$(python3 -c "import torch; print(torch.__version__.split('+')[0])")
CUDA_TAG=$(python3 -c "import torch; v=torch.version.cuda or '12.4'; v=v.replace('.',''); print('cu'+v[:3])")
echo "torch: $TORCH_VER  cuda: $CUDA_TAG" | tee -a $LOG

# ── uv ───────────────────────────────────────────────────────────────────────
if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="/root/.local/bin:$PATH"
mkdir -p $UV_CACHE_DIR

# ── Model dirs (created early so background downloads can write into them) ───
mkdir -p \
    $M/checkpoints $M/loras/anna_tatsii $M/vae \
    $M/unet/flux $M/text_encoders $M/upscale_models \
    $M/controlnet $M/clip_vision $M/embeddings \
    $M/ultralytics/bbox $M/ultralytics/segm \
    /workspace/output /workspace/input \
    /workspace/user/default/workflows

# ── dl helper (defined early so we can kick off model downloads in the bg) ──
HF=https://huggingface.co
dl() {
    local url=$1 out=$2
    [ -f "$out" ] && { echo "SKIP: $(basename $out)" | tee -a $LOG; return; }
    echo "-> $(basename $out)" | tee -a $LOG
    curl -L --fail --retry 3 -C - \
        ${HF_TOKEN:+-H "Authorization: Bearer $HF_TOKEN"} \
        -o "$out" "$url" >> $LOG 2>&1 \
        && echo "OK: $(basename $out)" | tee -a $LOG \
        || echo "FAIL: $(basename $out)" | tee -a $LOG
}

# ── Kick off model downloads NOW in the background ───────────────────────────
# Network-bound — runs in parallel with pip/git work below (CPU/disk bound),
# saving ~5-7 min on cold start where previously model downloads only began
# after all pip installs + custom node clones finished.
echo "=== kicking off background model downloads ===" | tee -a $LOG
dl "$HF/black-forest-labs/FLUX.2-klein-9b-fp8/resolve/main/flux-2-klein-9b-fp8.safetensors" \
   $M/unet/flux/flux-2-klein-9b-fp8.safetensors &
dl "$HF/Comfy-Org/vae-text-encorder-for-flux-klein-9b/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors" \
   $M/text_encoders/qwen_3_8b_fp8mixed.safetensors &
dl "$HF/Comfy-Org/vae-text-encorder-for-flux-klein-9b/resolve/main/split_files/vae/flux2-vae.safetensors" \
   $M/vae/flux2_vae.safetensors &
dl "$HF/Kijai/SUPIR_pruned/resolve/main/SUPIR-v0Q_fp16.safetensors" \
   $M/checkpoints/SUPIR-v0Q_fp16.safetensors &
dl "$HF/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" \
   $M/checkpoints/sd_xl_base_1.0.safetensors &
dl "$HF/Phips/4xRealWebPhoto_v4_dat2/resolve/main/4xRealWebPhoto_v4.pth" \
   $M/upscale_models/4xRealWebPhoto_v4.pth &
dl "$HF/Bingsu/adetailer/resolve/main/face_yolov8m.pt" \
   $M/ultralytics/bbox/face_yolov8m.pt &
dl "$HF/Bingsu/adetailer/resolve/main/face_yolov8n.pt" \
   $M/ultralytics/bbox/face_yolov8n.pt &
dl "$HF/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt" \
   $M/ultralytics/segm/person_yolov8m-seg.pt &

# ── Clone or update ComfyUI ──────────────────────────────────────────────────
if [ ! -d "$COMFY/.git" ]; then
    echo "Cloning ComfyUI..." | tee -a $LOG
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI $COMFY
else
    echo "ComfyUI exists, updating..." | tee -a $LOG
    git -C $COMFY pull --ff-only 2>/dev/null || true
fi

# ── ComfyUI deps ─────────────────────────────────────────────────────────────
uv pip install --system -q -r $COMFY/requirements.txt 2>&1 | tail -2 | tee -a $LOG

# ── Custom nodes ──────────────────────────────────────────────────────────────
mkdir -p $COMFY/custom_nodes
cd $COMFY/custom_nodes

REPOS=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/city96/ComfyUI-GGUF"
    "https://github.com/kijai/ComfyUI-SUPIR"
    "https://github.com/ltdrdata/ComfyUI-Inspire-Pack"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/cubiq/ComfyUI_essentials"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/melMass/comfy_mtb"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
    "https://github.com/adieyal/comfyui-dynamicprompts"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/ClownsharkBatwing/RES4LYF"
    "https://github.com/scraed/LanPaint"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
)

for repo in "${REPOS[@]}"; do
    dir=$(basename $repo)
    if [ ! -d "$dir/.git" ]; then
        echo "Cloning $dir..." | tee -a $LOG
        git clone --depth 1 "$repo" "$dir" 2>/dev/null || echo "WARN: failed $repo" | tee -a $LOG
    fi
done

# kitty-prompt-builder (from this repo)
if [ ! -d "kitty-prompt-builder" ]; then
    echo "Installing kitty-prompt-builder..." | tee -a $LOG
    mkdir -p kitty-prompt-builder/workflows
    curl -sSL $REPO/custom_nodes/kitty-prompt-builder/__init__.py \
         -o kitty-prompt-builder/__init__.py
    curl -sSL $REPO/custom_nodes/kitty-prompt-builder/logic.py \
         -o kitty-prompt-builder/logic.py
    curl -sSL $REPO/custom_nodes/kitty-prompt-builder/workflows/klein9b_anna.json \
         -o kitty-prompt-builder/workflows/klein9b_anna.json
fi

# ── Impact subpack (UltralyticsDetectorProvider) ─────────────────────────────
if [ ! -d "$COMFY/custom_nodes/comfyui-impact-subpack/.git" ]; then
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Subpack \
        $COMFY/custom_nodes/comfyui-impact-subpack 2>&1 | tail -1 | tee -a $LOG
fi

# ── Custom node requirements ──────────────────────────────────────────────────
for req in $COMFY/custom_nodes/*/requirements.txt; do
    uv pip install --system -q -r "$req" 2>/dev/null || true
done

# ── Extra packages ────────────────────────────────────────────────────────────
uv pip install --system -q \
    sqlalchemy alembic PyWavelets gguf \
    opencv-python-headless numba matplotlib \
    scikit-image ultralytics dynamicprompts \
    piexif segment-anything hf_transfer 2>&1 | tail -2 | tee -a $LOG

# ── Pin torch + transformers LAST ─────────────────────────────────────────────
uv pip install --system -q \
    torch==${TORCH_VER} torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/${CUDA_TAG} 2>&1 | tail -2 | tee -a $LOG
uv pip install --system -q 'transformers==4.46.3' 2>&1 | tail -2 | tee -a $LOG

echo "torch pinned: $(python3 -c 'import torch; print(torch.__version__)')" | tee -a $LOG

# ── Config ────────────────────────────────────────────────────────────────────
curl -sSL $REPO/extra_model_paths.yaml -o $COMFY/extra_model_paths.yaml

# ── Symlinks ──────────────────────────────────────────────────────────────────
rm -rf $COMFY/output $COMFY/input $COMFY/user
ln -sfn /workspace/output $COMFY/output
ln -sfn /workspace/input  $COMFY/input
mkdir -p $COMFY/models/ultralytics
ln -sfn $M/ultralytics/bbox $COMFY/models/ultralytics/bbox
ln -sfn $M/ultralytics/segm $COMFY/models/ultralytics/segm
ln -sfn /workspace/user   $COMFY/user

# ── Workflows ─────────────────────────────────────────────────────────────────
cp -n $COMFY/custom_nodes/kitty-prompt-builder/workflows/*.json \
    /workspace/user/default/workflows/ 2>/dev/null || true

# ── Wait for background model downloads to finish ────────────────────────────
echo "=== waiting for background model downloads ===" | tee -a $LOG
wait

# ── LoRA warning ──────────────────────────────────────────────────────────────
if [ ! -f "$M/loras/anna_tatsii/anna_tatsii_klein9b_v4_5000.safetensors" ]; then
    echo "WARNING: upload LoRA to $M/loras/anna_tatsii/" | tee -a $LOG
fi

echo "=== bootstrap done $(date) ===" | tee -a $LOG
echo "ComfyUI starting on port 8188..." | tee -a $LOG

# ── Start ComfyUI ─────────────────────────────────────────────────────────────
cd $COMFY
exec python3 main.py --listen 0.0.0.0 --port 8188 --preview-method auto --enable-cors-header
