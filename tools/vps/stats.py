"""Clashborn Stats (D-331, ROADMAP ST.2) — kho biên bản trận + số liệu kiểu Dotabuff. Thư viện chuẩn (sqlite3);
upload_server.py gọi.

Ghi:
  POST /api/match    (game gửi, KHÔNG cần mã — nginx giới hạn / IP) một biên bản MatchRecord (sim/world/match_record.gd)
  POST /api/matches  (cần mã) {"matches": [biên bản…]} — trận bot vs bot chạy hàng loạt (tools/stats/sim_matches.gd)
Đọc (công khai, trang clashborn.quest/stats/):
  GET /api/stats/summary | heroes | items | hero/<id>   ?mode=3v3&kind=pvb&version=0.1.560   (bỏ trống / all = tất cả)
Biên bản là dữ liệu người ngoài gửi: chỉ json.loads, kiểm từng trường (kiểu, khoảng, tên id), không tin gì khác (như
D-288). Trận thử (practice — MATCH-06: có nút Test), chưa có đội thắng, quá ngắn → bỏ. Không lưu IP / thiết bị. Lưu <root>/stats/stats.db.
"""
import json, os, re, sqlite3, threading, time

import accounts

SCHEMA = 1
MAX_BYTES = 64 * 1024        # một biên bản 3v3 ~3 KB
MAX_BATCH = 500
MIN_DURATION_S = 60.0
MAX_DURATION_S = 4 * 3600.0
START_S = 90.0              # "đồ khởi đầu" = mua trong 90 giây đầu (kiểu Dotabuff)
NAME = re.compile(r"^[a-z0-9_]{1,40}$")
VERSION = re.compile(r"^\d{1,3}\.\d{1,3}\.\d{1,6}$")
MODES = {"%dv%d" % (n, n): n for n in range(1, 6)}
KINDS = {"pvp", "pvb", "bvb"}
_lock = threading.Lock()

TABLES = """
CREATE TABLE IF NOT EXISTS matches (id INTEGER PRIMARY KEY, received TEXT, source TEXT, version TEXT, mode TEXT,
  kind TEXT, duration_s REAL, winner INTEGER);
CREATE TABLE IF NOT EXISTS players (match_id INTEGER, team INTEGER, slot INTEGER, hero TEXT, bot INTEGER, won INTEGER,
  kills INTEGER, deaths INTEGER, assists INTEGER, level INTEGER, gold INTEGER, last_hits INTEGER);
CREATE TABLE IF NOT EXISTS items (match_id INTEGER, team INTEGER, slot INTEGER, hero TEXT, item TEXT, won INTEGER);
CREATE TABLE IF NOT EXISTS buys (match_id INTEGER, team INTEGER, slot INTEGER, hero TEXT, item TEXT, t REAL, ord INTEGER,
  won INTEGER);
CREATE INDEX IF NOT EXISTS players_match ON players (match_id);
CREATE INDEX IF NOT EXISTS items_match ON items (match_id);
CREATE INDEX IF NOT EXISTS buys_match ON buys (match_id);
"""
# D-334: ô người chơi gắn tài khoản (lịch sử trận, ban → xóa trận); cột thêm sau khi VPS đã có dữ liệu.
# D-344: khóa trận online; D-405 (ST.5): ô người đã rớt lúc kết thúc (bot đánh thay — NET-17).
COLUMNS = {"players": [("account_id", "INTEGER"), ("left", "INTEGER")], "matches": [("match_key", "TEXT")]}
MATCH_KEY = re.compile(r"^\d{6}-\d{1,10}$")  # NET-15 (D-401): mã phòng 6 chữ số - seed
HISTORY = 20


def _db(root: str) -> sqlite3.Connection:
    d = os.path.join(root, "stats")
    os.makedirs(d, exist_ok=True)
    con = sqlite3.connect(os.path.join(d, "stats.db"), timeout=10)
    con.executescript(TABLES + accounts.TABLES)
    accounts.migrate(con, COLUMNS)
    accounts.migrate(con, accounts.COLUMNS)
    con.execute("CREATE INDEX IF NOT EXISTS players_account ON players (account_id)")
    con.execute("CREATE INDEX IF NOT EXISTS matches_key ON matches (match_key)")
    return con


