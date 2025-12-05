#!/usr/bin/env bash
# create_and_zip.sh
# Erzeugt das komplette esp32cydkibot-Projektgerüst und packt es als esp32cydkibot.zip
# Usage:
#   chmod +x create_and_zip.sh
#   ./create_and_zip.sh
#
# Ergebnis: ./esp32cydkibot/ (Projekt) und ./esp32cydkibot.zip (zum Hochladen)

set -euo pipefail

ROOT_OUT="$(pwd)/esp32cydkibot"
ZIP_OUT="$(pwd)/esp32cydkibot.zip"

if [ -e "$ROOT_OUT" ]; then
  echo "Error: Zielverzeichnis $ROOT_OUT existiert bereits. Entferne es oder ändere den Pfad."
  exit 1
fi

echo "Erstelle Projekt unter $ROOT_OUT ..."
mkdir -p "$ROOT_OUT"
cd "$ROOT_OUT"

# Direktories
mkdir -p backend/templates backend/static backend/models backend/data
mkdir -p agent
mkdir -p .devcontainer
mkdir -p .github/workflows

# .gitignore
cat > .gitignore <<'EOF'
__pycache__/
.venv/
.env
*.pyc
dist/
build/
*.zip
node_modules/
backend/data/
*.db
EOF

# README.md
cat > README.md <<'EOF'
# esp32cydkibot

ESP32 / CYD Spezialist Chatbot & Generator — FastAPI backend + frontend + local flash agent + SQLite.

Includes:
- backend/ (FastAPI app, templates, models)
- agent/ (local flash agent using esptool)
- .devcontainer/ (VS Code DevContainer)
- docker-compose.yml, CI workflow

Important:
- Set ADMIN_API_KEY before running in a public environment.
- Do not commit secrets (OPENAI API keys, etc.).
EOF

# docker-compose.yml
cat > docker-compose.yml <<'EOF'
version: "3.8"
services:
  backend:
    build:
      context: ./backend
    ports:
      - "8000:8000"
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
      - ADMIN_API_KEY=${ADMIN_API_KEY:-}
      - OPENAI_MODEL=${OPENAI_MODEL:-gpt-4}
      - RATE_LIMIT_MAX=${RATE_LIMIT_MAX:-30}
    volumes:
      - ./backend:/app
      - ./backend/data:/app/data
    depends_on:
      - agent

  agent:
    build:
      context: ./agent
      dockerfile: Dockerfile
    ports:
      - "5001:5001"
    volumes:
      - ./agent:/app
    # Map serial devices here if needed, e.g.:
    # devices:
    #   - "/dev/ttyUSB0:/dev/ttyUSB0"
EOF

# .devcontainer/devcontainer.json
cat > .devcontainer/devcontainer.json <<'EOF'
{
  "name": "ESP32-CYD Bot DevContainer",
  "dockerComposeFile": [
    "../docker-compose.yml"
  ],
  "service": "backend",
  "workspaceFolder": "/workspace",
  "shutdownAction": "stopCompose",
  "runServices": [
    "backend",
    "agent"
  ],
  "forwardPorts": [
    8000,
    5001
  ],
  "containerEnv": {
    "ADMIN_API_KEY": "dev-admin-key-please-change",
    "OPENAI_API_KEY": "",
    "OPENAI_MODEL": "gpt-4",
    "RATE_LIMIT_MAX": "100"
  },
  "postCreateCommand": "/workspace/.devcontainer/postCreate.sh",
  "remoteUser": "vscode",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "ms-azuretools.vscode-docker",
        "ms-python.vscode-pylance",
        "esbenp.prettier-vscode",
        "eamodio.gitlens",
        "ms-vscode-remote.remote-containers"
      ],
      "settings": {
        "python.pythonPath": "/usr/local/bin/python",
        "terminal.integrated.shell.linux": "/bin/bash"
      }
    }
  }
}
EOF

# .devcontainer/postCreate.sh
cat > .devcontainer/postCreate.sh <<'EOF'
#!/usr/bin/env bash
set -e
WORKSPACE="/workspace"
cd "$WORKSPACE"
if [ -f backend/requirements.txt ]; then
  pip install --upgrade pip
  pip install -r backend/requirements.txt
