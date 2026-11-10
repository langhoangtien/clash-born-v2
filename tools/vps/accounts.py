"""Clashborn — tài khoản người chơi (D-333, ROADMAP ACC). Thư viện chuẩn (sqlite3, hashlib.scrypt, smtplib, urllib);
upload_server.py gọi. Lưu cùng file SQLite với stats: <root>/stats/stats.db.

Email + mật khẩu:
  POST /api/auth/register {email, password}        → gửi mã xác minh 6 số qua mail (tài khoản chưa xác minh)
  POST /api/auth/verify   {email, code}            → xác minh → phiên đăng nhập {token, account}
  POST /api/auth/resend   {email}                  → gửi lại mã xác minh
  POST /api/auth/login    {email, password}        → phiên (chưa xác minh → lỗi NOT_VERIFIED)
  POST /api/auth/reset    {email}                  → gửi mã đặt lại mật khẩu (luôn trả ok — không lộ email nào có tài khoản)
  POST /api/auth/reset_finish {email, code, password} → mật khẩu mới, đăng xuất mọi máy khác, phiên mới
Google (trình duyệt, không plugin): POST /api/auth/google/start → {sid, url}; game mở url; Google trả về
  GET /api/auth/google/callback?code&state → trang "đã đăng nhập"; game hỏi POST /api/auth/google/poll {sid} → phiên.
Phiên (header X-Clashborn-Session: <token>): GET /api/auth/me, POST /api/auth/name {name}, POST /api/auth/logout,
  POST /api/auth/delete → xóa vĩnh viễn tài khoản + mọi phiên (Google Play bắt buộc có trong app).

An toàn: mật khẩu băm scrypt + muối riêng; mã 6 số chỉ lưu dạng băm, hết hạn 15 phút, tối đa 5 lần thử; sai mật khẩu
10 lần → khóa 15 phút; token phiên 32 byte ngẫu nhiên, chỉ lưu SHA-256, hạn 90 ngày. Bí mật (mật khẩu ứng dụng
Gmail, client secret Google) chỉ đọc từ /etc/clashborn/*.json trên VPS. Không lưu IP.
"""
import hashlib, hmac, html, json, os, re, secrets, smtplib, sqlite3, threading, time, urllib.parse, urllib.request
from email.message import EmailMessage

EMAIL = re.compile(r"^[^@\s]{1,64}@[^@\s]{1,190}\.[^@\s.]{2,24}$")
NAME = re.compile(r"^[^\W_][\w .\-]{1,14}[^\W_]$")   # 3–16 ký tự: chữ (cả tiếng Việt) / số, giữa được cách . - _
PASSWORD_MIN, PASSWORD_MAX = 8, 128
CODE_TTL = 15 * 60
CODE_TRIES = 5
LOCK_FAILS, LOCK_S = 10, 15 * 60
SESSION_S = 90 * 24 * 3600
GOOGLE_TTL = 10 * 60
MAX_BODY = 4096
SITE = "https://clashborn.quest"
SMTP_FILE = "/etc/clashborn/smtp.json"            # {"user": "...@gmail.com", "app_password": "...", "from_name": "Clashborn"}
GOOGLE_FILE = "/etc/clashborn/google_oauth.json"  # {"client_id": "...", "client_secret": "..."}
_lock = threading.Lock()

TABLES = """
CREATE TABLE IF NOT EXISTS accounts (id INTEGER PRIMARY KEY, email TEXT UNIQUE, pw_hash TEXT, verified INTEGER DEFAULT 0,
  name TEXT, name_key TEXT UNIQUE, google_sub TEXT UNIQUE, created TEXT, fails INTEGER DEFAULT 0, locked_until REAL DEFAULT 0);
CREATE TABLE IF NOT EXISTS codes (email TEXT, purpose TEXT, code_hash TEXT, expires REAL, tries INTEGER DEFAULT 0,
  PRIMARY KEY (email, purpose));
CREATE TABLE IF NOT EXISTS sessions (token_hash TEXT PRIMARY KEY, account_id INTEGER, expires REAL);
CREATE TABLE IF NOT EXISTS google_logins (sid TEXT PRIMARY KEY, expires REAL, token TEXT);
"""
# D-334: cột thêm sau khi VPS đã có dữ liệu — ALTER TABLE nếu thiếu (migrate()).
COLUMNS = {"accounts": [("banned", "INTEGER DEFAULT 0"), ("ban_reason", "TEXT"), ("role", "TEXT")]}  # D-335: role mod / admin


