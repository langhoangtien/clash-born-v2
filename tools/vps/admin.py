"""Clashborn — quản trị tài khoản (D-334, D-335). Thư viện chuẩn; upload_server.py gọi. Trang: clashborn.quest/admin/.

Ai được vào (D-335): tài khoản người chơi có quyền — **mod** (điều hành: xem, ban / bỏ ban, đổi tên, xóa trận) hoặc
**admin** (thêm cấp / thu quyền) — đăng nhập như trong game, gửi phiên qua X-Clashborn-Session; hoặc **mã quản trị**
(Authorization: Bearer <mã trong /etc/clashborn/upload_token>, cùng mã đẩy bản build) — chìa dự phòng, cấp admin đầu tiên.
Không ai tác động lên người cùng cấp hay cao hơn mình, không tự đổi quyền của mình; admin cấp được tới admin.

  GET  /api/admin/accounts?q=<email hoặc tên>   → tối đa 50 tài khoản (mới nhất trước), kèm số trận
  GET  /api/admin/account/<id>                  → chi tiết + 20 trận gần nhất
  GET  /api/admin/log                           → 100 thao tác gần nhất
  POST /api/admin/ban {id, reason}  /unban {id}  → ban: đăng xuất mọi máy, không đăng nhập / gửi trận / vào online được
  POST /api/admin/rename {id, name}              → đổi tên xấu (luật tên như người chơi tự đặt, không trùng)
  POST /api/admin/delete_matches {id}            → xóa khỏi thống kê mọi trận có tài khoản này (cả trận, mọi người chơi)
  POST /api/admin/delete_match {match}           → xóa một trận
  GET  /api/admin/whoami                         → người đang thao tác + quyền (D-335)
  POST /api/admin/set_role {id, role: ""|"mod"|"admin"} → chỉ admin / mã quản trị (D-335)
Mọi thao tác ghi vào bảng admin_log (lúc nào, ai làm, việc gì, tài khoản / trận, ghi chú).
"""
import sqlite3, time

import accounts
import stats

LOG = "CREATE TABLE IF NOT EXISTS admin_log (id INTEGER PRIMARY KEY, at TEXT, action TEXT, target TEXT, detail TEXT)"
RANK = {"": 0, "mod": 1, "admin": 2, "master": 3}  # master = mã quản trị
ROLE_NAMES = {"": "Người chơi", "mod": "Điều hành", "admin": "Quản trị", "master": "Mã quản trị"}


class AdminError(Exception):
    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.message, self.status = message, status


def _run(root: str, fn):
    with stats._lock:
        con = stats._db(root)
        con.execute(LOG)
        accounts.migrate(con, {"admin_log": [("actor", "TEXT")]})
        try:
            out = fn(con)
            con.commit()
            return out
        finally:
            con.close()


def _log(con, who: dict, action: str, target, detail: str = "") -> None:
    con.execute("INSERT INTO admin_log (at, actor, action, target, detail) VALUES (?,?,?,?,?)",
                (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), who["label"], action, str(target), detail[:500]))


def actor(root: str, master: bool, token) -> dict:
    """Người thao tác: mã quản trị, hoặc phiên của tài khoản có quyền mod / admin (không có → AdminError 403)."""
    if master:
        return {"id": 0, "role": "master", "label": "mã quản trị", "name": "Mã quản trị"}
    try:
        me = accounts.me(root, token)
    except accounts.AuthError as e:
        raise AdminError(e.message, 401)
    if RANK.get(me["role"], 0) < RANK["mod"]:
        raise AdminError("Tài khoản này không có quyền quản trị", 403)
    return {"id": me["id"], "role": me["role"], "label": "#%d %s" % (me["id"], me["name"]), "name": me["name"]}


def _need(who: dict, role: str) -> None:
    if RANK[who["role"]] < RANK[role]:
        raise AdminError("Cần quyền %s" % ROLE_NAMES[role], 403)


def _over(con, who: dict, aid: int) -> tuple:
    """Tài khoản đích, chỉ khi người thao tác cao cấp hơn (không tự làm với mình)."""
    row = _row(con, aid)
    if aid == who["id"] or RANK.get(row[9] or "", 0) >= RANK[who["role"]]:
        raise AdminError("Không thao tác được với tài khoản cùng cấp / cao hơn hay chính mình", 403)
    return row


def _id(v) -> int:
    if isinstance(v, bool) or not isinstance(v, int) or v < 1:
        raise AdminError("id không hợp lệ")
    return v


def _row(con, aid: int) -> tuple:
    row = con.execute("SELECT id, email, name, created, banned, ban_reason, google_sub IS NOT NULL, pw_hash IS NOT NULL, "
                      "verified, role FROM accounts WHERE id = ?", (aid,)).fetchone()
    if row is None:
        raise AdminError("không có tài khoản %d" % aid, 404)
    return row