fi
python - <<'PY'
try:
    from db import init_db
    init_db()
    print("Database initialized.")
except Exception as e:
    print("DB initialization failed or already initialized:", e)
PY
mkdir -p backend/data
chmod -R a+rw backend/data || true
echo "Devcontainer postCreate.sh completed."
EOF
chmod +x .devcontainer/postCreate.sh

# GitHub Actions CI
cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  lint-and-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r backend/requirements.txt
          pip install flake8
      - name: Lint
        run: |
          flake8 backend || true
      - name: Build Docker images
        run: |
          docker build -t esp32-cyd-bot -f backend/Dockerfile backend
          docker build -t esp32-cyd-agent -f agent/Dockerfile agent
EOF

# backend/requirements.txt
cat > backend/requirements.txt <<'EOF'
fastapi==0.98.0
uvicorn[standard]==0.23.0
jinja2==3.1.2
python-multipart==0.0.6
aiofiles==23.1.0
requests==2.31.0
openai>=0.27.0
python-dotenv==1.0.0
sqlmodel==0.0.8
sqlalchemy==2.0.21
jinja2-time==0.2.0
python-json-logger==2.0.4
EOF

# backend/Dockerfile
cat > backend/Dockerfile <<'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PYTHONUNBUFFERED=1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# backend/db.py
cat > backend/db.py <<'EOF'
from sqlmodel import SQLModel, create_engine, Session
import os

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./data/app.db")
db_path = DATABASE_URL.replace("sqlite:///", "")
os.makedirs(os.path.dirname(db_path), exist_ok=True)

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})

def init_db():
    from models_db import APIKey, AuditLog
    SQLModel.metadata.create_all(engine)

def get_engine():
    return engine

def get_session():
    with Session(engine) as session:
        yield session
EOF

# backend/models_db.py
cat > backend/models_db.py <<'EOF'
from sqlmodel import SQLModel, Field
from typing import Optional
import time

