ARG BASE_IMAGE=runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/workspace/.cache/huggingface \
    HUGGINGFACE_HUB_CACHE=/workspace/.cache/huggingface \
    HF_HUB_ENABLE_HF_TRANSFER=1

# SSH server
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server && \
    mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config && \
    rm -rf /var/lib/apt/lists/*

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# ComfyUI
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI /opt/comfyui
RUN cd /opt/comfyui && uv pip install --system -r requirements.txt

# Custom nodes
ENV GIT_TERMINAL_PROMPT=0
RUN cd /opt/comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/city96/ComfyUI-GGUF && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-SUPIR && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Inspire-Pack && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes && \
    git clone --depth 1 https://github.com/cubiq/ComfyUI_essentials && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy && \
    git clone --depth 1 https://github.com/ssitu/ComfyUI_UltimateSDUpscale && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack && \
    git clone --depth 1 https://github.com/melMass/comfy_mtb && \
    git clone --depth 1 https://github.com/WASasquatch/was-node-suite-comfyui && \
    git clone --depth 1 https://github.com/adieyal/comfyui-dynamicprompts && \
    git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use && \
    git clone --depth 1 https://github.com/ClownsharkBatwing/RES4LYF

# Custom node requirements
RUN for req in /opt/comfyui/custom_nodes/*/requirements.txt; do \
        uv pip install --system -q -r "$req" 2>/dev/null || true; \
    done

# Extra packages
RUN uv pip install --system \
    sqlalchemy alembic PyWavelets gguf \
    opencv-python-headless numba matplotlib \
    scikit-image ultralytics dynamicprompts \
    piexif segment-anything hf_transfer

# Pin torch + transformers LAST — deps re-upgrade them otherwise
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu124
ARG TORCH_VERSION=2.4.0
ARG TORCHVISION_VERSION=0.19.0
ARG TORCHAUDIO_VERSION=2.4.0
RUN uv pip install --system \
    torch==${TORCH_VERSION} torchvision==${TORCHVISION_VERSION} torchaudio==${TORCHAUDIO_VERSION} \
    --index-url ${TORCH_INDEX_URL} && \
    uv pip install --system 'transformers==4.46.3'

# kitty-prompt-builder
COPY custom_nodes/kitty-prompt-builder /opt/comfyui/custom_nodes/kitty-prompt-builder

# Config files
COPY extra_model_paths.yaml /opt/comfyui/extra_model_paths.yaml
COPY download_models.sh /opt/comfyui/download_models.sh
RUN chmod +x /opt/comfyui/download_models.sh

COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR /opt/comfyui
CMD ["/start.sh"]