class AuthError(Exception):
    """Lỗi trả cho game: mã (game hiện câu theo mã) + câu tiếng Việt + mã HTTP."""
    def __init__(self, code: str, message: str, status: int = 400):
        super().__init__(message)
        self.code, self.message, self.status = code, message, status


# Thay được trong test (mail / Google giả).
def _smtp_send(to: str, subject: str, body: str) -> None:
    with open(SMTP_FILE, encoding="utf-8") as f:
        cfg = json.load(f)
    msg = EmailMessage()
    msg["From"] = "%s <%s>" % (cfg.get("from_name", "Clashborn"), cfg["user"])
    msg["To"], msg["Subject"] = to, subject
    msg.set_content(body)
    with smtplib.SMTP("smtp.gmail.com", 587, timeout=20) as s:
        s.starttls()
        s.login(cfg["user"], cfg["app_password"])
        s.send_message(msg)


def _http_json(url: str, form: dict = None, bearer: str = "") -> dict:
    data = urllib.parse.urlencode(form).encode() if form is not None else None
    req = urllib.request.Request(url, data=data)
    if bearer:
        req.add_header("Authorization", "Bearer " + bearer)
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read())


send_mail = _smtp_send
http_json = _http_json


def _google_cfg() -> dict:
    with open(GOOGLE_FILE, encoding="utf-8") as f:
        return json.load(f)


google_cfg = _google_cfg


# ---- Kho -----------------------------------------------------------------------------------------------------------

def _db(root: str) -> sqlite3.Connection:
    d = os.path.join(root, "stats")
    os.makedirs(d, exist_ok=True)
    con = sqlite3.connect(os.path.join(d, "stats.db"), timeout=10)
    con.executescript(TABLES)
    migrate(con, COLUMNS)
    return con


def migrate(con: sqlite3.Connection, columns: dict) -> None:
    """Thêm cột còn thiếu (bảng cũ trên VPS); chạy lại bao nhiêu lần cũng được."""
    for table, cols in columns.items():
        have = {r[1] for r in con.execute("PRAGMA table_info(%s)" % table)}
        for name, kind in cols:
            if name not in have:
                con.execute("ALTER TABLE %s ADD COLUMN %s %s" % (table, name, kind))


def _run(root: str, fn):
    with _lock:
        con = _db(root)
        try:
            out = fn(con)
            con.commit()
            return out
        finally:
            con.close()


def _hash_pw(password: str, salt: bytes = None) -> str:
    salt = salt or secrets.token_bytes(16)
    dk = hashlib.scrypt(password.encode(), salt=salt, n=2 ** 14, r=8, p=1, dklen=32)
    return "scrypt$%s$%s" % (salt.hex(), dk.hex())


def _check_pw(password: str, stored: str) -> bool:
    if not stored or not stored.startswith("scrypt$"):
        return False
    _, salt, dk = stored.split("$")
    return hmac.compare_digest(_hash_pw(password, bytes.fromhex(salt)).split("$")[2], dk)


