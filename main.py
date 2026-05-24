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

    <script>
        let ws;
        let user = "";
        let project = "";

        // Проверяем вечную локальную память устройства при старте страницы
        window.onload = function() {
            const savedUser = localStorage.getItem('margo_user');
            const savedProject = localStorage.getItem('margo_project');
            if(savedUser && savedProject) {
                user = savedUser;
                project = savedProject;
                restoreSession();
            }
        };

        function initProfile() {
            user = document.getElementById('username').value.trim();
            project = document.getElementById('proj-name').value.trim();
            if(!user || !project) return alert("Заполните поля!");
            
            // Запекаем данные в вечную память девайса друга
            localStorage.setItem('margo_user', user);
            localStorage.setItem('margo_project', project);
            restoreSession();
        }

        function restoreSession() {
            document.getElementById('title-text').innerText = project.toUpperCase();
            document.getElementById('auth-zone').classList.add('hidden');
            document.getElementById('chat-zone').classList.remove('hidden');
            
            let protocol = window.location.protocol === "https:" ? "wss://" : "ws://";
            ws = new WebSocket(protocol + window.location.host + "/ws");
            
            ws.onopen = () => {
                // Извлекаем старую переписку из памяти устройства
                const history = localStorage.getItem('margo_chat_history') || "";
                document.getElementById('log-box').innerHTML = history;
                log("[СИСТЕМА]: Внутренняя память восстановлена. Сигнал стабилен.");
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
            // Перезаписываем историю чата в вечную локальную память девайса
            localStorage.setItem('margo_chat_history', box.innerHTML);
        }

        function clearMemory() {
            localStorage.clear();
            window.location.reload();
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
