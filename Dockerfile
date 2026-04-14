FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

# Install system utilities
RUN apt-get update && apt-get install -y wget curl git && rm -rf /var/lib/apt/lists/*

# Python dependencies for handler
RUN pip install -U "huggingface_hub[hf_transfer]" runpod websocket-client librosa

WORKDIR /

# ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd /ComfyUI && pip install -r requirements.txt

# Custom nodes
RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/Comfy-Org/ComfyUI-Manager.git && \
    cd ComfyUI-Manager && pip install -r requirements.txt

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/city96/ComfyUI-GGUF && \
    cd ComfyUI-GGUF && pip install -r requirements.txt

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-KJNodes && \
    cd ComfyUI-KJNodes && pip install -r requirements.txt

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite && \
    cd ComfyUI-VideoHelperSuite && pip install -r requirements.txt

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/orssorbit/ComfyUI-wanBlockswap

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-MelBandRoFormer && \
    cd ComfyUI-MelBandRoFormer && pip install -r requirements.txt

RUN cd /ComfyUI/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper && \
    cd ComfyUI-WanVideoWrapper && pip install -r requirements.txt

# Model downloads (baked into image — no cold-start download wait)
RUN mkdir -p /ComfyUI/models/diffusion_models \
             /ComfyUI/models/loras \
             /ComfyUI/models/vae \
             /ComfyUI/models/text_encoders \
             /ComfyUI/models/clip_vision

RUN wget -q https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors \
    -O /ComfyUI/models/diffusion_models/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors

RUN wget -q https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors \
    -O /ComfyUI/models/diffusion_models/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors

RUN wget -q https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors \
    -O /ComfyUI/models/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors

RUN wget -q https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors \
    -O /ComfyUI/models/vae/Wan2_1_VAE_bf16.safetensors

RUN wget -q https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-fp8_e4m3fn.safetensors \
    -O /ComfyUI/models/text_encoders/umt5-xxl-enc-fp8_e4m3fn.safetensors

RUN wget -q https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors \
    -O /ComfyUI/models/clip_vision/clip_vision_h.safetensors

RUN wget -q https://huggingface.co/Kijai/MelBandRoFormer_comfy/resolve/main/MelBandRoformer_fp16.safetensors \
    -O /ComfyUI/models/diffusion_models/MelBandRoformer_fp16.safetensors

# Copy handler, workflow, and example assets
COPY handler.py /handler.py
COPY entrypoint.sh /entrypoint.sh
COPY I2V_single.json /I2V_single.json
COPY examples/single/ref_image.png /examples/image.jpg
COPY examples/single/1.wav /examples/audio.mp3

RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
