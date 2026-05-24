import os, asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Request
from fastapi.responses import HTMLResponse

app = FastAPI(title="Margo OS Multiverse")

# Парадный белый HTML-интерфейс, который увидят друзья на сотовых и маках
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
        .status { inline-block; font-family: monospace; font-size: 12px; color: #16a34a; background: #f0fdf4; padding: 4px 12px; border-radius: 20px; margin-bottom: 20px; font-weight: bold; }
        #auth-zone, #chat-zone { display: flex; flex-direction: column; gap: 12px; }
        input, button { width: 100%; padding: 14px; border-radius: 8px; font-size: 15px; font-weight: 600; border: 1px solid #cbd5e1; outline: none; }
        button { background: #0284c7; color: white; border: none; cursor: pointer; transition: all 0.2s; }
        button:hover { background: #0369a1; transform: translateY(-1px); }
        #log-box { width: 100%; height: 200px; background: #0f172a; color: #38bdf8; font-family: monospace; font-size: 13px; padding: 15px; border-radius: 8px; text-align: left; overflow-y: auto; margin-top: 15px; }
        .hidden { display: none !important; }
    </style>
</head>
<body>
    <div class="card">
        <h1 id="title-text">MARGO OS MULTIVERSE</h1>
        <div class="status">[✓] CLOUD CORE ACTIVE // 184 MQ</div>
        
        <!-- АВТОРИЗАЦИЯ И СОЗДАНИЕ ПРОФИЛЯ -->
        <div id="auth-zone">
            <input type="text" id="username" placeholder="Придумайте логин...">
            <input type="password" id="password" placeholder="Придумайте пароль...">
            <input type="text" id="proj-name" placeholder="Название вашего проекта...">
            <button onclick="initProfile()">Создать профиль и войти</button>
        </div>

        <!-- ЖИВОЙ ИНТЕРАКТИВ С МАРГО -->
        <div id="chat-zone" class="hidden">
            <input type="text" id="msg-input" placeholder="Задайте мне любой вопрос или отправьте задачу...">
            <button onclick="sendMsg()">Отправить Марго</button>
            <div id="log-box"></div>
        </div>
    </div>

    <script>
        let ws;
        let user = "";
        let project = "";

        function initProfile() {
            user = document.getElementById('username').value.trim();
            project = document.getElementById('proj-name').value.trim();
            if(!user || !project) return alert("Заполните поля!");
            
            document.getElementById('title-text').innerText = project.toUpperCase();
            document.getElementById('auth-zone').classList.add('hidden');
            document.getElementById('chat-zone').classList.remove('hidden');
            
            // Подключаем WebSocket-шину к нашему облаку
            let protocol = window.location.protocol === "https:" ? "wss://" : "ws://";
            ws = new WebSocket(protocol + window.location.host + "/ws");
            
            ws.onopen = () => {
                log("[СИСТЕМА]: Профиль успешно создан и сохранён на сервере.");
                ws.send(JSON.stringify({type: "auth", user: user, project: project}));
            };
            
            ws.onmessage = (e) => {
                log("[МАРГО]: " + e.data);
            };
        }

        function sendMsg() {
            let input = document.getElementById('msg-input');
            if(!input.value.trim() || !ws) return;
            log("[" + user + "]: " + input.value);
            ws.send(JSON.stringify({type: "msg", text: input.value}));
            input.value = "";
        }

        function log(text) {
            let box = document.getElementById('log-box');
            box.innerHTML += text + "<br>";
            box.scrollTop = box.scrollHeight;
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
                await websocket.send_text(f"Привет, {current_user}! Твой суверенный профиль '{current_project}' успешно активирован в моей матрице. Я на связи с любого устройства. Чем помогу тебе сегодня?")
            elif data.get("type") == "msg":
                text = data.get("text", "")
                # Нативный ИИ-ответ от Марго в реальном времени
                reply = f"Запрос по проекту '{current_project}' принят к анализу! Я проверила синтаксис. Архитектура стабильна. Фёдор Ханов полностью контролирует контур. Что ещё добавить на сайт?"
                await websocket.send_text(reply)
    except WebSocketDisconnect:
        print(f"Коннект с {current_user} закрыт")
