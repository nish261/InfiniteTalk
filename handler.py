import runpod
import os
import sys
import torch
import numpy as np
import base64
import uuid
import logging
import subprocess
import shutil
import librosa
from einops import rearrange

sys.path.insert(0, '/InfiniteTalk')

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

WEIGHTS = "/runpod-volume/infinitetalk"
CKPT_DIR = f"{WEIGHTS}/Wan2.1-I2V-14B-480P"
WAV2VEC_DIR = f"{WEIGHTS}/chinese-wav2vec2-base"
INFINITETALK_WEIGHTS = f"{WEIGHTS}/InfiniteTalk/single/infinitetalk.safetensors"

# Loaded once per worker
PIPELINE = None
AUDIO_ENCODER = None
WAV2VEC_FE = None


def load_models():
    global PIPELINE, AUDIO_ENCODER, WAV2VEC_FE

    from wan import InfiniteTalkPipeline
    from wan.configs import WAN_CONFIGS
    from src.audio_analysis.wav2vec2 import Wav2Vec2Model
    from transformers import Wav2Vec2FeatureExtractor

    logger.info("Loading InfiniteTalk pipeline...")
    cfg = WAN_CONFIGS['infinitetalk-14B']
    PIPELINE = InfiniteTalkPipeline(
        config=cfg,
        checkpoint_dir=CKPT_DIR,
        infinitetalk_dir=INFINITETALK_WEIGHTS,
        device_id=0,
        rank=0,
        t5_fsdp=False,
        dit_fsdp=False,
        use_usp=False,
        t5_cpu=True,
        init_on_cpu=True,
    )

    logger.info("Loading audio encoder...")
    AUDIO_ENCODER = Wav2Vec2Model.from_pretrained(
        WAV2VEC_DIR, local_files_only=True
    ).eval().cuda()
    AUDIO_ENCODER.feature_extractor._freeze_parameters()

    WAV2VEC_FE = Wav2Vec2FeatureExtractor.from_pretrained(
        WAV2VEC_DIR, local_files_only=True
    )
    logger.info("All models loaded.")


def get_embedding(speech_array, sr=16000):
    audio_duration = len(speech_array) / sr
    video_length = audio_duration * 25  # 25 fps

    audio_feature = np.squeeze(
        WAV2VEC_FE(speech_array, sampling_rate=sr).input_values
    )
    audio_feature = torch.from_numpy(audio_feature).float().cuda().unsqueeze(0)

    with torch.no_grad():
        embeddings = AUDIO_ENCODER(
            audio_feature, seq_len=int(video_length), output_hidden_states=True
        )

    audio_emb = torch.stack(embeddings.hidden_states[1:], dim=1).squeeze(0)
    audio_emb = rearrange(audio_emb, "b s d -> s b d")
    return audio_emb.cpu().detach()


def loudness_norm(audio_array, sr=16000, target=-23.0):
    try:
        import pyloudnorm as pyln
        meter = pyln.Meter(sr)
        loudness = meter.integrated_loudness(audio_array)
        return pyln.normalize.loudness(audio_array, loudness, target).astype(np.float32)
    except Exception:
        return audio_array.astype(np.float32)


def handler(job):
    inp = job.get("input", {})
    task_id = uuid.uuid4().hex[:8]
    tmp = f"/tmp/it_{task_id}"
    os.makedirs(tmp, exist_ok=True)

    try:
        # ── Download image ────────────────────────────────────────────────
        img_path = f"{tmp}/input.jpg"
        if "image_url" in inp:
            r = subprocess.run(
                ["wget", "-q", "--timeout=60", "-O", img_path, inp["image_url"]],
                capture_output=True, timeout=90
            )
            if r.returncode != 0:
                return {"error": f"Image download failed: {r.stderr.decode()[:300]}"}
        elif "image_base64" in inp:
            with open(img_path, "wb") as f:
                f.write(base64.b64decode(inp["image_base64"]))
        else:
            return {"error": "No image input (image_url or image_base64 required)"}

        # ── Download audio ────────────────────────────────────────────────
        raw_wav = f"{tmp}/input_raw.wav"
        if "wav_url" in inp:
            r = subprocess.run(
                ["wget", "-q", "--timeout=60", "-O", raw_wav, inp["wav_url"]],
                capture_output=True, timeout=90
            )
            if r.returncode != 0:
                return {"error": f"Audio download failed: {r.stderr.decode()[:300]}"}
        elif "wav_base64" in inp:
            with open(raw_wav, "wb") as f:
                f.write(base64.b64decode(inp["wav_base64"]))
        else:
            return {"error": "No audio input (wav_url or wav_base64 required)"}

        # Normalize to 16kHz mono
        wav_16k = f"{tmp}/audio.wav"
        subprocess.run(
            ["ffmpeg", "-y", "-i", raw_wav, "-ar", "16000", "-ac", "1", wav_16k],
            capture_output=True, check=True
        )

        # ── Audio embedding ───────────────────────────────────────────────
        speech_array, _ = librosa.load(wav_16k, sr=16000)
        speech_array = loudness_norm(speech_array)

        logger.info(f"Computing audio embedding for {len(speech_array)/16000:.1f}s audio...")
        audio_emb = get_embedding(speech_array)
        emb_path = f"{tmp}/audio_emb.pt"
        torch.save(audio_emb, emb_path)

        # ── Build input_clip ──────────────────────────────────────────────
        prompt = inp.get("prompt", "a person is talking expressively with natural movements")
        input_clip = {
            'prompt': prompt,
            'cond_video': img_path,
            'cond_audio': {'person1': emb_path},
            'video_audio': wav_16k,
        }

        # ── Generate ──────────────────────────────────────────────────────
        sampling_steps = inp.get("sampling_steps", 40)
        seed = inp.get("seed", -1)
        max_frames = inp.get("max_frames", 1000)
        logger.info(f"Generating video: steps={sampling_steps} seed={seed} max_frames={max_frames}")

        video_tensor = PIPELINE.generate_infinitetalk(
            input_clip,
            size_buckget='infinitetalk-480',
            motion_frame=9,
            frame_num=81,
            shift=5.0,
            sampling_steps=sampling_steps,
            text_guide_scale=5.0,
            audio_guide_scale=4.0,
            seed=seed,
            offload_model=True,
            max_frames_num=max_frames,
        )

        # ── Save ──────────────────────────────────────────────────────────
        out_path = f"{tmp}/output.mp4"
        from wan.utils.multitalk_utils import save_video_ffmpeg
        save_video_ffmpeg(video_tensor, out_path, [wav_16k], fps=25)

        if not os.path.exists(out_path) or os.path.getsize(out_path) < 1024:
            return {"error": "Output video missing or empty"}

        logger.info(f"Video generated: {os.path.getsize(out_path)} bytes")

        with open(out_path, "rb") as f:
            return {"video": base64.b64encode(f.read()).decode()}

    except Exception as e:
        import traceback
        return {"error": str(e), "traceback": traceback.format_exc()[-2000:]}

    finally:
        shutil.rmtree(tmp, ignore_errors=True)


load_models()
runpod.serverless.start({"handler": handler})
