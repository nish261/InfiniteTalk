#!/bin/bash
set -e

M_LOCAL="/ComfyUI/models"
M_VOL="/runpod-volume/models"

download_models() {
    local DEST="$1"
    mkdir -p "$DEST/diffusion_models" "$DEST/loras" "$DEST/vae" "$DEST/text_encoders" "$DEST/clip_vision"

    download_if_missing() {
        local url="$1" dest="$2"
        [ -f "$dest" ] && echo "Exists: $(basename $dest)" && return
        echo "Downloading $(basename $dest)..."
        wget -q --show-progress --timeout=120 --tries=3 "$url" -O "$dest" || { echo "FAILED: $dest"; exit 1; }
    }

    download_if_missing "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors" "$DEST/diffusion_models/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors"
    download_if_missing "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors" "$DEST/diffusion_models/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors"
    download_if_missing "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" "$DEST/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"
    download_if_missing "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" "$DEST/vae/Wan2_1_VAE_bf16.safetensors"
    download_if_missing "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-fp8_e4m3fn.safetensors" "$DEST/text_encoders/umt5-xxl-enc-fp8_e4m3fn.safetensors"
    download_if_missing "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" "$DEST/clip_vision/clip_vision_h.safetensors"
    download_if_missing "https://huggingface.co/Kijai/MelBandRoFormer_comfy/resolve/main/MelBandRoformer_fp16.safetensors" "$DEST/diffusion_models/MelBandRoformer_fp16.safetensors"

    echo "All models ready at $DEST"
}

symlink_from_volume() {
    echo "Symlinking models from network volume..."
    for subdir in diffusion_models loras vae text_encoders clip_vision; do
        rm -rf "$M_LOCAL/$subdir"
        ln -sf "$M_VOL/$subdir" "$M_LOCAL/$subdir"
    done
}

if [ -f "$M_VOL/.seeded" ]; then
    # Volume already seeded — fast path
    echo "Network volume ready — symlinking models (instant start)..."
    symlink_from_volume

elif [ -d "/runpod-volume" ]; then
    # Volume mounted but not seeded yet — download once, mark done
    echo "Network volume detected but empty — seeding models (one-time ~30min)..."
    download_models "$M_VOL"
    touch "$M_VOL/.seeded"
    symlink_from_volume

else
    # No volume — download to local disk
    echo "No network volume — downloading models to local disk..."
    download_models "$M_LOCAL"
fi

echo "Starting ComfyUI..."
python /ComfyUI/main.py --listen --use-split-cross-attention &

for i in $(seq 1 180); do
    curl -s http://127.0.0.1:8188/ > /dev/null 2>&1 && echo "ComfyUI ready!" && break
    sleep 2
done

echo "Starting handler..."
exec python /handler.py