def _int(v, lo: int, hi: int, what: str) -> int:
    if isinstance(v, bool) or not isinstance(v, (int, float)) or v != int(v) or not lo <= v <= hi:
        raise ValueError(what + " không hợp lệ")
    return int(v)


def _num(v, lo: float, hi: float, what: str) -> float:
    if isinstance(v, bool) or not isinstance(v, (int, float)) or not lo <= v <= hi:
        raise ValueError(what + " không hợp lệ")
    return float(v)


def _name(v, what: str) -> str:
    if not isinstance(v, str) or not NAME.match(v):
        raise ValueError(what + " không hợp lệ")
    return v


def check(rec) -> dict:
    """Biên bản hợp lệ (đã chuẩn hóa) hoặc ValueError."""
    if not isinstance(rec, dict) or rec.get("schema") != SCHEMA:
        raise ValueError("schema không hợp lệ")
    if rec.get("practice") is not False:
        raise ValueError("trận thử — không tính")
    version, mode, kind = rec.get("version"), rec.get("mode"), rec.get("kind")
    if not isinstance(version, str) or not VERSION.match(version) or mode not in MODES or kind not in KINDS:
        raise ValueError("version / mode / kind không hợp lệ")
    winner = _int(rec.get("winner"), 0, 1, "winner")
    out = {"version": version, "mode": mode, "kind": kind, "winner": winner,
           "duration_s": _num(rec.get("duration_s"), MIN_DURATION_S, MAX_DURATION_S, "duration_s"), "players": []}
    players = rec.get("players")
    n = MODES[mode]
    if not isinstance(players, list) or len(players) != 2 * n:
        raise ValueError("số người không khớp chế độ")
    for p in players:
        out["players"].append(_player(p, winner, n))
    if sorted(p["team"] for p in out["players"]) != [0] * n + [1] * n:
        raise ValueError("mỗi đội phải đủ người")
    if len({p["hero"] for p in out["players"]}) != 2 * n:
        raise ValueError("trùng tướng (MATCH-02)")
    return out


def online_from_game(rec) -> bool:
    """NET-12 (D-405): biên bản trận online do máy khách gửi (bản game cũ) — máy chủ phòng đã ghi trận này, bỏ qua."""
    return isinstance(rec, dict) and "match_key" in rec


def check_room(body) -> dict:
    """NET-12 (ST.5, D-405): biên bản của máy chủ phòng {record, match_key, accounts: [[ô, tài khoản]…], left: [ô…]}."""
    if not isinstance(body, dict):
        raise ValueError("cần object")
    out = check(body.get("record"))
    key, owners, left = body.get("match_key"), body.get("accounts"), body.get("left")
    if not isinstance(key, str) or not MATCH_KEY.match(key):
        raise ValueError("match_key không hợp lệ")
    if not isinstance(owners, list) or not isinstance(left, list):
        raise ValueError("accounts / left không hợp lệ")
    out["owners"] = {}
    for pair in owners:
        if not isinstance(pair, list) or len(pair) != 2:
            raise ValueError("accounts không hợp lệ")
        i = _int(pair[0], 0, len(out["players"]) - 1, "ô")
        if out["players"][i]["bot"]:
            raise ValueError("ô bot không có tài khoản")
        out["owners"][i] = _int(pair[1], 1, 2 ** 62, "tài khoản")
    out["left"] = {_int(i, 0, len(out["players"]) - 1, "ô rời") for i in left}
    if not out["left"] <= set(out["owners"]):
        raise ValueError("ô rời phải là ô người")
    out["match_key"] = key
    return out


