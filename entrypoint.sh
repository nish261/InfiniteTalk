#!/bin/bash
set -e

WEIGHTS="/runpod-volume/infinitetalk"

if [ -d "/runpod-volume" ]; then
    mkdir -p "${WEIGHTS}"

    # ── Wan2.1-I2V-14B-480P ──────────────────────────────────────────────────
    WAN_DIR="${WEIGHTS}/Wan2.1-I2V-14B-480P"
    if [ -f "${WAN_DIR}/.downloaded" ] && [ -f "${WAN_DIR}/config.json" ]; then
        echo "EXISTS: Wan2.1-I2V-14B-480P"
    else
        rm -f "${WAN_DIR}/.downloaded"
        echo "DOWNLOADING: Wan-AI/Wan2.1-I2V-14B-480P (~28 GB)"
        mkdir -p "${WAN_DIR}"
        HF_HUB_ENABLE_HF_TRANSFER=1 huggingface-cli download Wan-AI/Wan2.1-I2V-14B-480P \
            --local-dir "${WAN_DIR}" --local-dir-use-symlinks False
        touch "${WAN_DIR}/.downloaded"
        echo "DONE: Wan2.1-I2V-14B-480P"
    fi

    # ── chinese-wav2vec2-base ─────────────────────────────────────────────────
    W2V_DIR="${WEIGHTS}/chinese-wav2vec2-base"
    if [ -f "${W2V_DIR}/.downloaded" ] && [ -f "${W2V_DIR}/config.json" ]; then
        echo "EXISTS: chinese-wav2vec2-base"
    else
        rm -f "${W2V_DIR}/.downloaded"
        echo "DOWNLOADING: TencentGameMate/chinese-wav2vec2-base"
        mkdir -p "${W2V_DIR}"
        HF_HUB_ENABLE_HF_TRANSFER=1 huggingface-cli download TencentGameMate/chinese-wav2vec2-base \
            --local-dir "${W2V_DIR}" --local-dir-use-symlinks False
        touch "${W2V_DIR}/.downloaded"
        echo "DONE: chinese-wav2vec2-base"
    fi

    # ── InfiniteTalk single model (~2 GB, NOT the full 168 GB repo) ───────────
    IT_DIR="${WEIGHTS}/InfiniteTalk"
    IT_WEIGHTS="${IT_DIR}/single/infinitetalk.safetensors"
    if [ -f "${IT_DIR}/.downloaded" ] && [ -f "${IT_WEIGHTS}" ]; then
        echo "EXISTS: InfiniteTalk (single)"
    else
        rm -f "${IT_DIR}/.downloaded"
        echo "DOWNLOADING: MeiGen-AI/InfiniteTalk single/infinitetalk.safetensors"
        mkdir -p "${IT_DIR}/single"
        HF_HUB_ENABLE_HF_TRANSFER=1 huggingface-cli download MeiGen-AI/InfiniteTalk \
            --local-dir "${IT_DIR}" --local-dir-use-symlinks False \
            --include "single/infinitetalk.safetensors"
        touch "${IT_DIR}/.downloaded"
        echo "DONE: InfiniteTalk"
    fi

else
    echo "WARNING: No network volume mounted — models will not persist across restarts."
    mkdir -p "${WEIGHTS}"
    # Still try to download (ephemeral — will need to re-download each restart)
    WAN_DIR="${WEIGHTS}/Wan2.1-I2V-14B-480P"
    W2V_DIR="${WEIGHTS}/chinese-wav2vec2-base"
    IT_DIR="${WEIGHTS}/InfiniteTalk"
    HF_HUB_ENABLE_HF_TRANSFER=1 huggingface-cli download Wan-AI/Wan2.1-I2V-14B-480P \
        --local-dir "${WAN_DIR}" --local-dir-use-symlinks False
    HF_HUB_ENABLE_HF_TRANSFER=1 huggingface-cli download TencentGameMate/chinese-wav2vec2-base \
        --local-dir "${W2V_DIR}" --local-dir-use-symlinks False
    HF_HUB_ENABLE_HF_TRANSFER=1 huggingface-cli download MeiGen-AI/InfiniteTalk \
        --local-dir "${IT_DIR}" --local-dir-use-symlinks False \
        --include "single/infinitetalk.safetensors"
fi

echo "Model check complete. Starting InfiniteTalk handler..."
exec python /handler.py
