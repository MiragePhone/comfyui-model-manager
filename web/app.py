import os
import json
import threading
from flask import Flask, render_template
from flask_socketio import SocketIO
from download_worker import download_model

# Загрузка
os.environ['FLASK_ENV'] = 'development'
app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

# Конфиг
with open('models_config.json', 'r') as f:
    MODEL_CONFIG = json.load(f)

MODELS_MAP = {}
for mtype, models in MODEL_CONFIG.items():
    for m in models:
        m["type"] = mtype
        MODELS_MAP[m["id"]] = m

# Главная страница
@app.route('/')
def index():
    return render_template('index.html')

@socketio.on('download')
def handle_download(data):
    model_id = data['model_id']
    model = MODELS_MAP.get(model_id)
    if not model:
        socketio.emit('progress', {'error': 'Model not found'})
        return

    def run():
        download_model(model, socketio)

    thread = threading.Thread(target=run)
    thread.start()

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=6001)