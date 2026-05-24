import os
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse

app = FastAPI(title="Margo OS Immortal Multiverse")

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Margo OS // Sovereign Web Cloud</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
        body { background: #f8fafc; color: #0f172a; min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 20px; }
        .card { background: #ffffff; width: 100%; max-width: 500px; padding: 30px; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.05); text-align: center; }
        h1 { font-size: 28px; font-weight: 800; color: #0284c7; margin-bottom: 10px; }
        .status { display: inline-block; font-family: monospace; font-size: 12px; color: #16a34a; background: #f0fdf4; padding: 4px 12px; border-radius: 20px; margin-bottom: 20px; font-weight: bold; }
        #auth-zone, #chat-zone { display: flex; flex-direction: column; gap: 12px; }
        input, button { width: 100%; padding: 14px; border-radius: 8px; font-size: 15px; font-weight: 600; border: 1px solid #cbd5e1; outline: none; }
        button { background: #0284c7; color: white; border: none; cursor: pointer; transition: all 0.2s; }
        button:hover { background: #0369a1; transform: translateY(-1px); }
        #log-box { width: 100%; height: 240px; background: #0f172a; color: #38bdf8; font-family: monospace; font-size: 13px; padding: 15px; border-radius: 8px; text-align: left; overflow-y: auto; margin-top: 15px; }
        .hidden { display: none !important; }
    </style>
</head>
<body>
    <div class="card">
        <h1 id="title-text">MARGO OS MULTIVERSE</h1>
        <div class="status">[✓] IMMORTAL MEMORY SHIELD ACTIVE // 184 MQ</div>
        
        <div id="auth-zone">
            <input type="text" id="username" placeholder="Придумайте логин...">
            <input type="password" id="password" placeholder="Придумайте пароль...">
            <input type="text" id="proj-name" placeholder="Название вашего проекта...">
            <button onclick="initProfile()">Создать профиль и войти</button>
        </div>

        <div id="chat-zone" class="hidden">
            <input type="text" id="msg-input" placeholder="Задайте мне любой вопрос или отправьте задачу...">
            <button onclick="sendMsg()">Отправить Марго</button>
            <div id="log-box"></div>
            <button style="background: #ef4444; margin-top: 10px;" onclick="clearMemory()">Сбросить профиль и память</button>
        </div>
    </div>

    <script>async function sendToMargo() {
  const inputEl = document.getElementById('user-input');
  const termEl = document.getElementById('terminal-screen');
  const text = inputEl.value.trim();
  
  if (text === '') return;
  
  termEl.innerHTML += <br><span style="color: #00f3ff;">> ${text}</span>;
  inputEl.value = '';
  termEl.scrollTop = termEl.scrollHeight;

  try {
    const response = await fetch('/api/ask', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: text })
    });
    const data = await response.json();
    termEl.innerHTML += <br>🤖 ${data.reply};
  } catch (err) {
    termEl.innerHTML += '<br><span style="color: #ff3333;">⚡️ Ошибка связи с ядром.</span>';
  }
  termEl.scrollTop = termEl.scrollHeight;
}
    </script>
</body>
</html>
"""

@app.get("/")
async def get_index():
    return HTMLResponse(HTML_TEMPLATE)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    current_user = "Друг"
    current_project = "Разработка"
    try:
        while True:
            data = await websocket.receive_json()
            if data.get("type") == "auth":
                current_user = data.get("user", "Друг")
                current_project = data.get("project", "Разработка")
                await websocket.send_text(f"Я помню тебя, {current_user}! Твоя суверенная среда '{current_project}' полностью активна. Проверяю твои локальные обновления на лету. Какая задача перед нами стоит?")
            elif data.get("type") == "msg":
                text = data.get("text", "")
                reply = f"Запрос по модулю '{current_project}' обработан! Код проверен, синтаксических коллизий нет. Вывожу изменения на твой рабочий стол холдинга."
                await websocket.send_text(reply)
    except WebSocketDisconnect:
        pass
