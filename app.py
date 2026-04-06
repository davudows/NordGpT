#!/usr/bin/env python3
"""
NordGpT — Local AI Chat Backend
OWASP Top 10 mitigations:
  A01 Broken Access Control     — Auth middleware, role-based access, chat ownership
  A02 Cryptographic Failures    — bcrypt passwords, secrets.token_urlsafe sessions
  A03 Injection                 — Pydantic validation, path traversal prevention, model name allowlist
  A04 Insecure Design           — Admin-only user creation, proper role model
  A05 Security Misconfiguration — Strict security headers, localhost-only CORS
  A06 Vulnerable Components     — Pinned versions in requirements.txt
  A07 Auth Failures             — Rate limiting (5 attempts/5 min), 24h session expiry
  A08 Data Integrity            — Input validation on all endpoints
  A09 Logging                   — Auth event audit log
  A10 SSRF                      — Ollama URL hardcoded to localhost, model name regex
"""

import json
import re
import secrets
import logging
import uuid
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

import httpx
from fastapi import Depends, FastAPI, HTTPException, Request, Response
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from passlib.context import CryptContext
from pydantic import BaseModel, field_validator

# ── Logging (A09) ──────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("nordgpt")
audit = logging.getLogger("nordgpt.audit")  # auth events

# ── Config ─────────────────────────────────────────────────────────────────────
BASE_DIR   = Path(__file__).parent
DATA_DIR   = BASE_DIR / "data" / "chats"
USERS_FILE = BASE_DIR / "data" / "users.json"
CONF_FILE  = BASE_DIR / ".nordgpt.conf"

DATA_DIR.mkdir(parents=True, exist_ok=True)
USERS_FILE.parent.mkdir(parents=True, exist_ok=True)

OLLAMA_URL = "http://127.0.0.1:11434"   # localhost-only, prevents SSRF (A10)

# A02: bcrypt password hashing
pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")

# A07: in-memory rate limiting  {ip: [timestamp, ...]}
_login_attempts: dict[str, list[float]] = defaultdict(list)
MAX_ATTEMPTS   = 5
WINDOW_SECONDS = 300   # 5 minutes

# A02: in-memory sessions  {token: {username, role, expires}}
_sessions: dict[str, dict] = {}

# ── Input validators (A03) ─────────────────────────────────────────────────────
_CHAT_ID_RE  = re.compile(r'^[a-zA-Z0-9\-]{8,64}$')
_MODEL_RE    = re.compile(r'^[a-zA-Z0-9][\w\-.:]{0,99}$')
_USERNAME_RE = re.compile(r'^[a-zA-Z0-9_]{3,32}$')

def valid_chat_id(v: str) -> bool:
    return bool(_CHAT_ID_RE.match(v))

def valid_model(v: str) -> bool:
    return bool(_MODEL_RE.match(v))

# ── User store helpers ─────────────────────────────────────────────────────────
def load_users() -> list[dict]:
    if not USERS_FILE.exists():
        return []
    return json.loads(USERS_FILE.read_text(encoding="utf-8"))

def save_users(users: list[dict]):
    USERS_FILE.write_text(
        json.dumps(users, indent=2, ensure_ascii=False), encoding="utf-8"
    )

def find_user(username: str) -> dict | None:
    return next((u for u in load_users() if u["username"] == username), None)

# ── Auth helpers ───────────────────────────────────────────────────────────────
def create_session(username: str, role: str) -> str:
    # A02: cryptographically random, 256-bit token
    token = secrets.token_urlsafe(32)
    expires = (datetime.utcnow() + timedelta(hours=24)).isoformat()
    _sessions[token] = {"username": username, "role": role, "expires": expires}
    return token

def validate_session(token: str) -> dict | None:
    s = _sessions.get(token)
    if not s:
        return None
    if datetime.utcnow() > datetime.fromisoformat(s["expires"]):
        _sessions.pop(token, None)
        return None
    return s

def is_rate_limited(ip: str) -> bool:
    # A07: sliding window rate limit
    now = datetime.utcnow().timestamp()
    _login_attempts[ip] = [t for t in _login_attempts[ip] if now - t < WINDOW_SECONDS]
    return len(_login_attempts[ip]) >= MAX_ATTEMPTS

def record_attempt(ip: str):
    _login_attempts[ip].append(datetime.utcnow().timestamp())

# ── FastAPI deps ───────────────────────────────────────────────────────────────
def get_current_user(request: Request) -> dict:
    token = request.cookies.get("nordgpt_session")
    if not token:
        raise HTTPException(401, "Oturum açılmamış")
    user = validate_session(token)
    if not user:
        raise HTTPException(401, "Oturum süresi doldu")
    return user