def _player(p, winner: int, n: int) -> dict:
    if not isinstance(p, dict):
        raise ValueError("người chơi không hợp lệ")
    team = _int(p.get("team"), 0, 1, "team")
    out = {"hero": _name(p.get("hero"), "hero"), "team": team, "slot": _int(p.get("slot"), 0, n - 1, "slot"),
           "bot": bool(p.get("bot") is True), "won": team == winner}
    for key in ("kills", "deaths", "assists", "last_hits"):
        out[key] = _int(p.get(key), 0, 100000, key)
    out["level"] = _int(p.get("level"), 1, 100, "level")
    out["gold"] = _int(p.get("gold"), -100000, 10000000, "gold")
    items, buys = p.get("items"), p.get("buys")
    if not isinstance(items, list) or len(items) > 6 or not isinstance(buys, list) or len(buys) > 200:
        raise ValueError("đồ không hợp lệ")
    out["items"] = [_name(i, "item") for i in items]
    out["buys"] = []
    for b in buys:
        if not isinstance(b, list) or len(b) != 2:
            raise ValueError("lịch sử mua không hợp lệ")
        out["buys"].append([_num(b[0], 0.0, MAX_DURATION_S, "giây mua"), _name(b[1], "item")])
    return out


def load(body: bytes):
    try:
        return json.loads(body)
    except (ValueError, UnicodeDecodeError, RecursionError):  # D-288: lồng quá sâu cũng là JSON hỏng
        raise ValueError("không phải JSON")


def save(root: str, recs: list, source: str, account: int = -1) -> dict:
    """Ghi các biên bản đã kiểm (check); `account` ≥ 0: tài khoản gửi trận (gắn vào ô người). Trả {"ids": […]}."""
    ids = []
    with _lock:
        con = _db(root)
        try:
            for r in recs:
                owners = {i: account for i, p in enumerate(r["players"]) if not p["bot"]} if account >= 0 else {}
                ids.append(_insert(con, r, source, owners, set()))
            con.commit()
        finally:
            con.close()
    return {"ids": ids}


def save_room(root: str, r: dict) -> dict:
    """NET-12 (ST.5): biên bản máy chủ phòng (check_room) — trùng match_key (gửi lại sau lỗi mạng) → không ghi lại."""
    with _lock:
        con = _db(root)
        try:
            row = con.execute("SELECT id FROM matches WHERE match_key = ?", (r["match_key"],)).fetchone()
            if row is not None:
                return {"ids": [row[0]], "duplicate": True}
            mid = _insert(con, r, "room", r["owners"], r["left"])
            con.commit()
        finally:
            con.close()
    return {"ids": [mid]}


def _insert(con: sqlite3.Connection, r: dict, source: str, owners: dict, left: set) -> int:
    cur = con.execute("INSERT INTO matches (received, source, version, mode, kind, duration_s, winner, match_key) "
                      "VALUES (?,?,?,?,?,?,?,?)", (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), source, r["version"],
                                                   r["mode"], r["kind"], r["duration_s"], r["winner"], r.get("match_key")))
    mid = cur.lastrowid
    for i, p in enumerate(r["players"]):
        key = (mid, p["team"], p["slot"], p["hero"])
        con.execute("INSERT INTO players (match_id, team, slot, hero, bot, won, kills, deaths, assists, level, gold, last_hits, "
                    "account_id, left) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)", key + (int(p["bot"]), int(p["won"]), p["kills"],
                    p["deaths"], p["assists"], p["level"], p["gold"], p["last_hits"], owners.get(i), int(i in left)))
        for item in p["items"]:
            con.execute("INSERT INTO items VALUES (?,?,?,?,?,?)", key + (item, int(p["won"])))
        for order, (t, item) in enumerate(p["buys"]):
            con.execute("INSERT INTO buys VALUES (?,?,?,?,?,?,?,?)", key + (item, t, order, int(p["won"])))
    return mid


# ---- Đọc ---------------------------------------------------------------------------------------------------------

def filters(query: dict) -> dict:
    """Bộ lọc từ query string: mode / kind / version; giá trị lạ → bỏ qua (coi như tất cả)."""
    f = {}
    if query.get("mode") in MODES:
        f["mode"] = query["mode"]
    if query.get("kind") in KINDS:
        f["kind"] = query["kind"]
    if isinstance(query.get("version"), str) and VERSION.match(query["version"]):
        f["version"] = query["version"]
    return f


