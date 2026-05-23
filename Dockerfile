FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/workspace/.cache/huggingface \
    HUGGINGFACE_HUB_CACHE=/workspace/.cache/huggingface \
    HF_HUB_ENABLE_HF_TRANSFER=1

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# ComfyUI
RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI /opt/comfyui
RUN cd /opt/comfyui && uv pip install --system -r requirements.txt

# Custom nodes
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
    git clone --depth 1 https://github.com/Extraltodeus/RES4LYF && \
    git clone --depth 1 https://github.com/adieyal/comfyui-dynamicprompts && \
    git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use

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
