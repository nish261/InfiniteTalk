FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

RUN apt-get update && apt-get install -y wget curl git && rm -rf /var/lib/apt/lists/*

# Upgrade PyTorch to >=2.6 to fix CVE-2025-32434 torch.load block
RUN pip install -U "torch>=2.6.0" torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

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

# Patch WanVideoWrapper: make allow_fp16_accumulation conditional (torch 2.7 nightly only)
RUN python3 -c "\
import glob, re;\
files = glob.glob('/ComfyUI/custom_nodes/ComfyUI-WanVideoWrapper/**/*.py', recursive=True);\
[open(f,'w').write(re.sub(r'(?m)^([ \t]*)if not hasattr\(torch.backends.cuda.matmul,[^)]+\):[^\n]*\n[ \t]*raise[^\n]*\n','',re.sub(r'(?m)^([ \t]*)(torch.backends.cuda.matmul.allow_fp16_accumulation\s*=)',r'\1if hasattr(torch.backends.cuda.matmul,\"allow_fp16_accumulation\"): \2',open(f).read()))) or print('Patched:',f) for f in files if 'allow_fp16_accumulation' in open(f).read()];\
print('Patch done')\
"

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
