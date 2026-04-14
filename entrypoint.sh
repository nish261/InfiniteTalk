#!/bin/bash
set -e

echo "Starting ComfyUI..."
# Use standard cross-attention (no SageAttention required — works on all Ada Lovelace GPUs)
python /ComfyUI/main.py --listen --use-split-cross-attention &

echo "Waiting for ComfyUI to be ready..."
max_wait=180
wait_count=0
while [ $wait_count -lt $max_wait ]; do
    if curl -s http://127.0.0.1:8188/ > /dev/null 2>&1; then
        echo "ComfyUI is ready!"
        break
    fi
    echo "  waiting... ($wait_count/$max_wait)"
    sleep 2
    wait_count=$((wait_count + 2))
done

if [ $wait_count -ge $max_wait ]; then
    echo "Error: ComfyUI failed to start in ${max_wait}s"
    exit 1
fi

echo "Starting RunPod handler..."
exec python /handler.py