class APIKey(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    key_id: str = Field(index=True)
    hash: str
    name: Optional[str] = None
    created_at: int = Field(default_factory=lambda: int(time.time()))
    disabled: bool = Field(default=False)

class AuditLog(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    action: str
    details: Optional[str] = None
    created_at: int = Field(default_factory=lambda: int(time.time()))
EOF

# backend/moderation.py
cat > backend/moderation.py <<'EOF'
import openai
import os

BLOCKLIST = [
    "crack", "cracking", "bruteforce", "brute force", "password cracking",
    "password-recovery", "deauth", "deauthenticate", "deauthattack",
    "wpa2-crack", "malware", "ransomware", "exploit", "privilege escalation",
    "rootkit", "backdoor", "keylogger", "ddos", "stresstest"
]

def is_forbidden(text: str) -> bool:
    txt = (text or "").lower()
    for kw in BLOCKLIST:
        if kw in txt:
            return True
    return False

def moderate_with_openai(text: str, api_key: str) -> dict:
    if not api_key:
        return {"blocked": False, "raw": None}
    openai.api_key = api_key
    try:
        resp = openai.Moderation.create(input=text)
        results = resp["results"][0]
        blocked = results.get("flagged", False)
        return {"blocked": bool(blocked), "raw": resp}
    except Exception as e:
        return {"blocked": False, "raw": {"error": str(e)}}
EOF

# backend/generator.py
cat > backend/generator.py <<'EOF'
import os, json
from jinja2 import Environment, FileSystemLoader, select_autoescape

class TemplateGenerator:
    def __init__(self, template_dir="templates", models_file="models/models_extended.json"):
        self.template_dir = template_dir
        self.models_file = models_file
        self.env = Environment(
            loader=FileSystemLoader(searchpath=template_dir),
            autoescape=select_autoescape(enabled_extensions=())
        )
        self._models = {}
        try:
            base = os.path.dirname(os.path.abspath(__file__))
            mf = os.path.join(base, self.models_file)
            if os.path.exists(mf):
                with open(mf, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict) and "models" in data:
                        self._models = data["models"]
                    else:
                        self._models = data
        except Exception:
            self._models = {}

    def render_template(self, template_name: str, params: dict, model_id: str = None) -> str | None:
        try:
            tmpl = self.env.get_template(template_name)
        except Exception:
            return None
        model = None
        if model_id:
            model = self._models.get(model_id)
        ctx = {}
        if isinstance(params, dict):
            ctx.update(params)
        ctx["model"] = model
        return tmpl.render(**ctx)

    def get_output_filename(self, template_name: str) -> str:
        return os.path.basename(template_name)

    def list_templates(self):
        files = []
        for fname in sorted(os.listdir(self.template_dir)):
            path = os.path.join(self.template_dir, fname)
            if os.path.isfile(path):
                desc = ""
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        for _ in range(6):
                            line = f.readline()
                            if not line:
                                break
                            stripped = line.strip()
                            if stripped.startswith("#") or stripped.startswith("//"):
                                desc = desc + stripped.lstrip("#/ ") + " "
                except Exception:
                    desc = ""
                files.append({"name": fname, "description": desc.strip()})
        return files

    def list_models(self):
        ret = []
        for mid, m in sorted(self._models.items(), key=lambda i: i[0]):
            ret.append({
                "id": mid,
                "name": m.get("name"),
                "category": m.get("category"),
                "notes": m.get("notes", "")
            })
        return ret

    def get_model(self, model_id: str):
        if not model_id:
            return None
        return self._models.get(model_id)

    def simple_assist(self, prompt: str) -> str:
        p = prompt.lower()
        if "wifi" in p and "scan" in p:
            return "Nutze das Template 'wifi_scanner_micropython.py' oder wähle ein Modell und benutze das CYD/M5Stack-Template mit use_sd=true."
        if "blink" in p or "led" in p:
            return "Nutze 'esp32_board_init.ino' oder wähle ein Board-Modell und verwende das board-init Template."
        return "Kein LLM konfiguriert. Setze OPENAI_API_KEY, um LLM-Antworten zu erhalten."
EOF

# backend/main.py
cat > backend/main.py <<'EOF'
import os, io, zipfile, logging, time, hashlib, uuid, json
from typing import Optional
from collections import defaultdict

from fastapi import FastAPI, Request, HTTPException, Header, Depends
from fastapi.responses import StreamingResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from generator import TemplateGenerator
from moderation import is_forbidden, moderate_with_openai
from db import init_db, get_engine
from models_db import APIKey, AuditLog
from sqlmodel import Session, select

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("esp32-cyd-bot")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4")
ADMIN_API_KEY = os.getenv("ADMIN_API_KEY", "")
RATE_LIMIT_MAX = int(os.getenv("RATE_LIMIT_MAX", "30"))
RATE_LIMIT_WINDOW = int(os.getenv("RATE_LIMIT_WINDOW", "60"))

app = FastAPI(title="ESP32/CYD Specialist Generator")
app.mount("/", StaticFiles(directory="static", html=True), name="static")

init_db()
engine = get_engine()

gen = TemplateGenerator(template_dir="templates", models_file="models/models_extended.json")

_ip_counters = defaultdict(list)

def hash_key(raw):
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()

def validate_user_key(x_api_key: Optional[str]):
    if not x_api_key:
        return False
    if ADMIN_API_KEY and x_api_key == ADMIN_API_KEY:
        return True
    with Session(engine) as session:
        q = select(APIKey)
        res = session.exec(q).all()
        hx = hash_key(x_api_key)
        for k in res:
            if k.hash == hx and not k.disabled:
                return True
    return False

def require_api_key(x_api_key: Optional[str] = Header(None)):
    if ADMIN_API_KEY:
        if not validate_user_key(x_api_key):
            raise HTTPException(status_code=401, detail="Ungültiger API-Key (X-API-KEY).")
    return True

def require_master_key(x_api_key: Optional[str] = Header(None)):
    if not ADMIN_API_KEY:
        raise HTTPException(status_code=403, detail="No master admin key configured on server.")
    if x_api_key != ADMIN_API_KEY:
        raise HTTPException(status_code=401, detail="Ungültiger Admin Master Key.")
    return True

def check_rate_limit(client_ip: str):
    now = time.time()
    arr = _ip_counters[client_ip]
    while arr and arr[0] <= now - RATE_LIMIT_WINDOW:
        arr.pop(0)
    if len(arr) >= RATE_LIMIT_MAX:
        return False
    arr.append(now)
    return True

class GenerateRequest(BaseModel):
    kind: str
    template: str
    params: dict = {}
    user_confirmed_authorized: bool = False
    model_id: Optional[str] = None

class AskRequest(BaseModel):
    prompt: str

@app.get("/api/health")
def health():
    return {"status": "ok", "openai_configured": bool(OPENAI_API_KEY), "admin_api_key_required": bool(ADMIN_API_KEY), "rate_limit_max": RATE_LIMIT_MAX}

@app.get("/api/templates")
def api_templates(api_ok: bool = Depends(require_api_key)):
    return {"templates": gen.list_templates()}

@app.get("/api/models")
def api_models(api_ok: bool = Depends(require_api_key)):
    return {"models": gen.list_models()}

@app.post("/api/generate")
async def generate(req: GenerateRequest, request: Request, api_ok: bool = Depends(require_api_key)):
    client_ip = request.client.host if request.client else "unknown"
    if not check_rate_limit(client_ip):
        raise HTTPException(status_code=429, detail="Rate limit exceeded")

    combined = " ".join([req.kind, req.template] + [str(v) for v in (req.params or {}).values()])
    if is_forbidden(combined):
        raise HTTPException(status_code=400, detail="Anfrage enthält verbotene oder gefährliche Begriffe und wurde abgelehnt.")

# Truncated: remaining content and templates will be created below in full
EOF

# To avoid an excessively long single cat block for main.py and templates, append the rest
cat >> backend/main.py <<'EOF'
    lower_template = (req.template or "").lower()
    if ("scan" in lower_template or "pentest" in lower_template or "port_scan" in lower_template):
        if not req.user_confirmed_authorized:
            raise HTTPException(status_code=403, detail="Pentest-/Scan-Template verlangt Bestätigung der Autorisierung.")

    if req.model_id and not gen.get_model(req.model_id):
        raise HTTPException(status_code=404, detail="Model nicht gefunden.")

    content = gen.render_template(req.template, req.params or {}, model_id=req.model_id)
    if content is None:
        raise HTTPException(status_code=404, detail="Template nicht gefunden oder Fehler beim Rendern.")

    # Create ZIP in memory
    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        out_name = gen.get_output_filename(req.template)
        zf.writestr(out_name, content)
        if req.model_id:
            model_meta = gen.get_model(req.model_id)
            if model_meta:
                zf.writestr(f"{req.model_id}.model.json", json.dumps(model_meta, indent=2, ensure_ascii=False))
    zip_buffer.seek(0)

    # audit log
    with Session(engine) as session:
        log = AuditLog(action="generate", details=f"template={req.template}, model={req.model_id}")
        session.add(log)
        session.commit()

    headers = {"Content-Disposition": f'attachment; filename="{req.template}.zip"'}
    return StreamingResponse(zip_buffer, media_type="application/zip", headers=headers)

@app.post("/api/ask")
async def ask(req: AskRequest, request: Request, api_ok: bool = Depends(require_api_key)):
    client_ip = request.client.host if request.client else "unknown"
    if not check_rate_limit(client_ip):
        raise HTTPException(status_code=429, detail="Rate limit exceeded")

    prompt = req.prompt or ""
    if is_forbidden(prompt):
        raise HTTPException(status_code=400, detail="Anfrage enthält verbotene Begriffe und wurde abgelehnt.")

    if OPENAI_API_KEY:
        try:
            mod = moderate_with_openai(prompt, OPENAI_API_KEY)
            if mod.get("blocked"):
                raise HTTPException(status_code=400, detail="Inhalt wurde von der Moderation blockiert.")
        except Exception as e:
            logger.warning(f"Moderation failed: {e}")

    if OPENAI_API_KEY:
        import openai
        openai.api_key = OPENAI_API_KEY
        try:
            resp = openai.ChatCompletion.create(
                model=OPENAI_MODEL,
                messages=[{"role": "user", "content": prompt}],
                max_tokens=int(os.getenv("OPENAI_MAX_TOKENS", "800")),
                n=1,
                temperature=float(os.getenv("OPENAI_TEMPERATURE", "0.2")),
            )
            answer = resp.choices[0].message["content"].strip()
            # audit
            with Session(engine) as session:
                log = AuditLog(action="ask", details=f"prompt_len={len(prompt)}")
                session.add(log)
                session.commit()
            return {"status": "ok", "answer": answer}
        except Exception as e:
            logger.error(f"LLM call failed: {e}")
            return {"status": "error", "message": f"LLM-Aufruf fehlgeschlagen: {e}"}
    else:
        return {"status": "ok", "answer": gen.simple_assist(prompt)}

# Admin key management
@app.post("/api/admin/generate_key")
def admin_generate_key(name: Optional[str] = None, admin_ok: bool = Depends(require_master_key)):
    raw = str(uuid.uuid4())
    kid = str(uuid.uuid4())
    hx = hash_key(raw)
    with Session(engine) as session:
        entry = APIKey(key_id=kid, hash=hx, name=name or "")
        session.add(entry)
        session.commit()
    return {"id": kid, "key": raw, "note": "Save this raw key now — it will not be shown again."}

@app.get("/api/admin/keys")
def admin_list_keys(admin_ok: bool = Depends(require_master_key)):
    with Session(engine) as session:
        keys = session.exec(select(APIKey)).all()
        out = [{"id": k.key_id, "name": k.name, "created_at": k.created_at, "disabled": k.disabled} for k in keys]
    return {"keys": out}

@app.delete("/api/admin/keys/{key_id}")
def admin_delete_key(key_id: str, admin_ok: bool = Depends(require_master_key)):
    with Session(engine) as session:
        q = select(APIKey).where(APIKey.key_id == key_id)
        res = session.exec(q).first()
        if not res:
            raise HTTPException(status_code=404, detail="Key not found")
        session.delete(res)
        session.commit()
    return {"status": "deleted", "id": key_id}
EOF

# models json (valid, small sample; you can replace with generated large file later)
cat > backend/models/models_extended.json <<'EOF'
{
  "meta": {
    "generated_at": "2025-12-04T00:00:00Z",
    "count": 2
  },
  "models": {
    "esp32-wroom-v0": {
      "id": "esp32-wroom-v0",
      "name": "ESP32-WROOM (Generic)",
      "category": "esp32",
      "cpu": "Xtensa Dual-Core",
      "flash": "4MB",
      "default_pins": {
        "led_pin": 2,
        "sd_cs": 5,
        "i2c_sda": 21,
        "i2c_scl": 22
      },
      "notes": ""
    },
    "m5stack-core2-v0": {
      "id": "m5stack-core2-v0",
      "name": "M5Stack Core2",
      "category": "m5stack",
      "cpu": "ESP32",
      "flash": "16MB",
      "default_pins": {
        "led_pin": 10,
        "sd_cs": 4,
        "i2c_sda": 21,
        "i2c_scl": 22
      },
      "notes": "Core2 with touch display"
    }
  }
}
EOF

# templates
cat > backend/templates/wifi_scanner_micropython.py <<'EOF'
# MicroPython WiFi-Scanner (ESP32)
# Speichert erkannte SSIDs in /sd/ssids.txt (SD-Karte) oder /ssids.txt (SPIFFS)
# Hinweis: Nur für legale, autorisierte Nutzung. Keine Angriffe oder Passwort-Cracking.

import network
import time

USE_SD = {{ use_sd | default(False) }}
OUT_PATH = "{{ out_path | default('/ssids.txt') }}"

def scan_and_save():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    time.sleep(1)
    nets = wlan.scan()
    ssids = []
    for net in nets:
        try:
            ssid = net[0].decode('utf-8')
        except:
            ssid = str(net[0])
        ssids.append(ssid)
    try:
        path = OUT_PATH
        if USE_SD:
            path = "/sd/ssids.txt"
        with open(path, "w") as f:
            for s in ssids:
                f.write(s + "\n")
        print("Scan done. Saved to", path)
    except Exception as e:
        print("Error saving file:", e)

if __name__ == "__main__":
    scan_and_save()
EOF

cat > backend/templates/esp32_board_init.ino <<'EOF'
// ESP32 Board Init (Arduino)
// Model: {{ model.name if model else "generic" }}

const int PIN_LED = {{ (model.default_pins.led_pin if model and model.default_pins else pin_led) | default(2) }};

void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED, OUTPUT);
  Serial.println("Board init for {{ model.name if model else 'ESP32' }}");
  digitalWrite(PIN_LED, LOW);
}