def _sha(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()


def _email(v) -> str:
    if not isinstance(v, str) or not EMAIL.match(v.strip()):
        raise AuthError("BAD_EMAIL", "Email không hợp lệ")
    return v.strip().casefold()


def _password(v) -> str:
    if not isinstance(v, str) or not PASSWORD_MIN <= len(v) <= PASSWORD_MAX:
        raise AuthError("BAD_PASSWORD", "Mật khẩu cần %d–%d ký tự" % (PASSWORD_MIN, PASSWORD_MAX))
    return v


def _account(con, where: str, arg) -> tuple:
    return con.execute("SELECT id, email, pw_hash, verified, name, google_sub, fails, locked_until, banned, ban_reason, "
                       "role FROM accounts WHERE " + where, (arg,)).fetchone()


def _not_banned(row: tuple) -> tuple:
    """D-334: tài khoản bị ban không đăng nhập / dùng phiên được (mọi đường đăng nhập đi qua _session / _account_of)."""
    if row is not None and row[8]:
        raise AuthError("BANNED", "Tài khoản đã bị khóa" + (": " + row[9] if row[9] else ""), 403)
    return row


def _public(row: tuple) -> dict:
    return {"id": row[0], "email": row[1], "name": row[4] or "", "google": row[5] is not None, "has_password": bool(row[2]),
            "role": row[10] or ""}


def _session(con, account_id: int) -> dict:
    _not_banned(_account(con, "id = ?", account_id))
    token = secrets.token_urlsafe(32)
    con.execute("INSERT INTO sessions VALUES (?,?,?)", (_sha(token), account_id, time.time() + SESSION_S))
    return {"token": token, "account": _public(_account(con, "id = ?", account_id))}


def _send_code(con, email: str, purpose: str) -> None:
    code = "%06d" % secrets.randbelow(1000000)
    con.execute("INSERT OR REPLACE INTO codes VALUES (?,?,?,?,0)", (email, purpose, _sha(email + code), time.time() + CODE_TTL))
    what = "xác minh email" if purpose == "verify" else "đặt lại mật khẩu"
    send_mail(email, "Clashborn — mã %s: %s" % (what, code),
              "Mã %s Clashborn của bạn: %s\n\nMã hết hạn sau 15 phút. Không phải bạn yêu cầu thì bỏ qua mail này." % (what, code))


def _use_code(con, email: str, purpose: str, code) -> None:
    row = con.execute("SELECT code_hash, expires, tries FROM codes WHERE email = ? AND purpose = ?", (email, purpose)).fetchone()
    if row is None or row[1] < time.time() or row[2] >= CODE_TRIES:
        raise AuthError("CODE_EXPIRED", "Mã hết hạn hoặc sai quá nhiều lần — bấm gửi lại mã")
    if not isinstance(code, str) or not hmac.compare_digest(_sha(email + code.strip()), row[0]):
        con.execute("UPDATE codes SET tries = tries + 1 WHERE email = ? AND purpose = ?", (email, purpose))
        con.commit()
        raise AuthError("BAD_CODE", "Mã không đúng")
    con.execute("DELETE FROM codes WHERE email = ? AND purpose = ?", (email, purpose))


# ---- Email + mật khẩu --------------------------------------------------------------------------------------------

def register(root: str, body: dict) -> dict:
    email, password = _email(body.get("email")), _password(body.get("password"))

    def go(con):
        row = _account(con, "email = ?", email)
        if row is not None and row[3]:
            raise AuthError("EMAIL_TAKEN", "Email đã có tài khoản — đăng nhập hoặc quên mật khẩu", 409)
        if row is None:
            con.execute("INSERT INTO accounts (email, pw_hash, created) VALUES (?,?,?)",
                        (email, _hash_pw(password), time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())))
        else:
            con.execute("UPDATE accounts SET pw_hash = ? WHERE id = ?", (_hash_pw(password), row[0]))
        _send_code(con, email, "verify")
        return {"sent": True}
    return _run(root, go)


def resend(root: str, body: dict) -> dict:
    email = _email(body.get("email"))

    def go(con):
        row = _account(con, "email = ?", email)
        if row is not None and not row[3]:
            _send_code(con, email, "verify")
        return {"sent": True}
    return _run(root, go)


def verify(root: str, body: dict) -> dict:
    email = _email(body.get("email"))

    def go(con):
        row = _account(con, "email = ?", email)
        if row is None:
            raise AuthError("CODE_EXPIRED", "Mã hết hạn hoặc sai quá nhiều lần — bấm gửi lại mã")
        _use_code(con, email, "verify", body.get("code"))
        con.execute("UPDATE accounts SET verified = 1 WHERE id = ?", (row[0],))
        return _session(con, row[0])
    return _run(root, go)