def _card(con, row: tuple) -> dict:
    games = con.execute("SELECT COUNT(*) FROM players WHERE account_id = ?", (row[0],)).fetchone()[0]
    return {"id": row[0], "email": row[1], "name": row[2] or "", "created": row[3], "banned": bool(row[4]),
            "ban_reason": row[5] or "", "google": bool(row[6]), "password": bool(row[7]), "verified": bool(row[8]), "games": games,
            "role": row[9] or ""}


def search(root: str, who: dict, q: str) -> list:
    _need(who, "mod")
    like = "%" + q.strip().casefold().replace("%", "").replace("_", "\\_") + "%"

    def go(con):
        rows = con.execute("SELECT id FROM accounts WHERE email LIKE ? ESCAPE '\\' OR name_key LIKE ? ESCAPE '\\' "
                           "ORDER BY id DESC LIMIT 50", (like, like)).fetchall()
        return [_card(con, _row(con, aid)) for (aid,) in rows]
    return _run(root, go)


def account(root: str, who: dict, aid) -> dict:
    _need(who, "mod")
    out = _run(root, lambda con: _card(con, _row(con, _id(aid))))
    out["matches"] = stats.history(root, out["id"])
    return out


def log(root: str, who: dict) -> list:
    _need(who, "mod")
    rows = _run(root, lambda con: con.execute("SELECT at, actor, action, target, detail FROM admin_log ORDER BY id DESC "
                                              "LIMIT 100").fetchall())
    return [{"at": a, "actor": w or "", "action": b, "target": c, "detail": d} for a, w, b, c, d in rows]


def set_role(root: str, who: dict, body: dict) -> dict:
    """D-335: cấp / thu quyền — chỉ admin / mã quản trị; cấp tới đúng cấp của mình."""
    _need(who, "admin")
    aid, role = _id(body.get("id")), body.get("role")
    if role not in ("", "mod", "admin") or RANK[role] > RANK[who["role"]]:
        raise AdminError("quyền không hợp lệ")

    def go(con):
        old = _over(con, who, aid)[9] or ""
        con.execute("UPDATE accounts SET role = ? WHERE id = ?", (role or None, aid))
        _log(con, who, "set_role", aid, "%s → %s" % (ROLE_NAMES[old], ROLE_NAMES[role]))
        return _card(con, _row(con, aid))
    return _run(root, go)


def ban(root: str, who: dict, body: dict) -> dict:
    _need(who, "mod")
    aid, reason = _id(body.get("id")), str(body.get("reason", "")).strip()[:200]

    def go(con):
        _over(con, who, aid)
        con.execute("UPDATE accounts SET banned = 1, ban_reason = ? WHERE id = ?", (reason, aid))
        con.execute("DELETE FROM sessions WHERE account_id = ?", (aid,))
        _log(con, who, "ban", aid, reason)
        return _card(con, _row(con, aid))
    return _run(root, go)


def unban(root: str, who: dict, body: dict) -> dict:
    _need(who, "mod")
    aid = _id(body.get("id"))

    def go(con):
        _over(con, who, aid)
        con.execute("UPDATE accounts SET banned = 0, ban_reason = NULL WHERE id = ?", (aid,))
        _log(con, who, "unban", aid)
        return _card(con, _row(con, aid))
    return _run(root, go)


def rename(root: str, who: dict, body: dict) -> dict:
    _need(who, "mod")
    aid, name = _id(body.get("id")), body.get("name")
    if not isinstance(name, str) or not accounts.NAME.match(name.strip()) or "  " in name:
        raise AdminError("tên không hợp lệ (3–16 ký tự)")

    def go(con):
        old = _over(con, who, aid)[2] or ""
        try:
            con.execute("UPDATE accounts SET name = ?, name_key = ? WHERE id = ?", (name.strip(), name.strip().casefold(), aid))
        except sqlite3.IntegrityError:
            raise AdminError("tên đã có người dùng", 409)
        _log(con, who, "rename", aid, "%s → %s" % (old, name.strip()))
        return _card(con, _row(con, aid))
    return _run(root, go)


def _drop(con, ids: list) -> int:
    for t in ("players", "items", "buys"):
        con.executemany("DELETE FROM %s WHERE match_id = ?" % t, [(m,) for m in ids])
    con.executemany("DELETE FROM matches WHERE id = ?", [(m,) for m in ids])
    return len(ids)


def delete_matches(root: str, who: dict, body: dict) -> dict:
    _need(who, "mod")
    aid = _id(body.get("id"))

    def go(con):
        _over(con, who, aid)
        ids = [m for (m,) in con.execute("SELECT DISTINCT match_id FROM players WHERE account_id = ?", (aid,))]
        n = _drop(con, ids)
        _log(con, who, "delete_matches", aid, "%d trận" % n)
        return {"deleted": n}
    return _run(root, go)


def delete_match(root: str, who: dict, body: dict) -> dict:
    _need(who, "mod")
    mid = _id(body.get("match"))

    def go(con):
        if con.execute("SELECT 1 FROM matches WHERE id = ?", (mid,)).fetchone() is None:
            raise AdminError("không có trận %d" % mid, 404)
        _drop(con, [mid])
        _log(con, who, "delete_match", "trận %d" % mid)
        return {"deleted": 1}
    return _run(root, go)