void loop() {
  digitalWrite(PIN_LED, HIGH);
  delay({{ on_ms | default(500) }});
  digitalWrite(PIN_LED, LOW);
  delay({{ off_ms | default(500) }});
}
EOF

cat > backend/templates/cyd_basic_micropython.py <<'EOF'
# CYD Basic MicroPython Template
# Model: {{ model.name if model else "CYD Generic" }}

import machine
import time

LED_PIN = {{ (model.default_pins.led_pin if model and model.default_pins else led_pin) | default(2) }}
USE_SD = {{ use_sd | default(False) }}

led = machine.Pin(LED_PIN, machine.Pin.OUT)

def blink(times=3, ms=200):
    for _ in range(times):
        led.on()
        time.sleep_ms(ms)
        led.off()
        time.sleep_ms(ms)

def init_sd():
    if not USE_SD:
        print("SD disabled by config.")
        return False
    try:
        import sdcard, os, machine
        spi = machine.SPI(1)
        cs_pin = {{ (model.default_pins.sd_cs if model and model.default_pins and model.default_pins.sd_cs else sd_cs) | default(15) }}
        cs = machine.Pin(cs_pin)
        sd = sdcard.SDCard(spi, cs)
        os.mount(sd, "/sd")
        print("SD mounted at /sd")
        return True
    except Exception as e:
        print("SD init failed:", e)
        return False

