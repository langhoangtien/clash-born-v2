"""D-341: biên bản trận game gửi mà máy chủ từ chối — giữ KEEP cái gần nhất (lý do + biên bản, không có email / IP)
để quản trị đọc qua GET /api/admin/rejects, khỏi phải vào nhật ký VPS. Chẩn đoán lỗi 400 trận 3v3 (D-339)."""
import json, os, time

KEEP = 30


def _dir(root: str) -> str:
    return os.path.join(root, "rejected")


def keep(root: str, body, reason: str, account: int) -> None:
    """Ghi một lần từ chối (và một dòng nhật ký như D-339)."""
    b = body if isinstance(body, dict) else {}
    ps = b.get("players")
    print("match rejected: %s | mode=%r kind=%r version=%r players=%s teams=%s" % (
        reason, b.get("mode"), b.get("kind"), b.get("version"), len(ps) if isinstance(ps, list) else "?",
        [p.get("team") for p in ps if isinstance(p, dict)] if isinstance(ps, list) else "?"), flush=True)
    d = _dir(root)
    os.makedirs(d, exist_ok=True)
    name = "%d-%06d.json" % (int(time.time()), time.monotonic_ns() % 1000000)
    with open(os.path.join(d, name), "w", encoding="utf-8") as f:
        json.dump({"at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "reason": reason, "account": account,
                   "record": body}, f, ensure_ascii=False)
    for old in sorted(os.listdir(d))[:-KEEP]:
        os.remove(os.path.join(d, old))


def listing(root: str) -> list:
    """Mới nhất trước."""
    d = _dir(root)
    out = []
    for name in sorted(os.listdir(d), reverse=True) if os.path.isdir(d) else []:
        with open(os.path.join(d, name), encoding="utf-8") as f:
            out.append(json.load(f))
    return out
