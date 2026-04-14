import runpod
import os
import websocket
import base64
import json
import uuid
import logging
import urllib.request
import urllib.parse
import binascii
import subprocess
import librosa
import shutil

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

server_address = os.getenv("SERVER_ADDRESS", "127.0.0.1")
client_id = str(uuid.uuid4())


def truncate_b64(s, n=50):
    if not s:
        return "None"
    return s[:n] + f"...({len(s)} chars)" if len(s) > n else s


def download_url(url, out_path):
    result = subprocess.run(
        ["wget", "-O", out_path, "--no-verbose", "--timeout=60", url],
        capture_output=True, text=True, timeout=120,
    )
    if result.returncode != 0:
        raise Exception(f"Download failed: {result.stderr}")
    return out_path


def save_b64(b64_data, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(base64.b64decode(b64_data))
    return path


def process_input(data, path, mode):
    if mode == "path":
        return data
    elif mode == "url":
        os.makedirs(os.path.dirname(path), exist_ok=True)
        return download_url(data, path)
    elif mode == "base64":
        return save_b64(data, path)
    raise Exception(f"Unknown mode: {mode}")


def queue_prompt(prompt, input_type="image", person_count="single"):
    url = f"http://{server_address}:8188/prompt"
    p = {"prompt": prompt, "client_id": client_id}
    data = json.dumps(p).encode("utf-8")
    req = urllib.request.Request(url, data=data)
    req.add_header("Content-Type", "application/json")
    response = urllib.request.urlopen(req)
    return json.loads(response.read())


def get_history(prompt_id):
    url = f"http://{server_address}:8188/history/{prompt_id}"
    with urllib.request.urlopen(url) as r:
        return json.loads(r.read())


def get_videos(ws, prompt, input_type="image", person_count="single"):
    prompt_id = queue_prompt(prompt, input_type, person_count)["prompt_id"]
    logger.info(f"Workflow submitted: {prompt_id}")

    while True:
        out = ws.recv()
        if isinstance(out, str):
            msg = json.loads(out)
            if msg["type"] == "executing":
                d = msg["data"]
                if d["node"] is not None:
                    logger.info(f"Running node: {d['node']}")
                if d["node"] is None and d["prompt_id"] == prompt_id:
                    logger.info("Workflow complete")
                    break

    history = get_history(prompt_id)[prompt_id]
    output_videos = {}
    for node_id in history["outputs"]:
        node_output = history["outputs"][node_id]
        paths = []
        if "gifs" in node_output:
            for video in node_output["gifs"]:
                vpath = video["fullpath"]
                if os.path.exists(vpath) and os.path.getsize(vpath) > 1024:
                    paths.append(vpath)
                    logger.info(f"Found video: {vpath} ({os.path.getsize(vpath)} bytes)")
                else:
                    logger.warning(f"Missing or empty: {vpath}")
        output_videos[node_id] = paths
    return output_videos


def get_audio_duration(path):
    try:
        return librosa.get_duration(path=path)
    except Exception as e:
        logger.warning(f"Duration check failed: {e}")
        return None


def calc_max_frames(wav_path, fps=25):
    dur = get_audio_duration(wav_path)
    if dur is None:
        return 81
    frames = int(dur * fps) + 81
    logger.info(f"Audio {dur:.1f}s → max_frames={frames}")
    return frames


def handler(job):
    inp = job.get("input", {})
    task_id = f"task_{uuid.uuid4()}"
    tmp = f"/tmp/{task_id}"
    os.makedirs(tmp, exist_ok=True)

    # ── Input type / person count ─────────────────────────────────────────
    input_type   = inp.get("input_type", "image")
    person_count = inp.get("person_count", "single")
    logger.info(f"input_type={input_type} person_count={person_count}")

    # ── Image input ───────────────────────────────────────────────────────
    if input_type == "image":
        if "image_path" in inp:
            media_path = process_input(inp["image_path"], f"{tmp}/input_image.jpg", "path")
        elif "image_url" in inp:
            media_path = process_input(inp["image_url"], f"{tmp}/input_image.jpg", "url")
        elif "image_base64" in inp:
            media_path = process_input(inp["image_base64"], f"{tmp}/input_image.jpg", "base64")
        else:
            media_path = "/examples/image.jpg"
    else:
        if "video_path" in inp:
            media_path = process_input(inp["video_path"], f"{tmp}/input_video.mp4", "path")
        elif "video_url" in inp:
            media_path = process_input(inp["video_url"], f"{tmp}/input_video.mp4", "url")
        elif "video_base64" in inp:
            media_path = process_input(inp["video_base64"], f"{tmp}/input_video.mp4", "base64")
        else:
            media_path = "/examples/image.jpg"

    # ── Audio input ───────────────────────────────────────────────────────
    if "wav_path" in inp:
        wav_path = process_input(inp["wav_path"], f"{tmp}/input_audio.wav", "path")
    elif "wav_url" in inp:
        wav_path = process_input(inp["wav_url"], f"{tmp}/input_audio.wav", "url")
    elif "wav_base64" in inp:
        wav_path = process_input(inp["wav_base64"], f"{tmp}/input_audio.wav", "base64")
    else:
        wav_path = "/examples/audio.mp3"

    # Validate files exist
    for label, path in [("media", media_path), ("audio", wav_path)]:
        if not os.path.exists(path):
            return {"error": f"{label} file not found: {path}"}
    logger.info(f"media={media_path} ({os.path.getsize(media_path)} bytes)")
    logger.info(f"audio={wav_path} ({os.path.getsize(wav_path)} bytes)")

    # ── Workflow parameters ───────────────────────────────────────────────
    prompt_text  = inp.get("prompt", "a person is talking expressively, natural hand gestures")
    width        = inp.get("width", 512)
    height       = inp.get("height", 512)
    max_frame    = inp.get("max_frame") or calc_max_frames(wav_path)
    force_offload = inp.get("force_offload", True)

    # Snap to 16-pixel multiples (WanVideo requirement)
    width  = (width  // 16) * 16
    height = (height // 16) * 16

    workflow_path = "/I2V_single.json"
    with open(workflow_path) as f:
        prompt = json.load(f)

    # Inject parameters
    prompt["284"]["inputs"]["image"]  = media_path
    prompt["125"]["inputs"]["audio"]  = wav_path
    prompt["241"]["inputs"]["positive_prompt"] = prompt_text
    prompt["245"]["inputs"]["value"]  = width
    prompt["246"]["inputs"]["value"]  = height
    prompt["270"]["inputs"]["value"]  = max_frame

    # Force offload into sampler (prevents OOM)
    for nid, nd in prompt.items():
        if nd.get("class_type") == "WanVideoSampler":
            nd.setdefault("inputs", {})["force_offload"] = force_offload
            logger.info(f"WanVideoSampler ({nid}): force_offload={force_offload}")
            break

    # ── ComfyUI connection ────────────────────────────────────────────────
    http_url = f"http://{server_address}:8188/"
    for attempt in range(60):
        try:
            urllib.request.urlopen(http_url, timeout=5)
            break
        except Exception:
            if attempt == 59:
                return {"error": "ComfyUI failed to respond"}
            import time; time.sleep(2)

    ws_url = f"ws://{server_address}:8188/ws?clientId={client_id}"
    ws = websocket.WebSocket()
    for attempt in range(36):
        try:
            ws.connect(ws_url); break
        except Exception:
            if attempt == 35:
                return {"error": "WebSocket connection timed out"}
            import time; time.sleep(5)

    videos = get_videos(ws, prompt, input_type, person_count)
    ws.close()

    # ── Find output video ─────────────────────────────────────────────────
    output_path = None
    for nid in videos:
        if videos[nid]:
            output_path = videos[nid][0]
            break

    if not output_path or not os.path.exists(output_path):
        return {"error": "No video output produced. Check ComfyUI logs."}

    # ── Return base64 or network-volume path ──────────────────────────────
    if inp.get("network_volume", False):
        dest = f"/runpod-volume/infinitetalk_{task_id}.mp4"
        shutil.copy2(output_path, dest)
        return {"video_path": dest}
    else:
        with open(output_path, "rb") as f:
            video_b64 = base64.b64encode(f.read()).decode("utf-8")
        logger.info(f"Returning {len(video_b64)} chars of base64 video")
        return {"video": video_b64}


runpod.serverless.start({"handler": handler})
