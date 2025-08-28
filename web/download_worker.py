import os
import requests
import time
import json
from pathlib import Path
from urllib.parse import urlparse
from websocket import create_connection

# Загрузка переменных
COMFYUI_DIR = os.getenv("COMFYUI_DIR", "/ComfyUI")
COMFYUI_URL = os.getenv("COMFYUI_URL", "http://127.0.0.1:8188")
CIVITAI_API_KEY = os.getenv("CIVITAI_API_KEY", "")
WS_URL = os.getenv("WS_URL", "ws://127.0.0.1:6001")  # WebSocket

def send_progress(ws, model_id, status, progress=None, speed=None, error=None):
    msg = {
        "model_id": model_id,
        "status": status,
        "progress": progress,
        "speed": speed,
        "error": error,
        "timestamp": time.time()
    }
    try:
        ws.send(json.dumps(msg))
    except:
        pass

def download_model(model_data, ws):
    model_id = model_data["id"]
    url = model_data["url"]
    model_type = model_data["type"]
    filename = model_data["filename"]
    folder = model_data["dir"]

    dest_dir = Path(COMFYUI_DIR) / "models" / folder
    dest_dir.mkdir(parents=True, exist_ok=True)

    if not filename:
        parsed = urlparse(url)
        filename = os.path.basename(parsed.path.split("?")[0])
        if not filename.endswith((".safetensors", ".pth", ".ckpt")):
            filename = f"{model_id}.safetensors"

    filepath = dest_dir / filename

    headers = {}
    if "civitai.com" in url and CIVITAI_API_KEY:
        headers["Authorization"] = f"Bearer {CIVITAI_API_KEY}"

    try:
        send_progress(ws, model_id, "downloading", 0)

        start_time = time.time()
        response = requests.get(url, headers=headers, stream=True)
        response.raise_for_status()

        total_size = int(response.headers.get('content-length', 0))
        downloaded = 0
        chunk_size = 8192

        with open(filepath, 'wb') as f:
            for chunk in response.iter_content(chunk_size=chunk_size):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    elapsed = time.time() - start_time
                    speed = downloaded / elapsed if elapsed > 0 else 0
                    progress = (downloaded / total_size) * 100 if total_size > 0 else 0

                    if int(elapsed) % 1 == 0:  # Каждую секунду
                        send_progress(ws, model_id, "downloading", round(progress, 1), f"{speed/1024/1024:.1f} MB/s")

        send_progress(ws, model_id, "completed", 100)

        # Перезагрузка ComfyUI
        try:
            requests.post(COMFYUI_URL / "/restart", timeout=2)
            print(f"✅ ComfyUI перезагружена после загрузки {model_id}")
        except:
            print("⚠️ ComfyUI не перезагружена — API недоступно")

    except Exception as e:
        send_progress(ws, model_id, "error", error=str(e))