FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

RUN apt-get update && apt-get install -y wget curl git ffmpeg && rm -rf /var/lib/apt/lists/*

# Upgrade PyTorch to fix CVE-2025-32434
RUN pip install -U "torch>=2.6.0" torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# Clone InfiniteTalk
RUN git clone https://github.com/MeiGen-AI/InfiniteTalk.git /InfiniteTalk

# Install InfiniteTalk dependencies (skip gradio/dashscope — not needed for inference)
RUN pip install \
    "opencv-python>=4.9.0.80" \
    "diffusers>=0.31.0" \
    "transformers>=4.49.0" \
    "tokenizers>=0.20.3" \
    "accelerate>=1.1.1" \
    tqdm imageio easydict ftfy \
    imageio-ffmpeg scikit-image loguru \
    "numpy>=1.23.5,<2" \
    pyloudnorm \
    "optimum-quanto==0.2.6" \
    scenedetect "moviepy==1.0.3" decord \
    librosa einops scipy \
    "xfuser>=0.4.1"

# Install RunPod + HuggingFace tools
RUN pip install runpod "huggingface_hub[hf_transfer]"

COPY handler.py /handler.py
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