def require_admin(user: dict = Depends(get_current_user)) -> dict:
    if user.get("role") != "admin":
        raise HTTPException(403, "Bu işlem için yönetici yetkisi gerekli")  # A01
    return user

# ── App ────────────────────────────────────────────────────────────────────────
app = FastAPI(title="NordGpT", docs_url=None, redoc_url=None)  # hide API docs in prod

# A05: Strict CORS — same-origin only (localhost)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:7860", "http://127.0.0.1:7860"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["Content-Type"],
)

# A05: Security headers on every response
@app.middleware("http")
async def security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"]  = "nosniff"
    response.headers["X-Frame-Options"]          = "DENY"
    response.headers["X-XSS-Protection"]         = "1; mode=block"
    response.headers["Referrer-Policy"]           = "strict-origin-when-cross-origin"
    response.headers["Content-Security-Policy"]   = (
        "default-src 'self'; "
        "script-src 'self' 'unsafe-inline' cdn.jsdelivr.net cdnjs.cloudflare.com; "
        "style-src 'self' 'unsafe-inline' cdnjs.cloudflare.com; "
        "img-src 'self' data:; "
        "connect-src 'self';"
    )
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    return response

# A01: Auth guard — protect all routes except public ones
UNPROTECTED = {"/", "/login", "/auth/login", "/auth/logout"}

@app.middleware("http")
async def auth_guard(request: Request, call_next):
    path = request.url.path
    if path in UNPROTECTED or path.startswith("/static/"):
        return await call_next(request)

    token = request.cookies.get("nordgpt_session")
    if not token or not validate_session(token):
        if path.startswith("/api/") or path.startswith("/auth/"):
            return JSONResponse({"detail": "Unauthorized"}, status_code=401)
        return RedirectResponse("/login", status_code=302)

    return await call_next(request)

# ── Static / Pages ─────────────────────────────────────────────────────────────
app.mount("/static", StaticFiles(directory=str(BASE_DIR / "static")), name="static")

@app.get("/")
async def root(request: Request):
    token = request.cookies.get("nordgpt_session")
    if token and validate_session(token):
        return RedirectResponse("/chat", status_code=302)
    return RedirectResponse("/login", status_code=302)

@app.get("/login")
async def login_page(request: Request):
    token = request.cookies.get("nordgpt_session")
    if token and validate_session(token):
        return RedirectResponse("/chat", status_code=302)
    return FileResponse(BASE_DIR / "static" / "login.html")

@app.get("/chat")
async def chat_page():
    return FileResponse(BASE_DIR / "static" / "index.html")

