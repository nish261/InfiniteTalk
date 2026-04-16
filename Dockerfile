FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

RUN apt-get update && apt-get install -y wget curl git ffmpeg && rm -rf /var/lib/apt/lists/*

# Pin torch/torchvision/torchaudio + xformers together to avoid version mismatch
RUN pip install \
    "torch==2.6.0" "torchvision==0.21.0" "torchaudio==2.6.0" \
    --index-url https://download.pytorch.org/whl/cu124 && \
    pip install "xformers==0.0.29.post3" \
    --index-url https://download.pytorch.org/whl/cu124

# Clone InfiniteTalk
RUN git clone https://github.com/MeiGen-AI/InfiniteTalk.git /InfiniteTalk

# Install InfiniteTalk deps from its own requirements (skip UI-only packages)
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

# Patch flash_attn imports to catch ImportError (ABI mismatch), not just ModuleNotFoundError
RUN python3 -c "
import re, glob
for f in glob.glob('/InfiniteTalk/**/*.py', recursive=True):
    src = open(f).read()
    if 'except ModuleNotFoundError' in src and 'flash_attn' in src:
        patched = src.replace('except ModuleNotFoundError:', 'except Exception:')
        open(f, 'w').write(patched)
        print('Patched:', f)
print('Done')
"

# Install RunPod + HuggingFace tools
RUN pip install runpod "huggingface_hub[hf_transfer]"

COPY handler.py /handler.py
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
