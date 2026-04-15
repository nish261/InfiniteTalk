#!/bin/bash

WEIGHTS="/runpod-volume/infinitetalk"

download_if_missing() {
    local repo_id="$1"
    local local_dir="$2"

    if [ -f "${local_dir}/.downloaded" ]; then
        echo "EXISTS: ${repo_id}"
        return 0
    fi

    echo "DOWNLOADING: ${repo_id} → ${local_dir}"
    mkdir -p "${local_dir}"
    HF_HUB_ENABLE_HF_TRANSFER=1 huggingface-cli download \
        "${repo_id}" \
        --local-dir "${local_dir}" \
        --local-dir-use-symlinks False
    touch "${local_dir}/.downloaded"
    echo "DONE: ${repo_id}"
}

if [ -d "/runpod-volume" ]; then
    mkdir -p "${WEIGHTS}"
    download_if_missing "Wan-AI/Wan2.1-I2V-14B-480P"           "${WEIGHTS}/Wan2.1-I2V-14B-480P"
    download_if_missing "TencentGameMate/chinese-wav2vec2-base" "${WEIGHTS}/chinese-wav2vec2-base"
    download_if_missing "MeiGen-AI/InfiniteTalk"                "${WEIGHTS}/InfiniteTalk"
else
    echo "WARNING: No network volume mounted. Models will not persist."
    mkdir -p "${WEIGHTS}"
    download_if_missing "Wan-AI/Wan2.1-I2V-14B-480P"           "${WEIGHTS}/Wan2.1-I2V-14B-480P"
    download_if_missing "TencentGameMate/chinese-wav2vec2-base" "${WEIGHTS}/chinese-wav2vec2-base"
    download_if_missing "MeiGen-AI/InfiniteTalk"                "${WEIGHTS}/InfiniteTalk"
fi

echo "Starting InfiniteTalk handler..."
exec python /handler.py