def login(root: str, body: dict) -> dict:
    email, password = _email(body.get("email")), body.get("password")

    def go(con):
        row = _account(con, "email = ?", email)
        if row is not None and row[7] > time.time():
            raise AuthError("LOCKED", "Sai mật khẩu nhiều lần — thử lại sau 15 phút hoặc đặt lại mật khẩu", 429)
        if row is None or not isinstance(password, str) or not _check_pw(password, row[2]):
            if row is not None:
                fails = row[6] + 1
                con.execute("UPDATE accounts SET fails = ?, locked_until = ? WHERE id = ?",
                            (0 if fails >= LOCK_FAILS else fails, time.time() + LOCK_S if fails >= LOCK_FAILS else 0, row[0]))
                con.commit()
            raise AuthError("BAD_LOGIN", "Email hoặc mật khẩu không đúng", 401)
        if not row[3]:
            raise AuthError("NOT_VERIFIED", "Email chưa xác minh — nhập mã trong mail", 403)
        con.execute("UPDATE accounts SET fails = 0 WHERE id = ?", (row[0],))
        return _session(con, row[0])
    return _run(root, go)


def reset(root: str, body: dict) -> dict:
    email = _email(body.get("email"))

    def go(con):
        if _account(con, "email = ?", email) is not None:
            _send_code(con, email, "reset")
        return {"sent": True}  # như nhau dù có tài khoản hay không
    return _run(root, go)


def reset_finish(root: str, body: dict) -> dict:
    email, password = _email(body.get("email")), _password(body.get("password"))

    def go(con):
        row = _account(con, "email = ?", email)
        if row is None:
            raise AuthError("CODE_EXPIRED", "Mã hết hạn hoặc sai quá nhiều lần — bấm gửi lại mã")
        _use_code(con, email, "reset", body.get("code"))
        con.execute("UPDATE accounts SET pw_hash = ?, verified = 1, fails = 0, locked_until = 0 WHERE id = ?",
                    (_hash_pw(password), row[0]))
        con.execute("DELETE FROM sessions WHERE account_id = ?", (row[0],))
        return _session(con, row[0])
    return _run(root, go)


# ---- Phiên ---------------------------------------------------------------------------------------------------------

def _account_of(con, token) -> tuple:
    if not isinstance(token, str) or not token:
        raise AuthError("NO_SESSION", "Chưa đăng nhập", 401)
    row = con.execute("SELECT account_id, expires FROM sessions WHERE token_hash = ?", (_sha(token),)).fetchone()
    if row is None or row[1] < time.time():
        raise AuthError("NO_SESSION", "Phiên đăng nhập hết hạn — đăng nhập lại", 401)
    return _not_banned(_account(con, "id = ?", row[0]))


def me(root: str, token) -> dict:
    return _run(root, lambda con: _public(_account_of(con, token)))


def uploader(root: str, token) -> int:
    """D-334: tài khoản gửi biên bản trận — -1 khi không đăng nhập / phiên hết hạn; bị ban → AuthError BANNED."""
    if not token:
        return -1
    try:
        return me(root, token)["id"]
    except AuthError as e:
        if e.code == "BANNED":
            raise
        return -1


def set_name(root: str, token, body: dict) -> dict:
    name = body.get("name")
    if not isinstance(name, str) or not NAME.match(name.strip()) or "  " in name:
        raise AuthError("BAD_NAME", "Tên 3–16 ký tự: chữ, số, cách, . - _ (không bắt đầu / kết thúc bằng dấu)")
    name = name.strip()

    def go(con):
        row = _account_of(con, token)
        try:
            con.execute("UPDATE accounts SET name = ?, name_key = ? WHERE id = ?", (name, name.casefold(), row[0]))
        except sqlite3.IntegrityError:
            raise AuthError("NAME_TAKEN", "Tên đã có người dùng", 409)
        return _public(_account(con, "id = ?", row[0]))
    return _run(root, go)


def logout(root: str, token) -> dict:
    def go(con):
        con.execute("DELETE FROM sessions WHERE token_hash = ?", (_sha(str(token)),))
        return {"ok": True}
    return _run(root, go)


def delete_account(root: str, token) -> dict:
    def go(con):
        row = _account_of(con, token)
        con.execute("DELETE FROM sessions WHERE account_id = ?", (row[0],))
        con.execute("DELETE FROM codes WHERE email = ?", (row[1],))
        con.execute("DELETE FROM accounts WHERE id = ?", (row[0],))
        return {"deleted": True}
    return _run(root, go)