if __name__ == "__main__":
    print("CYD Basic Boot for {{ model.name if model else 'generic' }}")
    blink(2, 150)
    if USE_SD:
        init_sd()
EOF

# static files
cat > backend/static/index.html <<'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <title>ESP32 / CYD Spezialist - Generator</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; max-width:1000px; }
    label { display:block; margin-top:8px; font-weight:600; }
    input, select, textarea { width: 100%; padding:8px; margin-top:4px; box-sizing:border-box; }
    button { margin-top:12px; padding:10px 18px; }
    .row { display:flex; gap:12px; }
    .col { flex:1; }
    pre { background:#f3f3f3; padding:12px; overflow:auto; }
    .small { font-size:0.9em; color:#666; }
    #preview { white-space: pre; max-height: 400px; overflow:auto; border:1px solid #ddd; padding:8px; background:#111; color:#ddd; font-family: monospace;}
  </style>
</head>
<body>
  <h1>ESP32 / CYD Spezialist - Generator</h1>
  <p class="small">Wähle ein Modell und ein Template, gib Parameter als JSON an und lade die generierte Datei (ZIP) herunter. Aktiviere die Checkbox bei autorisierten Pentest-Templates.</p>

  <label for="model">Modell</label>
  <select id="model"><option value="">-- kein Modell --</option></select>

  <label for="template">Template</label>
  <select id="template"></select>

  <label for="params">Parameter als JSON</label>
  <textarea id="params" rows="6">{}</textarea>

  <label><input type="checkbox" id="confirm"> Ich bestätige, dass ich autorisiert bin, Pentest-Templates zu verwenden</label>

  <div class="row">
    <div class="col"><button id="generate">Generieren & Herunterladen</button></div>
    <div class="col"><button id="previewBtn">Vorschau</button></div>
    <div class="col"><button id="refresh">Vorlagen aktualisieren</button></div>
  </div>

  <h3>Vorschau</h3>
  <pre id="preview">Preview anzeigen...</pre>

  <h3>Log / Status</h3>
  <pre id="log">Ready</pre>

<script src="app.js"></script>
</body>
</html>
EOF

cat > backend/static/app.js <<'EOF'
(async function(){
  const logEl = document.getElementById("log");
  const templateSelect = document.getElementById("template");
  const paramsEl = document.getElementById("params");
  const confirmEl = document.getElementById("confirm");
  const generateBtn = document.getElementById("generate");
  const refreshBtn = document.getElementById("refresh");
  const modelSelect = document.getElementById("model");
  const preview = document.getElementById("preview");
  const previewBtn = document.getElementById("previewBtn");

  function log(msg){ logEl.textContent = msg; console.log(msg); }

  async function loadTemplates(){
    log("Lade Templates...");
    const resp = await fetch("/api/templates", { method: "GET", headers: {'X-API-KEY': sessionStorage.getItem('api_key') || ""}});
    if (!resp.ok){ log("Fehler beim Laden der Templates: " + await resp.text()); return; }
    const data = await resp.json();
    templateSelect.innerHTML = "";
    data.templates.forEach(t=>{
      const o = document.createElement("option");
      o.value = t.name;
      o.textContent = `${t.name} ${t.description ? "- " + t.description : ""}`;
      templateSelect.appendChild(o);
    });
    log("Templates geladen.");
  }

  async function loadModels(){
    log("Lade Modelle...");
    const resp = await fetch("/api/models", { method: "GET", headers: {'X-API-KEY': sessionStorage.getItem('api_key') || ""}});
    if (!resp.ok){ log("Fehler beim Laden der Modelle: " + await resp.text()); return; }
    const data = await resp.json();
    modelSelect.innerHTML = "<option value=''>-- kein Modell --</option>";
    data.models.forEach(m=>{
      const o = document.createElement("option");
      o.value = m.id;
      o.textContent = `${m.id} - ${m.name}`;
      modelSelect.appendChild(o);
    });
    log("Modelle geladen.");
  }

  generateBtn.addEventListener("click", async () => {
    const apiKey = sessionStorage.getItem('api_key') || prompt("API-Key (X-API-KEY):");
    if (!apiKey) return;
    sessionStorage.setItem('api_key', apiKey);

    let template = templateSelect.value;
    let params = {};
    try { params = JSON.parse(paramsEl.value || "{}"); } catch(e){ alert("Ungültiges JSON"); return; }
    const payload = {
      kind: "template",
      template,
      params,
      user_confirmed_authorized: confirmEl.checked,
      model_id: modelSelect.value || null
    };
    log("Sende Generierungs-Anfrage...");
    try {
      const resp = await fetch("/api/generate", {
        method: "POST",
        headers: {'Content-Type': 'application/json', 'X-API-KEY': apiKey},
        body: JSON.stringify(payload)
      });
      if (!resp.ok){
        const j = await resp.json().catch(()=>null);
        log("Fehler: " + (j?.detail || JSON.stringify(j) || await resp.text()));
        return;
      }
      const blob = await resp.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = template + ".zip";
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
      log("Download gestartet: " + template + ".zip");
    } catch (e){
      log("Fehler beim Generieren: " + e);
    }
  });

  previewBtn.addEventListener("click", async ()=>{
    let template = templateSelect.value;
    let params = {};
    try { params = JSON.parse(paramsEl.value || "{}"); } catch(e){ alert("Ungültiges JSON"); return; }
    preview.textContent = "Preview is not implemented server-side in this minimal app. Use Generate to download and inspect the file.";
  });

  refreshBtn.addEventListener("click", async () => {
    await Promise.all([loadModels(), loadTemplates()]);
  });

  await Promise.all([loadModels(), loadTemplates()]);
})();
EOF

# admin.html
cat > backend/static/admin.html <<'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <title>Admin - API Key Management</title>
  <style>
    body { font-family: Arial, sans-serif; max-width:900px; margin:24px; }
    input, button { padding:8px; margin:6px 0; width:100%; box-sizing:border-box; }
    table { width:100%; border-collapse:collapse; margin-top:12px; }
    th,td { border:1px solid #ddd; padding:8px; }
  </style>
</head>
<body>
  <h1>Admin - API Key Management</h1>
  <p>Gib deinen MASTER ADMIN KEY (X-API-KEY) ein, um Keys zu verwalten.</p>

  <label>Admin Master Key</label>
  <input id="adminkey" placeholder="MASTER ADMIN KEY">

  <label>Key-Name (optional)</label>
  <input id="keyname" placeholder="z.B. deploy-key">

  <button id="gen">Generate API Key</button>

  <h3>Existing Keys</h3>
  <div id="keys">Lade...</div>

<script>
function headers(){
  const adminKey = document.getElementById('adminkey').value;
  return {"X-API-KEY": adminKey, "Content-Type": "application/json"};
}

async function loadKeys(){
  try {
    const resp = await fetch("/api/admin/keys", { headers: headers() });
    if (!resp.ok) { document.getElementById('keys').innerText = 'Error: ' + await resp.text(); return; }
    const j = await resp.json();
    const container = document.getElementById('keys');
    container.innerHTML = '';
    const table = document.createElement('table');
    table.innerHTML = '<tr><th>ID</th><th>Name</th><th>Created</th><th>Disabled</th><th>Action</th></tr>';
    j.keys.forEach(k=>{
      const tr = document.createElement('tr');
      const created = new Date(k.created_at * 1000).toLocaleString();
      tr.innerHTML = `<td>${k.id}</td><td>${k.name}</td><td>${created}</td><td>${k.disabled}</td><td><button data-id="${k.id}">Delete</button></td>`;
      table.appendChild(tr);
    });
    container.appendChild(table);
    container.querySelectorAll('button[data-id]').forEach(b=>{
      b.addEventListener('click', async (e)=>{
        const id = e.target.getAttribute('data-id');
        if (!confirm('Delete key ' + id + '?')) return;
        const resp = await fetch('/api/admin/keys/' + id, { method: 'DELETE', headers: headers() });
        if (resp.ok) { loadKeys(); } else { alert('Error: ' + await resp.text()); }
      });
    });
  } catch (e) { document.getElementById('keys').innerText = 'Error: ' + e; }
}

document.getElementById('gen').addEventListener('click', async ()=>{
  try {
    const name = document.getElementById('keyname').value || '';
    const resp = await fetch('/api/admin/generate_key?name=' + encodeURIComponent(name), { method: 'POST', headers: headers() });
    if (!resp.ok) { alert('Error: ' + await resp.text()); return; }
    const j = await resp.json();
    alert('New Key (save now):\nID: ' + j.id + '\nKEY: ' + j.key);
    loadKeys();
  } catch (e) { alert('Error: ' + e); }
});

</script>
</body>
</html>
EOF

# agent
cat > agent/requirements.txt <<'EOF'
Flask==2.2.5
flask-cors==3.0.10
pyserial==3.5
esptool==3.3
EOF

cat > agent/agent.py <<'EOF'
from flask import Flask, request, jsonify
from flask_cors import CORS
import subprocess, tempfile, os

app = Flask(__name__)
CORS(app, origins=["http://localhost:8000", "http://127.0.0.1:8000"])

@app.route("/flash", methods=["POST"])
def flash():
    if 'binfile' not in request.files:
        return jsonify({"error": "no file provided"}), 400
    f = request.files['binfile']
    port = request.form.get('port', '/dev/ttyUSB0')
    baud = request.form.get('baud', '115200')
    tmp = tempfile.NamedTemporaryFile(delete=False)
    try:
        f.save(tmp.name)
        tmp.flush()
        cmd = ["esptool.py", "--chip", "esp32", "--port", port, "--baud", baud, "write_flash", "-z", "0x1000", tmp.name]
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        return jsonify({"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr})
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        try:
            tmp.close()
            os.unlink(tmp.name)
        except Exception:
            pass

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
EOF

cat > agent/Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "agent.py"]
EOF

cat > agent/README.md <<'EOF'
Agent: Local flash agent using esptool.
Run locally:
  python agent.py
POST /flash with multipart form:
  binfile=@firmware.bin  port=/dev/ttyUSB0  baud=115200
EOF

# small helper docs
cat > backend/README_EXAMPLE.md <<'EOF'
Quick start (backend):
1. create virtualenv:
   python -m venv .venv
   source .venv/bin/activate
2. pip install -r requirements.txt
3. export ADMIN_API_KEY="your-secret"
4. uvicorn main:app --reload --host 0.0.0.0 --port 8000
EOF

# initialize git (local)
echo "Initialisiere lokalen git-Repo..."
git init >/dev/null
git add . >/dev/null
git commit -m "Initial commit: esp32cydkibot scaffold" >/dev/null || true

# create zip
echo "Erstelle ZIP: $ZIP_OUT ..."
# go up one dir to create zip with top-level folder name
cd ..
zip -r "$(basename "$ZIP_OUT")" "$(basename "$ROOT_OUT")" >/dev/null

echo "Fertig. ZIP-Datei erstellt: $ZIP_OUT"
echo ""
echo "Nun kannst du die ZIP-Datei manuell auf GitHub hochladen (Repository: psytec1x/esp32cydkibot)."
echo "Wenn du das Repo per HTTPS bereits als remote gesetzt hast, kannst du alternativ die lokalen Dateien pushen."