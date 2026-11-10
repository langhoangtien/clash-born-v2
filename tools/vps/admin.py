"""Clashborn — quản trị tài khoản (D-334). Thư viện chuẩn; upload_server.py gọi, mọi đường cần mã quản trị
(Authorization: Bearer <mã trong /etc/clashborn/upload_token> — cùng mã đẩy bản build). Trang: clashborn.quest/admin/.

  GET  /api/admin/accounts?q=<email hoặc tên>   → tối đa 50 tài khoản (mới nhất trước), kèm số trận
  GET  /api/admin/account/<id>                  → chi tiết + 20 trận gần nhất
  GET  /api/admin/log                           → 100 thao tác gần nhất
  POST /api/admin/ban {id, reason}  /unban {id}  → ban: đăng xuất mọi máy, không đăng nhập / gửi trận / vào online được
  POST /api/admin/rename {id, name}              → đổi tên xấu (luật tên như người chơi tự đặt, không trùng)
  POST /api/admin/delete_matches {id}            → xóa khỏi thống kê mọi trận có tài khoản này (cả trận, mọi người chơi)
  POST /api/admin/delete_match {match}           → xóa một trận
Mọi thao tác ghi vào bảng admin_log (lúc nào, việc gì, tài khoản / trận, ghi chú).
"""
import sqlite3, time

import accounts
import stats

LOG = "CREATE TABLE IF NOT EXISTS admin_log (id INTEGER PRIMARY KEY, at TEXT, action TEXT, target TEXT, detail TEXT)"


class AdminError(Exception):
    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.message, self.status = message, status


def _run(root: str, fn):
    with stats._lock:
        con = stats._db(root)
        con.execute(LOG)
        try:
            out = fn(con)
            con.commit()
            return out
        finally:
            con.close()


def _log(con, action: str, target, detail: str = "") -> None:
    con.execute("INSERT INTO admin_log (at, action, target, detail) VALUES (?,?,?,?)",
                (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), action, str(target), detail[:500]))


def _id(v) -> int:
    if isinstance(v, bool) or not isinstance(v, int) or v < 1:
        raise AdminError("id không hợp lệ")
    return v


def _row(con, aid: int) -> tuple:
    row = con.execute("SELECT id, email, name, created, banned, ban_reason, google_sub IS NOT NULL, pw_hash IS NOT NULL, "
                      "verified FROM accounts WHERE id = ?", (aid,)).fetchone()
    if row is None:
        raise AdminError("không có tài khoản %d" % aid, 404)
    return row


def _card(con, row: tuple) -> dict:
    games = con.execute("SELECT COUNT(*) FROM players WHERE account_id = ?", (row[0],)).fetchone()[0]
    return {"id": row[0], "email": row[1], "name": row[2] or "", "created": row[3], "banned": bool(row[4]),
            "ban_reason": row[5] or "", "google": bool(row[6]), "password": bool(row[7]), "verified": bool(row[8]), "games": games}


def search(root: str, q: str) -> list:
    like = "%" + q.strip().casefold().replace("%", "").replace("_", "\\_") + "%"

    def go(con):
        rows = con.execute("SELECT id FROM accounts WHERE email LIKE ? ESCAPE '\\' OR name_key LIKE ? ESCAPE '\\' "
                           "ORDER BY id DESC LIMIT 50", (like, like)).fetchall()
        return [_card(con, _row(con, aid)) for (aid,) in rows]
    return _run(root, go)


def account(root: str, aid) -> dict:
    out = _run(root, lambda con: _card(con, _row(con, _id(aid))))
    out["matches"] = stats.history(root, out["id"])
    return out


def log(root: str) -> list:
    rows = _run(root, lambda con: con.execute("SELECT at, action, target, detail FROM admin_log ORDER BY id DESC LIMIT 100")
                .fetchall())
    return [{"at": a, "action": b, "target": c, "detail": d} for a, b, c, d in rows]


def ban(root: str, body: dict) -> dict:
    aid, reason = _id(body.get("id")), str(body.get("reason", "")).strip()[:200]

    def go(con):
        _row(con, aid)
        con.execute("UPDATE accounts SET banned = 1, ban_reason = ? WHERE id = ?", (reason, aid))
        con.execute("DELETE FROM sessions WHERE account_id = ?", (aid,))
        _log(con, "ban", aid, reason)
        return _card(con, _row(con, aid))
    return _run(root, go)


def unban(root: str, body: dict) -> dict:
    aid = _id(body.get("id"))

    def go(con):
        _row(con, aid)
        con.execute("UPDATE accounts SET banned = 0, ban_reason = NULL WHERE id = ?", (aid,))
        _log(con, "unban", aid)
        return _card(con, _row(con, aid))
    return _run(root, go)


def rename(root: str, body: dict) -> dict:
    aid, name = _id(body.get("id")), body.get("name")
    if not isinstance(name, str) or not accounts.NAME.match(name.strip()) or "  " in name:
        raise AdminError("tên không hợp lệ (3–16 ký tự)")

    def go(con):
        old = _row(con, aid)[2] or ""
        try:
            con.execute("UPDATE accounts SET name = ?, name_key = ? WHERE id = ?", (name.strip(), name.strip().casefold(), aid))
        except sqlite3.IntegrityError:
            raise AdminError("tên đã có người dùng", 409)
        _log(con, "rename", aid, "%s → %s" % (old, name.strip()))
        return _card(con, _row(con, aid))
    return _run(root, go)


def _drop(con, ids: list) -> int:
    for t in ("players", "items", "buys"):
        con.executemany("DELETE FROM %s WHERE match_id = ?" % t, [(m,) for m in ids])
    con.executemany("DELETE FROM matches WHERE id = ?", [(m,) for m in ids])
    return len(ids)


def delete_matches(root: str, body: dict) -> dict:
    aid = _id(body.get("id"))

    def go(con):
        _row(con, aid)
        ids = [m for (m,) in con.execute("SELECT DISTINCT match_id FROM players WHERE account_id = ?", (aid,))]
        n = _drop(con, ids)
        _log(con, "delete_matches", aid, "%d trận" % n)
        return {"deleted": n}
    return _run(root, go)


def delete_match(root: str, body: dict) -> dict:
    mid = _id(body.get("match"))

    def go(con):
        if con.execute("SELECT 1 FROM matches WHERE id = ?", (mid,)).fetchone() is None:
            raise AdminError("không có trận %d" % mid, 404)
        _drop(con, [mid])
        _log(con, "delete_match", "trận %d" % mid)
        return {"deleted": 1}
    return _run(root, go)
