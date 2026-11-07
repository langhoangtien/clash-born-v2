"""Clashborn — kho báo cáo hiệu năng game gửi lên (D-287). Chỉ dùng thư viện chuẩn; upload_server.py gọi.

Game gửi (không cần mã bí mật — mã nhét trong APK thì ai cũng lấy được):
  POST /api/report  {kind: "bench"|"log", note?: str, summary?: str, data: object}
    → {"id": "B-0042"}   (B = Benchmark A/B, L = log trận)
Đọc (cần mã bí mật):
  GET /api/reports              → [{id, received, kind, version, device, note}] mới nhất trước
  GET /api/reports/<id|latest>  → cả báo cáo
Chặn lạm dụng: tối đa MAX_BYTES / lần, chỉ nhận JSON đúng dạng, giữ KEEP báo cáo (cũ nhất tự xóa); nginx giới hạn
số lần gửi / IP. Lưu ở <root>/reports/ (ngoài www/ — người ngoài không xem được). Không lưu IP.
"""
import json, os, re, tempfile, threading, time

MAX_BYTES = 4 * 1024 * 1024  # log trận 15 phút (mẫu 0,5 s) ~1 MB
KEEP = 200
NOTE_MAX = 500
SUMMARY_MAX = 20000
PREFIX = {"bench": "B", "log": "L"}
REPORT_ID = re.compile(r"^[BL]-\d{4,6}$")
_lock = threading.Lock()


def _dir(root: str) -> str:
    d = os.path.join(root, "reports")
    os.makedirs(d, exist_ok=True)
    return d


def _number(name: str) -> int:
    return int(name.split("-")[1].split(".")[0])


def _files(root: str) -> list:
    """Tên file báo cáo, cũ → mới (số tăng dần chung cho cả B và L)."""
    return sorted((f for f in os.listdir(_dir(root)) if f.endswith(".json") and REPORT_ID.match(f[:-5])), key=_number)


def parse(body: bytes) -> dict:
    """Kiểm tra dạng báo cáo; sai thì ValueError."""
    try:
        info = json.loads(body)
    except (ValueError, UnicodeDecodeError):
        raise ValueError("không phải JSON")
    if not isinstance(info, dict) or info.get("kind") not in PREFIX or not isinstance(info.get("data"), dict):
        raise ValueError("thiếu kind (bench | log) hoặc data")
    note, summary = info.get("note", ""), info.get("summary", "")
    if not isinstance(note, str) or not isinstance(summary, str):
        raise ValueError("note / summary phải là chữ")
    return {"kind": info["kind"], "note": note.strip()[:NOTE_MAX], "summary": summary[:SUMMARY_MAX], "data": info["data"]}


def save(root: str, info: dict) -> dict:
    with _lock:
        files = _files(root)
        number = (_number(files[-1]) if files else 0) + 1
        rid = "%s-%04d" % (PREFIX[info["kind"]], number)
        report = {"id": rid, "received": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
        report.update(info)
        fd, tmp = tempfile.mkstemp(dir=_dir(root))
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False)
        os.replace(tmp, os.path.join(_dir(root), rid + ".json"))
        for old in (files + [rid + ".json"])[:-KEEP]:
            os.remove(os.path.join(_dir(root), old))
    return {"id": rid}


def _load(root: str, name: str) -> dict:
    with open(os.path.join(_dir(root), name), encoding="utf-8") as f:
        return json.load(f)


def listing(root: str) -> list:
    out = []
    for name in reversed(_files(root)):
        r = _load(root, name)
        meta = r.get("data", {}).get("meta", {})
        out.append({"id": r["id"], "received": r["received"], "kind": r["kind"], "version": meta.get("version", ""),
                    "device": meta.get("device", ""), "note": r.get("note", "")})
    return out


def get(root: str, rid: str) -> dict:
    files = _files(root)
    if rid == "latest":
        if not files:
            raise KeyError(rid)
        return _load(root, files[-1])
    if not REPORT_ID.match(rid) or rid + ".json" not in files:
        raise KeyError(rid)
    return _load(root, rid + ".json")