# ---- Google (trình duyệt) ------------------------------------------------------------------------------------------

def _redirect() -> str:
    return SITE + "/api/auth/google/callback"


def google_start(root: str) -> dict:
    cfg = google_cfg()
    sid = secrets.token_urlsafe(24)
    _run(root, lambda con: con.execute("INSERT INTO google_logins VALUES (?,?,NULL)", (sid, time.time() + GOOGLE_TTL)))
    q = urllib.parse.urlencode({"client_id": cfg["client_id"], "redirect_uri": _redirect(), "response_type": "code",
                                "scope": "openid email profile", "state": sid, "prompt": "select_account"})
    return {"sid": sid, "url": "https://accounts.google.com/o/oauth2/v2/auth?" + q}


def google_callback(root: str, query: dict) -> str:
    """Trang HTML cho trình duyệt (đã đăng nhập / lỗi)."""
    sid, code = query.get("state", ""), query.get("code", "")
    try:
        ok = _run(root, lambda con: con.execute("SELECT 1 FROM google_logins WHERE sid = ? AND expires > ?",
                                                 (sid, time.time())).fetchone())
        if not ok or not code:
            raise AuthError("GOOGLE_EXPIRED", "Phiên đăng nhập Google hết hạn — thử lại trong game")
        cfg = google_cfg()
        tok = http_json("https://oauth2.googleapis.com/token", {"code": code, "client_id": cfg["client_id"],
                        "client_secret": cfg["client_secret"], "redirect_uri": _redirect(), "grant_type": "authorization_code"})
        info = http_json("https://openidconnect.googleapis.com/v1/userinfo", bearer=tok["access_token"])
        if not info.get("sub") or not info.get("email") or info.get("email_verified") is not True:
            raise AuthError("GOOGLE_EMAIL", "Tài khoản Google chưa xác minh email")
        _run(root, lambda con: _google_link(con, sid, str(info["sub"]), _email(info["email"])))
        return _page("Đã đăng nhập", "Quay lại Clashborn — game sẽ tự vào tài khoản.")
    except AuthError as e:
        return _page("Chưa đăng nhập được", e.message)
    except (OSError, ValueError, KeyError):
        return _page("Chưa đăng nhập được", "Google không trả lời — thử lại trong game.")


def _google_link(con, sid: str, sub: str, email: str) -> None:
    row = _account(con, "google_sub = ?", sub) or _account(con, "email = ?", email)
    if row is None:
        con.execute("INSERT INTO accounts (email, verified, google_sub, created) VALUES (?,1,?,?)",
                    (email, sub, time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())))
        row = _account(con, "google_sub = ?", sub)
    else:  # cùng email (Google đã xác minh) → gộp; tài khoản email chưa xác minh coi như đã xác minh
        con.execute("UPDATE accounts SET google_sub = ?, verified = 1 WHERE id = ?", (sub, row[0]))
    con.execute("UPDATE google_logins SET token = ? WHERE sid = ?", (_session(con, row[0])["token"], sid))


def google_poll(root: str, body: dict) -> dict:
    sid = body.get("sid")

    def go(con):
        row = con.execute("SELECT token, expires FROM google_logins WHERE sid = ?", (str(sid),)).fetchone()
        if row is None or row[1] < time.time():
            raise AuthError("GOOGLE_EXPIRED", "Phiên đăng nhập Google hết hạn — thử lại", 410)
        if row[0] is None:
            return {"pending": True}
        con.execute("DELETE FROM google_logins WHERE sid = ?", (str(sid),))
        return {"token": row[0], "account": _public(_account_of(con, row[0]))}
    return _run(root, go)


def _page(title: str, text: str) -> str:
    return ("<!doctype html><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
            "<title>Clashborn</title><body style='background:#0b1020;color:#e8ecf4;font-family:sans-serif;text-align:center;"
            "padding:60px 16px'><h1 style='color:#e7b45a'>%s</h1><p>%s</p></body>" % (html.escape(title), html.escape(text)))