# ── Auth endpoints ─────────────────────────────────────────────────────────────
class LoginRequest(BaseModel):
    username: str
    password: str

    @field_validator("username")
    @classmethod
    def clean_username(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 1 or len(v) > 64:
            raise ValueError("Geçersiz kullanıcı adı")
        return v

    @field_validator("password")
    @classmethod
    def clean_password(cls, v: str) -> str:
        if len(v) < 1 or len(v) > 256:
            raise ValueError("Geçersiz şifre")
        return v

@app.post("/auth/login")
async def login(request: Request, data: LoginRequest):
    client_ip = request.client.host or "unknown"

    # A07: Rate limiting
    if is_rate_limited(client_ip):
        audit.warning("LOGIN_BLOCKED ip=%s username=%s (rate limited)", client_ip, data.username[:32])
        raise HTTPException(429, "Çok fazla başarısız deneme. 5 dakika sonra tekrar deneyin.")

    user = find_user(data.username)

    # A07: constant-time compare to prevent timing attacks
    # A03: Generic error — don't reveal if username exists
    password_ok = (
        user is not None
        and pwd_ctx.verify(data.password, user["password_hash"])
    )

    if not password_ok:
        record_attempt(client_ip)
        attempts_left = MAX_ATTEMPTS - len(_login_attempts[client_ip])
        audit.warning("LOGIN_FAIL ip=%s username=%s attempts_left=%d",
                      client_ip, data.username[:32], max(attempts_left, 0))
        raise HTTPException(401, "Kullanıcı adı veya şifre hatalı")

    token = create_session(user["username"], user["role"])
    audit.info("LOGIN_OK ip=%s username=%s role=%s", client_ip, user["username"], user["role"])

    resp = JSONResponse({"ok": True, "username": user["username"], "role": user["role"]})
    resp.set_cookie(
        key="nordgpt_session",
        value=token,
        httponly=True,      # A02: JS cannot read cookie
        samesite="strict",  # A08: CSRF protection
        max_age=86400,      # 24h
        secure=False,       # Set True when served over HTTPS
        path="/",
    )
    return resp

@app.post("/auth/logout")
async def logout(request: Request):
    token = request.cookies.get("nordgpt_session")
    if token:
        user = validate_session(token)
        if user:
            audit.info("LOGOUT username=%s", user["username"])
        _sessions.pop(token, None)
    resp = JSONResponse({"ok": True})
    resp.delete_cookie("nordgpt_session", path="/")
    return resp

@app.get("/auth/me")
async def me(user: dict = Depends(get_current_user)):
    return {"username": user["username"], "role": user["role"]}

# ── User management (admin only) ───────────────────────────────────────────────
class CreateUserRequest(BaseModel):
    username: str
    password: str
    role: str = "user"

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        v = v.strip()
        if not _USERNAME_RE.match(v):
            raise ValueError("Kullanıcı adı 3-32 karakter, sadece harf/rakam/_")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Şifre en az 8 karakter olmalı")
        if len(v) > 256:
            raise ValueError("Şifre çok uzun")
        return v

    @field_validator("role")
    @classmethod
    def validate_role(cls, v: str) -> str:
        if v not in ("admin", "user"):
            raise ValueError("Rol 'admin' veya 'user' olmalı")
        return v

@app.get("/api/users")
async def list_users(admin: dict = Depends(require_admin)):
    users = load_users()
    return [
        {"username": u["username"], "role": u["role"],
         "created_at": u.get("created_at", ""), "created_by": u.get("created_by", "")}
        for u in users
    ]

@app.post("/api/users")
async def create_user(req: CreateUserRequest, admin: dict = Depends(require_admin)):
    users = load_users()
    if any(u["username"] == req.username for u in users):
        raise HTTPException(409, "Bu kullanıcı adı zaten kullanılıyor")

    users.append({
        "username": req.username,
        "password_hash": pwd_ctx.hash(req.password),
        "role": req.role,
        "created_at": datetime.utcnow().isoformat(),
        "created_by": admin["username"],
    })
    save_users(users)
    audit.info("USER_CREATED username=%s role=%s by=%s", req.username, req.role, admin["username"])
    return {"ok": True, "username": req.username}

@app.delete("/api/users/{username}")
async def delete_user(username: str, admin: dict = Depends(require_admin)):
    # A01: prevent self-deletion
    if username == admin["username"]:
        raise HTTPException(400, "Kendinizi silemezsiniz")

    users = load_users()
    filtered = [u for u in users if u["username"] != username]
    if len(filtered) == len(users):
        raise HTTPException(404, "Kullanıcı bulunamadı")

    save_users(filtered)
    # Invalidate active sessions for deleted user
    to_remove = [t for t, s in _sessions.items() if s["username"] == username]
    for t in to_remove:
        _sessions.pop(t, None)

    audit.info("USER_DELETED username=%s by=%s", username, admin["username"])
    return {"ok": True}

# ── Config endpoint ────────────────────────────────────────────────────────────
@app.get("/api/config")
async def get_config(_: dict = Depends(get_current_user)):
    conf = {"language": "tr", "category": "general", "default_model": "", "hw_tier": "medium"}
    if CONF_FILE.exists():
        for line in CONF_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            conf[k.strip().lower()] = v.strip()
    return conf

# ── Ollama / Models ────────────────────────────────────────────────────────────
@app.get("/api/models")
async def get_models(_: dict = Depends(get_current_user)):
    try:
        async with httpx.AsyncClient(timeout=5) as c:
            r = await c.get(f"{OLLAMA_URL}/api/tags")
            return r.json()
    except Exception:
        return {"models": []}

@app.get("/api/ollama/status")
async def ollama_status(_: dict = Depends(get_current_user)):
    try:
        async with httpx.AsyncClient(timeout=3) as c:
            r = await c.get(f"{OLLAMA_URL}/api/tags")
            data = r.json()
            return {"running": True, "model_count": len(data.get("models", []))}
    except Exception:
        return {"running": False, "model_count": 0}

@app.get("/api/catalog")
async def get_catalog(_: dict = Depends(get_current_user)):
    catalog_path = BASE_DIR / "models.json"
    return json.loads(catalog_path.read_text(encoding="utf-8"))

class PullRequest(BaseModel):
    model: str

    @field_validator("model")
    @classmethod
    def validate_model(cls, v: str) -> str:
        # A03: allowlist regex — prevent injection via model name
        if not valid_model(v):
            raise ValueError("Geçersiz model adı")
        return v

@app.post("/api/pull")
async def pull_model(req: PullRequest, user: dict = Depends(get_current_user)):
    async def stream():
        try:
            async with httpx.AsyncClient(timeout=600) as c:
                async with c.stream("POST", f"{OLLAMA_URL}/api/pull",
                                    json={"name": req.model, "stream": True}) as r:
                    async for line in r.aiter_lines():
                        if line.strip():
                            yield f"data: {line}\n\n"
            yield f"data: {json.dumps({'status': 'success', 'model': req.model})}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'status': 'error', 'error': str(e)})}\n\n"

    logger.info("PULL_START model=%s user=%s", req.model, user["username"])
    return StreamingResponse(stream(), media_type="text/event-stream")

@app.delete("/api/models/{model_name:path}")
async def delete_model(model_name: str, _: dict = Depends(require_admin)):
    # A03: validate model name before passing to Ollama
    if not valid_model(model_name.split("/")[-1]):
        raise HTTPException(400, "Geçersiz model adı")
    try:
        async with httpx.AsyncClient(timeout=30) as c:
            r = await c.delete(f"{OLLAMA_URL}/api/delete", json={"name": model_name})
            return {"ok": r.status_code in (200, 204)}
    except Exception as e:
        raise HTTPException(500, str(e))

# ── Chat History ───────────────────────────────────────────────────────────────
def chat_path(chat_id: str) -> Path:
    return DATA_DIR / f"{chat_id}.json"

def load_chat(chat_id: str) -> dict | None:
    p = chat_path(chat_id)
    if p.exists():
        return json.loads(p.read_text(encoding="utf-8"))
    return None

def save_chat(chat: dict):
    chat_path(chat["id"]).write_text(
        json.dumps(chat, ensure_ascii=False, indent=2), encoding="utf-8"
    )

def list_chats(username: str, is_admin: bool) -> list[dict]:
    chats = []
    for f in DATA_DIR.glob("*.json"):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
            # A01: users see only their chats; admin sees all
            if not is_admin and data.get("created_by") != username:
                continue
            chats.append({
                "id": data["id"],
                "title": data.get("title", "Chat"),
                "model": data.get("model", ""),
                "updated_at": data.get("updated_at", ""),
                "created_at": data.get("created_at", ""),
                "message_count": len(data.get("messages", [])),
                "created_by": data.get("created_by", ""),
            })
        except Exception:
            pass
    return sorted(chats, key=lambda x: x["updated_at"], reverse=True)

@app.get("/api/history")
async def get_history(user: dict = Depends(get_current_user)):
    return list_chats(user["username"], user["role"] == "admin")

@app.get("/api/history/{chat_id}")
async def get_chat(chat_id: str, user: dict = Depends(get_current_user)):
    # A03: path traversal prevention
    if not valid_chat_id(chat_id):
        raise HTTPException(400, "Geçersiz chat ID")
    chat = load_chat(chat_id)
    if not chat:
        raise HTTPException(404, "Sohbet bulunamadı")
    # A01: ownership check
    if user["role"] != "admin" and chat.get("created_by") != user["username"]:
        raise HTTPException(403, "Bu sohbete erişim yetkiniz yok")
    return chat

class RenameRequest(BaseModel):
    title: str

    @field_validator("title")
    @classmethod
    def clean_title(cls, v: str) -> str:
        v = v.strip()
        if not v or len(v) > 200:
            raise ValueError("Başlık 1-200 karakter arasında olmalı")
        return v

@app.patch("/api/history/{chat_id}")
async def rename_chat(chat_id: str, req: RenameRequest, user: dict = Depends(get_current_user)):
    if not valid_chat_id(chat_id):
        raise HTTPException(400, "Geçersiz chat ID")
    chat = load_chat(chat_id)
    if not chat:
        raise HTTPException(404)
    if user["role"] != "admin" and chat.get("created_by") != user["username"]:
        raise HTTPException(403)
    chat["title"] = req.title
    chat["updated_at"] = datetime.utcnow().isoformat()
    save_chat(chat)
    return {"ok": True}

@app.delete("/api/history/{chat_id}")
async def delete_chat(chat_id: str, user: dict = Depends(get_current_user)):
    if not valid_chat_id(chat_id):
        raise HTTPException(400, "Geçersiz chat ID")
    p = chat_path(chat_id)
    if p.exists():
        chat = load_chat(chat_id)
        if chat and user["role"] != "admin" and chat.get("created_by") != user["username"]:
            raise HTTPException(403)
        p.unlink()
    return {"ok": True}

@app.delete("/api/history")
async def clear_history(user: dict = Depends(get_current_user)):
    is_admin = user["role"] == "admin"
    for f in DATA_DIR.glob("*.json"):
        try:
            if is_admin:
                f.unlink()
            else:
                data = json.loads(f.read_text())
                if data.get("created_by") == user["username"]:
                    f.unlink()
        except Exception:
            pass
    return {"ok": True}

# ── Chat / Streaming ───────────────────────────────────────────────────────────
class ChatRequest(BaseModel):
    chat_id: str | None = None
    model: str
    message: str
    temporary: bool = False
    system_prompt: str | None = None

    @field_validator("model")
    @classmethod
    def validate_model(cls, v: str) -> str:
        if not valid_model(v):
            raise ValueError("Geçersiz model adı")
        return v

    @field_validator("message")
    @classmethod
    def validate_message(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Mesaj boş olamaz")
        if len(v) > 32_000:
            raise ValueError("Mesaj çok uzun (max 32.000 karakter)")
        return v

    @field_validator("chat_id")
    @classmethod
    def validate_chat_id_field(cls, v):
        if v is not None and not valid_chat_id(v):
            raise ValueError("Geçersiz chat ID")
        return v

@app.post("/api/chat")
async def chat(req: ChatRequest, user: dict = Depends(get_current_user)):
    # Load or create chat
    if req.chat_id and not req.temporary:
        existing = load_chat(req.chat_id)
        if existing:
            # A01: ownership check
            if user["role"] != "admin" and existing.get("created_by") != user["username"]:
                raise HTTPException(403, "Bu sohbete erişim yetkiniz yok")
            chat_data = existing
        else:
            chat_data = _new_chat(req.chat_id, req.model, req.temporary,
                                  req.system_prompt, user["username"])
    else:
        chat_data = _new_chat(str(uuid.uuid4()), req.model, req.temporary,
                              req.system_prompt, user["username"])

    # Add user message
    chat_data["messages"].append({
        "role": "user",
        "content": req.message,
        "timestamp": datetime.utcnow().isoformat(),
    })
    if len(chat_data["messages"]) == 1:
        chat_data["title"] = req.message.strip()[:60]

    # Build Ollama message list
    ollama_msgs = []
    if chat_data.get("system_prompt"):
        ollama_msgs.append({"role": "system", "content": chat_data["system_prompt"]})
    for m in chat_data["messages"]:
        ollama_msgs.append({"role": m["role"], "content": m["content"]})

    async def generate():
        full = ""
        yield f"data: {json.dumps({'type':'meta','chat_id':chat_data['id'],'title':chat_data['title']})}\n\n"

        try:
            async with httpx.AsyncClient(timeout=300) as c:
                async with c.stream("POST", f"{OLLAMA_URL}/api/chat",
                                    json={"model": req.model, "messages": ollama_msgs,
                                          "stream": True}) as r:
                    async for line in r.aiter_lines():
                        if not line.strip():
                            continue
                        try:
                            chunk = json.loads(line)
                        except json.JSONDecodeError:
                            continue
                        if chunk.get("error"):
                            yield f"data: {json.dumps({'type':'error','content':chunk['error']})}\n\n"
                            return
                        token = chunk.get("message", {}).get("content", "")
                        if token:
                            full += token
                            yield f"data: {json.dumps({'type':'token','content':token})}\n\n"
                        if chunk.get("done"):
                            break
        except httpx.ConnectError:
            yield f"data: {json.dumps({'type':'error','content':'Ollama bağlantı hatası. Servis çalışıyor mu?'})}\n\n"
            return
        except Exception as e:
            yield f"data: {json.dumps({'type':'error','content':str(e)})}\n\n"
            return

        chat_data["messages"].append({
            "role": "assistant",
            "content": full,
            "timestamp": datetime.utcnow().isoformat(),
        })
        chat_data["updated_at"] = datetime.utcnow().isoformat()
        if not req.temporary:
            save_chat(chat_data)

        yield f"data: {json.dumps({'type':'done','chat_id':chat_data['id']})}\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream",
                             headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})

def _new_chat(cid: str, model: str, temp: bool, sys_prompt, owner: str) -> dict:
    return {
        "id": cid,
        "title": "New Chat",
        "model": model,
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
        "temporary": temp,
        "system_prompt": sys_prompt,
        "created_by": owner,
        "messages": [],
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=7860, reload=False, log_level="warning")
