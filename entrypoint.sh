#!/bin/bash
set -e

MODEL_DIR="/ComfyUI/models"

download_if_missing() {
    local url="$1"
    local dest="$2"
    if [ ! -f "$dest" ]; then
        echo "Downloading $(basename $dest)..."
        wget -q --show-progress "$url" -O "$dest" || { echo "FAILED: $dest"; exit 1; }
    else
        echo "Already exists: $(basename $dest)"
    fi
}

echo "=== Downloading models ==="
download_if_missing \
    "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors" \
    "$MODEL_DIR/diffusion_models/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors"

download_if_missing \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors" \
    "$MODEL_DIR/diffusion_models/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors"

download_if_missing \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" \
    "$MODEL_DIR/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"

download_if_missing \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" \
    "$MODEL_DIR/vae/Wan2_1_VAE_bf16.safetensors"

download_if_missing \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-fp8_e4m3fn.safetensors" \
    "$MODEL_DIR/text_encoders/umt5-xxl-enc-fp8_e4m3fn.safetensors"

download_if_missing \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
    "$MODEL_DIR/clip_vision/clip_vision_h.safetensors"

download_if_missing \
    "https://huggingface.co/Kijai/MelBandRoFormer_comfy/resolve/main/MelBandRoformer_fp16.safetensors" \
    "$MODEL_DIR/diffusion_models/MelBandRoformer_fp16.safetensors"

echo "=== All models ready ==="

echo "Starting ComfyUI..."
python /ComfyUI/main.py --listen --use-split-cross-attention &

echo "Waiting for ComfyUI..."
for i in $(seq 1 180); do
    if curl -s http://127.0.0.1:8188/ > /dev/null 2>&1; then
        echo "ComfyUI ready!"
        break
    fi
    sleep 2
done

echo "Starting handler..."
exec python /handler.py