def _where(f: dict) -> tuple:
    cond = ["m.%s = ?" % k for k in ("mode", "kind", "version") if k in f]
    return (" WHERE " + " AND ".join(cond)) if cond else "", [f[k] for k in ("mode", "kind", "version") if k in f]


def _read(root: str, sql: str, args: list) -> list:
    con = _db(root)
    try:
        return con.execute(sql, args).fetchall()
    finally:
        con.close()


def summary(root: str, f: dict) -> dict:
    where, args = _where(f)
    total, avg = _read(root, "SELECT COUNT(*), AVG(duration_s) FROM matches m" + where, args)[0]
    versions = [v for (v,) in _read(root, "SELECT DISTINCT version FROM matches ORDER BY id DESC", [])]
    kinds = dict(_read(root, "SELECT kind, COUNT(*) FROM matches m%s GROUP BY kind" % where, args))
    modes = dict(_read(root, "SELECT mode, COUNT(*) FROM matches m%s GROUP BY mode" % where, args))
    return {"matches": total, "avg_duration_s": round(avg or 0.0, 1), "versions": versions, "kinds": kinds, "modes": modes}


def heroes(root: str, f: dict) -> list:
    where, args = _where(f)
    total = _read(root, "SELECT COUNT(*) FROM matches m" + where, args)[0][0] or 1
    rows = _read(root, "SELECT p.hero, COUNT(*), SUM(p.won), AVG(p.kills), AVG(p.deaths), AVG(p.assists), AVG(p.level), "
                 "AVG(p.last_hits) FROM players p JOIN matches m ON m.id = p.match_id%s GROUP BY p.hero" % where, args)
    return [{"hero": h, "games": g, "wins": w, "winrate": round(w / g, 4), "pickrate": round(g / total, 4),
             "kills": round(k, 2), "deaths": round(d, 2), "assists": round(a, 2), "level": round(lv, 2),
             "last_hits": round(lh, 1)} for h, g, w, k, d, a, lv, lh in sorted(rows, key=lambda r: -r[1])]


def items(root: str, f: dict, hero: str = "") -> list:
    """Đồ cuối trận: số lần có, tỉ lệ thắng; giây mua đầu tiên trung bình (theo buys)."""
    where, args = _where(f)
    extra = (" AND " if where else " WHERE ") + "x.hero = ?" if hero else ""
    args2 = args + ([hero] if hero else [])
    rows = _read(root, "SELECT x.item, COUNT(*), SUM(x.won) FROM items x JOIN matches m ON m.id = x.match_id%s%s "
                 "GROUP BY x.item" % (where, extra), args2)
    times = dict(_read(root, "SELECT item, AVG(t) FROM (SELECT x.item, MIN(x.t) AS t FROM buys x JOIN matches m ON "
                       "m.id = x.match_id%s%s GROUP BY x.match_id, x.team, x.slot, x.item) GROUP BY item" % (where, extra), args2))
    return [{"item": i, "games": g, "wins": w, "winrate": round(w / g, 4), "first_buy_s": round(times.get(i) or 0.0, 1)}
            for i, g, w in sorted(rows, key=lambda r: -r[1])]


def hero(root: str, hid: str, f: dict) -> dict:
    if not NAME.match(hid):
        raise KeyError(hid)
    where, args = _where(f)
    cond = (" AND " if where else " WHERE ")
    pair = ("SELECT q.hero, COUNT(*), SUM(p.won) FROM players p JOIN players q ON q.match_id = p.match_id AND %s "
            "JOIN matches m ON m.id = p.match_id%s%sp.hero = ? GROUP BY q.hero")
    vs = _read(root, pair % ("q.team != p.team", where, cond), args + [hid])
    allies = _read(root, pair % ("q.team = p.team AND q.slot != p.slot", where, cond), args + [hid])
    starts = _read(root, "SELECT x.item, COUNT(*), SUM(x.won) FROM buys x JOIN matches m ON m.id = x.match_id%s%s"
                   "x.hero = ? AND x.t <= ? GROUP BY x.item" % (where, cond), args + [hid, START_S])
    return {"hero": hid, "items": items(root, f, hid), "vs": _rate(vs, "hero"), "with": _rate(allies, "hero"),
            "start_items": _rate(starts, "item")}


