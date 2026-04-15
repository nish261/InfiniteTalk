#!/bin/bash
set -e

# Models stored on network volume (/runpod-volume/models) — downloaded once, reused forever
# Falls back to /ComfyUI/models if no volume mounted
if [ -d "/runpod-volume/models" ]; then
    echo "Network volume detected — symlinking models..."
    for subdir in diffusion_models loras vae text_encoders clip_vision; do
        rm -rf /ComfyUI/models/$subdir
        ln -sf /runpod-volume/models/$subdir /ComfyUI/models/$subdir
    done
    echo "Models symlinked from network volume."
else
    echo "No network volume — downloading models to local disk..."
    download_if_missing() {
        local url="$1" dest="$2"
        [ -f "$dest" ] && echo "Exists: $(basename $dest)" && return
        echo "Downloading $(basename $dest)..."
        wget -q --show-progress "$url" -O "$dest" || { echo "FAILED: $dest"; exit 1; }
    }
    M="/ComfyUI/models"
    download_if_missing "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors" "$M/diffusion_models/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors"
    download_if_missing "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors" "$M/diffusion_models/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors"
    download_if_missing "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" "$M/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"
    download_if_missing "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" "$M/vae/Wan2_1_VAE_bf16.safetensors"
    download_if_missing "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-fp8_e4m3fn.safetensors" "$M/text_encoders/umt5-xxl-enc-fp8_e4m3fn.safetensors"
    download_if_missing "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" "$M/clip_vision/clip_vision_h.safetensors"
    download_if_missing "https://huggingface.co/Kijai/MelBandRoFormer_comfy/resolve/main/MelBandRoformer_fp16.safetensors" "$M/diffusion_models/MelBandRoformer_fp16.safetensors"
    echo "All models ready."
fi

echo "Starting ComfyUI..."
python /ComfyUI/main.py --listen --use-split-cross-attention &

for i in $(seq 1 180); do
    curl -s http://127.0.0.1:8188/ > /dev/null 2>&1 && echo "ComfyUI ready!" && break
    sleep 2
done

echo "Starting handler..."
exec python /handler.py
