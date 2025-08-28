let ws = new WebSocket("ws://localhost:6001");

ws.onmessage = function (event) {
  const data = JSON.parse(event.data);
  const bar = document.getElementById(`progress-${data.model_id}`);
  const status = document.getElementById(`status-${data.model_id}`);

  if (data.status === "downloading") {
    bar.style.width = `${data.progress}%`;
    status.textContent = `Загрузка: ${data.progress.toFixed(1)}% (${data.speed})`;
  } else if (data.status === "completed") {
    bar.style.width = "100%";
    status.textContent = "Готово! ComfyUI перезагружается...";
    setTimeout(() => location.reload(), 2000);
  } else if (data.status === "error") {
    status.innerHTML = `<span style="color:red">Ошибка: ${data.error}</span>`;
    document.getElementById(`btn-${data.model_id}`).textContent = "Повторить";
  }
};

function downloadModel(id) {
  const btn = document.getElementById(`btn-${id}`);
  btn.disabled = true;
  btn.textContent = "Загружается...";
  ws.send(JSON.stringify({ model_id: id }));
}
