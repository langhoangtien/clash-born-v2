#!/usr/bin/env python3
"""Clashborn — máy chủ nhận bản build (chạy trên VPS sau nginx, chỉ nghe 127.0.0.1). Chỉ dùng thư viện chuẩn.

API (mọi lệnh ghi cần header  Authorization: Bearer <mã trong /etc/clashborn/upload_token>):
  GET  /api/health                    → {"ok": true}
  PUT  /api/upload/<tên file>         → lưu vào incoming/ (tên: clashborn-0.1.N.apk | site.tar.gz)
  POST /api/publish  (JSON)           → {code, name, file, sha256, notes?}: kiểm sha256 file trong incoming/,
                                         chuyển vào www/releases/, ghi www/version.json (ghi tạm rồi đổi tên),
                                         trỏ www/download/clashborn.apk tới bản mới, giữ KEEP bản gần nhất.
  POST /api/site                      → giải nén incoming/site.tar.gz thành trang web (không đụng releases/,
                                         version.json, download/, play/).
Chạy:  python3 upload_server.py --root /srv/clashborn --port 8787
"""
import argparse, hashlib, hmac, json, os, re, shutil, tarfile, tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

APK_NAME = re.compile(r"^clashborn-0\.1\.\d{1,6}\.apk$")
UPLOAD_NAMES = re.compile(r"^(clashborn-0\.1\.\d{1,6}\.apk|site\.tar\.gz)$")
MAX_BYTES = 400 * 1024 * 1024  # 400 MB / file
KEEP = 5
PROTECTED = {"releases", "version.json", "download", "play"}  # trang web không được ghi đè các mục này
ROOT = "/srv/clashborn"
TOKEN_FILE = "/etc/clashborn/upload_token"


def token() -> str:
    with open(TOKEN_FILE, encoding="utf-8") as f:
        return f.read().strip()


def sha256_of(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def write_atomic(path: str, data: bytes) -> None:
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
    with os.fdopen(fd, "wb") as f:
        f.write(data)
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)


def publish(info: dict) -> dict:
    name = str(info.get("file", ""))
    if not APK_NAME.match(name):
        raise ValueError("tên file APK không hợp lệ")
    src = os.path.join(ROOT, "incoming", name)
    if not os.path.isfile(src):
        raise ValueError("chưa tải lên " + name)
    digest = sha256_of(src)
    if not hmac.compare_digest(digest, str(info.get("sha256", "")).lower()):
        raise ValueError("sha256 không khớp")
    www = os.path.join(ROOT, "www")
    rel = os.path.join(www, "releases")
    os.makedirs(rel, exist_ok=True)
    os.makedirs(os.path.join(www, "download"), exist_ok=True)
    dst = os.path.join(rel, name)
    os.replace(src, dst)
    os.chmod(dst, 0o644)
    version = {"code": int(info["code"]), "name": str(info["name"]), "apk": "releases/" + name,
               "url": "https://clashborn.quest/releases/" + name, "sha256": digest,
               "size": os.path.getsize(dst), "notes": str(info.get("notes", ""))[:2000]}
    link = os.path.join(www, "download", "clashborn.apk")
    tmp_link = link + ".new"
    if os.path.lexists(tmp_link):
        os.remove(tmp_link)
    os.symlink(os.path.join("..", "releases", name), tmp_link)
    os.replace(tmp_link, link)
    write_atomic(os.path.join(www, "version.json"), json.dumps(version, ensure_ascii=False, indent=1).encode())
    apks = sorted((f for f in os.listdir(rel) if APK_NAME.match(f)), key=lambda f: int(f.split(".")[2]))
    for old in apks[:-KEEP]:
        os.remove(os.path.join(rel, old))
    return version


def publish_site() -> dict:
    src = os.path.join(ROOT, "incoming", "site.tar.gz")
    www = os.path.join(ROOT, "www")
    stage = tempfile.mkdtemp(dir=os.path.join(ROOT, "incoming"))  # người dùng clashborn ghi được ở đây
    try:
        with tarfile.open(src, "r:gz") as tar:
            for m in tar.getmembers():
                top = m.name.lstrip("./").split("/")[0]
                if m.issym() or m.islnk() or m.name.startswith("/") or ".." in m.name.split("/") or top in PROTECTED:
                    raise ValueError("đường dẫn không hợp lệ trong site.tar.gz: " + m.name)
            tar.extractall(stage, filter="data")
        count = 0
        for dirpath, _, files in os.walk(stage):
            for f in files:
                rel_path = os.path.relpath(os.path.join(dirpath, f), stage)
                dst = os.path.join(www, rel_path)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                os.replace(os.path.join(dirpath, f), dst)
                os.chmod(dst, 0o644)
                count += 1
        return {"files": count}
    finally:
        shutil.rmtree(stage, ignore_errors=True)


class Handler(BaseHTTPRequestHandler):
    server_version = "clashborn-upload"

    def _send(self, code: int, body: dict) -> None:
        data = json.dumps(body, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _authorized(self) -> bool:
        got = self.headers.get("Authorization", "")
        return got.startswith("Bearer ") and hmac.compare_digest(got[7:].strip(), token())

    def do_GET(self) -> None:
        if self.path == "/api/health":
            self._send(200, {"ok": True})
        else:
            self._send(404, {"error": "không có"})

    def do_PUT(self) -> None:
        if not self._authorized():
            return self._send(401, {"error": "sai mã"})
        name = self.path.removeprefix("/api/upload/")
        if not self.path.startswith("/api/upload/") or not UPLOAD_NAMES.match(name):
            return self._send(400, {"error": "tên file không hợp lệ"})
        size = int(self.headers.get("Content-Length", "-1"))
        if size <= 0 or size > MAX_BYTES:
            return self._send(413, {"error": "kích thước không hợp lệ"})
        inc = os.path.join(ROOT, "incoming")
        os.makedirs(inc, exist_ok=True)
        part = os.path.join(inc, name + ".part")
        left = size
        with open(part, "wb") as f:
            while left > 0:
                chunk = self.rfile.read(min(left, 1 << 20))
                if not chunk:
                    break
                f.write(chunk)
                left -= len(chunk)
        if left:
            os.remove(part)
            return self._send(400, {"error": "tải lên bị đứt"})
        os.replace(part, os.path.join(inc, name))
        self._send(200, {"file": name, "size": size, "sha256": sha256_of(os.path.join(inc, name))})

    def do_POST(self) -> None:
        if not self._authorized():
            return self._send(401, {"error": "sai mã"})
        try:
            if self.path == "/api/publish":
                length = min(int(self.headers.get("Content-Length", "0")), 64 * 1024)
                self._send(200, publish(json.loads(self.rfile.read(length) or b"{}")))
            elif self.path == "/api/site":
                self._send(200, publish_site())
            else:
                self._send(404, {"error": "không có"})
        except (ValueError, KeyError, OSError, tarfile.TarError) as e:
            self._send(400, {"error": str(e)})

    def log_message(self, fmt: str, *args) -> None:  # không ghi header (có mã bí mật)
        print("%s %s" % (self.command, self.path), flush=True)


def main() -> None:
    global ROOT, TOKEN_FILE
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=ROOT)
    ap.add_argument("--token-file", default=TOKEN_FILE)
    ap.add_argument("--port", type=int, default=8787)
    a = ap.parse_args()
    ROOT, TOKEN_FILE = a.root, a.token_file
    ThreadingHTTPServer(("127.0.0.1", a.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