def _rate(rows: list, key: str) -> list:
    return [{key: k, "games": g, "wins": w, "winrate": round(w / g, 4)} for k, g, w in sorted(rows, key=lambda r: -r[1])]


# ---- Người chơi (D-334) --------------------------------------------------------------------------------------------

def history(root: str, account: int, limit: int = HISTORY) -> list:
    """Trận gần nhất của tài khoản: tướng, kết quả, K/D/A, cấp, đồ cuối trận."""
    rows = _read(root, "SELECT m.id, m.received, m.version, m.mode, m.kind, m.duration_s, p.team, p.slot, p.hero, p.won, "
                 "p.kills, p.deaths, p.assists, p.level, p.last_hits, p.left FROM players p JOIN matches m ON m.id = p.match_id "
                 "WHERE p.account_id = ? ORDER BY m.id DESC LIMIT ?", [account, limit])
    out = []
    for mid, at, ver, mode, kind, dur, team, slot, hero_id, won, k, d, a, lv, lh, gone in rows:
        its = [i for (i,) in _read(root, "SELECT item FROM items WHERE match_id = ? AND team = ? AND slot = ?", [mid, team, slot])]
        row = {"match": mid, "at": at, "version": ver, "mode": mode, "kind": kind, "duration_s": round(dur, 1),
               "hero": hero_id, "won": bool(won), "kills": k, "deaths": d, "assists": a, "level": lv, "last_hits": lh,
               "items": its, "left": bool(gone), "allies": [], "enemies": []}
        for p in _lineup(root, mid, team, slot):  # D-343: cả hai đội
            row["allies" if p.pop("team") == team else "enemies"].append(p)
        out.append(row)
    return out


def _lineup(root: str, mid: int, my_team: int, my_slot: int) -> list:
    """Mọi ô của trận theo đội / ô: tướng, bot, tên trong game (không email; bị ban thì ẩn), K/D/A, cấp, đồ cuối trận."""
    rows = _read(root, "SELECT p.team, p.slot, p.hero, p.bot, p.kills, p.deaths, p.assists, p.level, a.name, a.banned, p.left "
                 "FROM players p LEFT JOIN accounts a ON a.id = p.account_id WHERE p.match_id = ? ORDER BY p.team, p.slot", [mid])
    items = {}
    for t, sl, it in _read(root, "SELECT team, slot, item FROM items WHERE match_id = ?", [mid]):
        items.setdefault((t, sl), []).append(it)
    return [{"team": t, "hero": h, "bot": bool(b), "name": (n or "") if not banned else "", "me": (t, sl) == (my_team, my_slot),
             "kills": k, "deaths": d, "assists": a, "level": lv, "items": items.get((t, sl), []), "left": bool(gone)}
            for t, sl, h, b, k, d, a, lv, n, banned, gone in rows]


def player(root: str, name: str) -> dict:
    """Trang người chơi công khai theo tên (không có email); tài khoản bị ban / không có → KeyError."""
    rows = _read(root, "SELECT id, name, banned FROM accounts WHERE name_key = ?", [name.strip().casefold()])
    if not rows or rows[0][2]:
        raise KeyError(name)
    aid, shown = rows[0][0], rows[0][1]
    per = _read(root, "SELECT hero, COUNT(*), SUM(won), AVG(kills), AVG(deaths), AVG(assists) FROM players WHERE "
                "account_id = ? GROUP BY hero", [aid])
    heroes_played = [{"hero": h, "games": g, "wins": w, "winrate": round(w / g, 4), "kills": round(k, 1),
                      "deaths": round(d, 1), "assists": round(a, 1)} for h, g, w, k, d, a in sorted(per, key=lambda r: -r[1])]
    games = sum(h["games"] for h in heroes_played)
    wins = sum(h["wins"] for h in heroes_played)
    return {"name": shown, "games": games, "wins": wins, "winrate": round(wins / games, 4) if games else 0.0,
            "heroes": heroes_played, "matches": history(root, aid)}

