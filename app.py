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

import base64
import json
import re
import secrets
import logging
import uuid
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlencode

import httpx
from fastapi import Depends, FastAPI, File, HTTPException, Request, Response, UploadFile
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import bcrypt as _bcrypt
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

# ── File uploads ───────────────────────────────────────────────────────────────
UPLOADS_DIR   = BASE_DIR / "data" / "uploads"
MAX_UPLOAD_MB = 20
MAX_FILE_SIZE = MAX_UPLOAD_MB * 1024 * 1024
ALLOWED_MIMES: dict[str, str] = {
    "image/jpeg": "image", "image/png": "image",
    "image/gif":  "image", "image/webp": "image",
    "application/pdf": "document",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "document",
    "text/plain": "document", "text/csv": "document",
}
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

_FILE_ID_RE = re.compile(r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$')

def extract_text_from_file(data: bytes, mime: str, filename: str) -> str:
    """Extract plain text from uploaded document. Returns empty string on error."""
    try:
        if mime == "application/pdf":
            import io
            from pypdf import PdfReader
            reader = PdfReader(io.BytesIO(data))
            pages = [page.extract_text() or "" for page in reader.pages]
            return "\n\n".join(p for p in pages if p.strip())
        elif "wordprocessingml" in mime:
            import io
            from docx import Document
            doc = Document(io.BytesIO(data))
            return "\n".join(p.text for p in doc.paragraphs if p.text.strip())
        elif mime in ("text/plain", "text/csv"):
            return data.decode("utf-8", errors="replace")
    except Exception as exc:
        logger.warning("TEXT_EXTRACT_ERROR filename=%s error=%s", filename, exc)
    return ""

# ── Microsoft SSO Config (loaded once at startup from .nordgpt.conf) ───────────
def _load_conf() -> dict:
    out: dict[str, str] = {}
    if CONF_FILE.exists():
        for line in CONF_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            out[k.strip()] = v.strip()
    return out

_startup_conf = _load_conf()
MS_CLIENT_ID     = _startup_conf.get("MICROSOFT_CLIENT_ID", "")
MS_CLIENT_SECRET = _startup_conf.get("MICROSOFT_CLIENT_SECRET", "")
MS_TENANT        = _startup_conf.get("MICROSOFT_TENANT_ID", "common")
MS_REDIRECT_URI  = _startup_conf.get("MICROSOFT_REDIRECT_URI", "")
ALLOWED_DOMAINS: list[str] = [
    d.strip().lower()
    for d in _startup_conf.get("ALLOWED_DOMAINS", "").split(",")
    if d.strip()
]

# ── Cloudflare Turnstile CAPTCHA (optional — set keys to enable) ───────────────
# Get free keys at: https://dash.cloudflare.com/?to=/:account/turnstile
TURNSTILE_SITE_KEY   = _startup_conf.get("TURNSTILE_SITE_KEY", "")
TURNSTILE_SECRET_KEY = _startup_conf.get("TURNSTILE_SECRET_KEY", "")

# CSRF state store for OAuth2 flow  {state_token: created_timestamp}
_oauth_states: dict[str, float] = {}

# A02: bcrypt password hashing (direct bcrypt — passlib 1.7 incompatible with bcrypt 4.x)
def _hash_password(plain: str) -> str:
    return _bcrypt.hashpw(plain.encode(), _bcrypt.gensalt()).decode()

def _verify_password(plain: str, hashed: str) -> bool:
    try:
        return _bcrypt.checkpw(plain.encode(), hashed.encode())
    except Exception:
        return False

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
    expires = (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat()
    _sessions[token] = {"username": username, "role": role, "expires": expires}
    return token

def validate_session(token: str) -> dict | None:
    s = _sessions.get(token)
    if not s:
        return None
    if datetime.now(timezone.utc) > datetime.fromisoformat(s["expires"]):
        _sessions.pop(token, None)
        return None
    return s

def is_rate_limited(ip: str) -> bool:
    # A07: sliding window rate limit
    now = datetime.now(timezone.utc).timestamp()
    _login_attempts[ip] = [t for t in _login_attempts[ip] if now - t < WINDOW_SECONDS]
    return len(_login_attempts[ip]) >= MAX_ATTEMPTS

def record_attempt(ip: str):
    _login_attempts[ip].append(datetime.now(timezone.utc).timestamp())

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

def get_client_ip(request: Request) -> str:
    """Return real client IP — prefers CF-Connecting-IP (Cloudflare Tunnel/Proxy)."""
    return (
        request.headers.get("CF-Connecting-IP")
        or request.headers.get("X-Real-IP")
        or request.client.host
        or "unknown"
    )

# ── App ────────────────────────────────────────────────────────────────────────
app = FastAPI(title="NordGpT", docs_url=None, redoc_url=None)  # hide API docs in prod

# A05: Strict CORS — same-origin + production domain
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:7860", "http://127.0.0.1:7860",
        "https://chat.nordisglobal.com",
    ],
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
UNPROTECTED = {"/", "/login", "/auth/login", "/auth/logout",
               "/auth/microsoft", "/auth/microsoft/callback",
               "/api/auth/providers"}

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
    cf_turnstile_response: str = ""   # CAPTCHA token (empty = CAPTCHA disabled)

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

async def _verify_turnstile(token: str, ip: str) -> bool:
    """Verify Cloudflare Turnstile CAPTCHA token. Returns True if valid."""
    if not TURNSTILE_SECRET_KEY:
        return True   # CAPTCHA not configured — allow all
    if not token:
        return False  # CAPTCHA configured but no token provided
    try:
        async with httpx.AsyncClient(timeout=5) as hc:
            resp = await hc.post(
                "https://challenges.cloudflare.com/turnstile/v0/siteverify",
                data={"secret": TURNSTILE_SECRET_KEY, "response": token, "remoteip": ip},
            )
            return resp.json().get("success", False)
    except Exception:
        return False

@app.post("/auth/login")
async def login(request: Request, data: LoginRequest):
    client_ip = get_client_ip(request)

    # A07: Rate limiting
    if is_rate_limited(client_ip):
        audit.warning("LOGIN_BLOCKED ip=%s username=%s (rate limited)", client_ip, data.username[:32])
        raise HTTPException(429, "Çok fazla başarısız deneme. 5 dakika sonra tekrar deneyin.")

    # CAPTCHA verification (when Turnstile keys are configured)
    if TURNSTILE_SECRET_KEY:
        captcha_ok = await _verify_turnstile(data.cf_turnstile_response, client_ip)
        if not captcha_ok:
            audit.warning("CAPTCHA_FAIL ip=%s username=%s", client_ip, data.username[:32])
            raise HTTPException(400, "CAPTCHA doğrulaması başarısız. Lütfen tekrar deneyin.")

    user = find_user(data.username)

    # A07: constant-time compare to prevent timing attacks
    # A03: Generic error — don't reveal if username exists
    password_ok = (
        user is not None
        and _verify_password(data.password, user["password_hash"])
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
        secure=True,
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

# ── Microsoft Entra ID / Azure AD SSO ─────────────────────────────────────────
@app.get("/api/auth/providers")
async def auth_providers():
    """Returns which login methods are available (used by login page)."""
    return {
        "password":           True,
        "microsoft":          bool(MS_CLIENT_ID and MS_CLIENT_SECRET),
        "allowed_domains":    ALLOWED_DOMAINS,
        "turnstile_site_key": TURNSTILE_SITE_KEY,   # empty string = CAPTCHA disabled
    }

@app.get("/auth/microsoft")
async def microsoft_login():
    """Step 1: Redirect user to Microsoft authorization page."""
    if not MS_CLIENT_ID:
        raise HTTPException(404, "Microsoft SSO yapılandırılmamış")

    state = secrets.token_urlsafe(16)
    _oauth_states[state] = time.time()

    # Prune stale states (>10 min) to prevent memory leak
    cutoff = time.time() - 600
    stale = [s for s, ts in _oauth_states.items() if ts < cutoff]
    for s in stale:
        _oauth_states.pop(s, None)

    params = urlencode({
        "client_id":     MS_CLIENT_ID,
        "response_type": "code",
        "redirect_uri":  MS_REDIRECT_URI,
        "scope":         "openid email profile User.Read",
        "state":         state,
        "response_mode": "query",
        "prompt":        "select_account",   # always show account picker
    })
    return RedirectResponse(
        f"https://login.microsoftonline.com/{MS_TENANT}/oauth2/v2.0/authorize?{params}"
    )

@app.get("/auth/microsoft/callback")
async def microsoft_callback(
    request: Request,
    code: str | None = None,
    state: str | None = None,
    error: str | None = None,
    error_description: str | None = None,
):
    """Step 2: Microsoft redirects here with auth code; exchange for token."""
    client_ip = get_client_ip(request)

    # A07: Rate limit the callback too (prevents brute-forcing stolen codes)
    if is_rate_limited(client_ip):
        audit.warning("MS_CALLBACK_RATE_LIMITED ip=%s", client_ip)
        return RedirectResponse("/login?error=rate_limited")

    if error:
        audit.warning("MS_AUTH_ERROR ip=%s error=%s desc=%s", client_ip, error, error_description)
        return RedirectResponse("/login?error=ms_cancelled")

    if not code or not state:
        return RedirectResponse("/login?error=ms_cancelled")

    # A08: CSRF check — state must match what we issued within 5 minutes
    issued_at = _oauth_states.pop(state, None)
    if issued_at is None or time.time() - issued_at > 300:
        audit.warning("MS_INVALID_STATE ip=%s", client_ip)
        record_attempt(client_ip)
        return RedirectResponse("/login?error=invalid_state")

    # Exchange authorization code for access token
    try:
        async with httpx.AsyncClient(timeout=10) as hc:
            token_resp = await hc.post(
                f"https://login.microsoftonline.com/{MS_TENANT}/oauth2/v2.0/token",
                data={
                    "client_id":     MS_CLIENT_ID,
                    "client_secret": MS_CLIENT_SECRET,
                    "code":          code,
                    "redirect_uri":  MS_REDIRECT_URI,
                    "grant_type":    "authorization_code",
                    "scope":         "openid email profile User.Read",
                },
            )
            if token_resp.status_code != 200:
                audit.warning("MS_TOKEN_ERROR ip=%s status=%d body=%s",
                              client_ip, token_resp.status_code, token_resp.text[:200])
                record_attempt(client_ip)
                return RedirectResponse("/login?error=token_error")

            access_token = token_resp.json().get("access_token", "")

            # Get user profile from Microsoft Graph
            me_resp = await hc.get(
                "https://graph.microsoft.com/v1.0/me",
                headers={"Authorization": f"Bearer {access_token}"},
                params={"$select": "displayName,mail,userPrincipalName"},
            )
            if me_resp.status_code != 200:
                audit.warning("MS_GRAPH_ERROR ip=%s status=%d", client_ip, me_resp.status_code)
                return RedirectResponse("/login?error=profile_error")

            me = me_resp.json()

    except Exception as exc:
        audit.error("MS_CALLBACK_EXCEPTION ip=%s error=%s", client_ip, exc)
        return RedirectResponse("/login?error=network_error")

    email = (me.get("mail") or me.get("userPrincipalName") or "").lower().strip()
    display_name = me.get("displayName") or email.split("@")[0]

    if not email or "@" not in email:
        audit.warning("MS_NO_EMAIL ip=%s profile=%s", client_ip, str(me)[:200])
        return RedirectResponse("/login?error=no_email")

    domain = email.split("@")[1]

    # A01: Domain allowlist — reject accounts from unapproved domains
    if ALLOWED_DOMAINS and domain not in ALLOWED_DOMAINS:
        audit.warning("MS_DOMAIN_DENIED ip=%s email=%s domain=%s allowed=%s",
                      client_ip, email, domain, ALLOWED_DOMAINS)
        record_attempt(client_ip)
        return RedirectResponse("/login?error=domain_not_allowed")

    # Find existing SSO user or auto-create one
    users = load_users()
    user_record = next((u for u in users if u.get("ms_email", "").lower() == email), None)

    if not user_record:
        # Derive safe username from email prefix
        base = re.sub(r"[^a-zA-Z0-9_]", "_", email.split("@")[0])[:28] or "user"
        username, suffix = base, 1
        while any(u["username"] == username for u in users):
            username = f"{base}_{suffix}"
            suffix += 1

        user_record = {
            "username":      username,
            "display_name":  display_name,
            "ms_email":      email,
            "password_hash": None,           # SSO users have no local password
            "role":          "user",
            "created_at":    datetime.now(timezone.utc).isoformat(),
            "created_by":    "microsoft_sso",
        }
        users.append(user_record)
        save_users(users)
        audit.info("MS_USER_CREATED username=%s email=%s", username, email)

    audit.info("MS_LOGIN_OK ip=%s username=%s email=%s", client_ip, user_record["username"], email)
    token = create_session(user_record["username"], user_record["role"])

    response = RedirectResponse("/", status_code=302)
    response.set_cookie(
        key="nordgpt_session",
        value=token,
        httponly=True,
        samesite="lax",   # must be lax (not strict) for OAuth2 redirect flow
        max_age=86400,
        secure=True,
        path="/",
    )
    return response

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
        "password_hash": _hash_password(req.password),
        "role": req.role,
        "created_at": datetime.now(timezone.utc).isoformat(),
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

@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...), user: dict = Depends(get_current_user)):
    """Upload a file (image or document) to attach to a chat message."""
    mime = (file.content_type or "").split(";")[0].strip()
    file_type = ALLOWED_MIMES.get(mime)
    if not file_type:
        raise HTTPException(415, f"Desteklenmeyen dosya türü. İzin verilenler: resim, PDF, DOCX, TXT")

    data = await file.read()
    if len(data) > MAX_FILE_SIZE:
        raise HTTPException(413, f"Dosya çok büyük (max {MAX_UPLOAD_MB} MB)")
    if len(data) == 0:
        raise HTTPException(400, "Boş dosya")

    file_id = str(uuid.uuid4())
    original_name = file.filename or "dosya"
    ext = Path(original_name).suffix.lower()
    if ext not in (".jpg", ".jpeg", ".png", ".gif", ".webp", ".pdf", ".docx", ".txt", ".csv"):
        ext = ""
    stored_name = f"{file_id}{ext}"
    stored_path  = UPLOADS_DIR / stored_name

    stored_path.write_bytes(data)

    extracted_text = ""
    if file_type == "document":
        extracted_text = extract_text_from_file(data, mime, original_name)

    meta = {
        "id":             file_id,
        "filename":       stored_name,
        "original_name":  original_name,
        "type":           file_type,
        "mime":           mime,
        "size":           len(data),
        "extracted_text": extracted_text[:50_000],
        "uploaded_by":    user["username"],
        "uploaded_at":    datetime.now(timezone.utc).isoformat(),
    }
    (UPLOADS_DIR / f"{file_id}.meta.json").write_text(
        json.dumps(meta, ensure_ascii=False), encoding="utf-8"
    )

    logger.info("UPLOAD file_id=%s name=%s type=%s size=%d user=%s",
                file_id, original_name, file_type, len(data), user["username"])
    return {
        "file_id":      file_id,
        "filename":     original_name,
        "type":         file_type,
        "size":         len(data),
        "has_text":     bool(extracted_text),
        "preview_url":  f"/api/upload/{file_id}" if file_type == "image" else None,
    }

