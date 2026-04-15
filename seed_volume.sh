#!/bin/bash
# One-time script to seed RunPod network volume with InfiniteTalk models
# Run inside a pod that has the volume mounted at /runpod-volume

set -e

M=/runpod-volume/models
mkdir -p "$M/diffusion_models" "$M/loras" "$M/vae" "$M/text_encoders" "$M/clip_vision"

dl() {
    local dest="$1" url="$2"
    if [ -f "$dest" ]; then
        echo "EXISTS: $(basename $dest)"
    else
        echo "DOWNLOADING: $(basename $dest)"
        wget -q --show-progress --timeout=120 --tries=3 -O "$dest" "$url"
        echo "DONE: $(basename $dest)"
    fi
}

dl "$M/diffusion_models/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors" \
   "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/InfiniteTalk/Wan2_1-InfiniteTalk-Single_fp8_e4m3fn_scaled_KJ.safetensors"

dl "$M/diffusion_models/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors" \
   "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-480P_fp8_e4m3fn.safetensors"

dl "$M/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" \
   "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"

dl "$M/vae/Wan2_1_VAE_bf16.safetensors" \
   "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors"

dl "$M/text_encoders/umt5-xxl-enc-fp8_e4m3fn.safetensors" \
   "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-fp8_e4m3fn.safetensors"

dl "$M/clip_vision/clip_vision_h.safetensors" \
   "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"

dl "$M/diffusion_models/MelBandRoformer_fp16.safetensors" \
   "https://huggingface.co/Kijai/MelBandRoFormer_comfy/resolve/main/MelBandRoformer_fp16.safetensors"

touch "$M/.seeded"
echo ""
echo "=== ALL MODELS SEEDED TO NETWORK VOLUME ==="
du -sh "$M"
