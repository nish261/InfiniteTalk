FROM runpod/pytorch:2.8.0-py3.11-cuda12.8.1-devel-ubuntu22.04

RUN apt-get update && apt-get install -y wget curl git && rm -rf /var/lib/apt/lists/*

RUN pip install -U "huggingface_hub[hf_transfer]" runpod websocket-client librosa

WORKDIR /

RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd /ComfyUI && pip install -r requirements.txt

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

RUN mkdir -p /ComfyUI/models/diffusion_models \
             /ComfyUI/models/loras \
             /ComfyUI/models/vae \
             /ComfyUI/models/text_encoders \
             /ComfyUI/models/clip_vision

COPY handler.py /handler.py
COPY entrypoint.sh /entrypoint.sh
COPY I2V_single.json /I2V_single.json
COPY examples/single/ref_image.png /examples/image.jpg
COPY examples/single/1.wav /examples/audio.mp3

RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