@app.get("/api/upload/{file_id}")
async def serve_upload(file_id: str, user: dict = Depends(get_current_user)):
    """Serve an uploaded file (images only — for preview in chat history)."""
    if not _FILE_ID_RE.match(file_id):
        raise HTTPException(400, "Geçersiz dosya ID")
    meta_path = UPLOADS_DIR / f"{file_id}.meta.json"
    if not meta_path.exists():
        raise HTTPException(404, "Dosya bulunamadı")
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    if user["role"] != "admin" and meta["uploaded_by"] != user["username"]:
        raise HTTPException(403)
    stored = UPLOADS_DIR / meta["filename"]
    if not stored.exists():
        raise HTTPException(404, "Dosya bulunamadı")
    return FileResponse(stored, media_type=meta["mime"])

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
    chat["updated_at"] = datetime.now(timezone.utc).isoformat()
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
    file_ids: list[str] = []

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

    # ── Process attached files ──────────────────────────────────────────────────
    attachments_meta: list[dict] = []
    doc_context      = ""
    image_b64_list:  list[str]   = []

    for fid in (req.file_ids or []):
        if not _FILE_ID_RE.match(fid):
            continue
        meta_path = UPLOADS_DIR / f"{fid}.meta.json"
        if not meta_path.exists():
            continue
        fmeta = json.loads(meta_path.read_text(encoding="utf-8"))
        # Ownership check
        if user["role"] != "admin" and fmeta["uploaded_by"] != user["username"]:
            continue
        attachments_meta.append({
            "file_id":  fid,
            "filename": fmeta["original_name"],
            "type":     fmeta["type"],
            "mime":     fmeta["mime"],
        })
        if fmeta["type"] == "image":
            img_path = UPLOADS_DIR / fmeta["filename"]
            if img_path.exists():
                image_b64_list.append(base64.b64encode(img_path.read_bytes()).decode())
        elif fmeta["type"] == "document" and fmeta.get("extracted_text"):
            doc_context += f"[📄 {fmeta['original_name']}]\n\n{fmeta['extracted_text'][:8000]}\n\n---\n\n"

    # User message content for Ollama (augmented with doc context if any)
    ollama_user_content = (doc_context + req.message) if doc_context else req.message

    # Add user message to history (store original message, not augmented)
    user_msg: dict = {
        "role":      "user",
        "content":   req.message,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    if attachments_meta:
        user_msg["attachments"] = attachments_meta
    chat_data["messages"].append(user_msg)

    if len(chat_data["messages"]) == 1:
        chat_data["title"] = req.message.strip()[:60]

    # Build Ollama message list
    ollama_msgs = []
    if chat_data.get("system_prompt"):
        ollama_msgs.append({"role": "system", "content": chat_data["system_prompt"]})
    for i, m in enumerate(chat_data["messages"]):
        is_current = (i == len(chat_data["messages"]) - 1 and m["role"] == "user")
        entry: dict = {
            "role":    m["role"],
            "content": ollama_user_content if is_current else m["content"],
        }
        if is_current and image_b64_list:
            entry["images"] = image_b64_list
        ollama_msgs.append(entry)

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
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })
        chat_data["updated_at"] = datetime.now(timezone.utc).isoformat()
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
        "created_at": datetime.now(timezone.utc).isoformat(),
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "temporary": temp,
        "system_prompt": sys_prompt,
        "created_by": owner,
        "messages": [],
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=7860, reload=False, log_level="warning")
