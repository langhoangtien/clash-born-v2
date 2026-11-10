"""D-334: trận gắn tài khoản, lịch sử trận, trang người chơi, quản trị (ban / đổi tên / xóa trận), nâng cấp bảng cũ.
Chạy: python3 -m unittest discover -s tools/vps -p 'test_*.py'"""
import json, os, sqlite3, sys, urllib.error, urllib.parse, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import accounts, stats  # noqa: E402
from test_accounts import AccountCase  # noqa: E402
from test_stats import record  # noqa: E402


class AdminTest(AccountCase):
    def req(self, method, path, body=None, session=None, token=None):
        data = json.dumps(body).encode() if body is not None else (b"" if method == "POST" else None)
        r = urllib.request.Request(self.url + path, data=data, method=method)
        if session:
            r.add_header("X-Clashborn-Session", session)
        if token:
            r.add_header("Authorization", "Bearer " + token)
        try:
            with urllib.request.urlopen(r) as res:
                return res.status, json.loads(res.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read())

    def player_with_match(self):
        token = self.signup("an@gmail.com")
        self.auth("name", {"name": "Lăng"}, session=token)
        self.assertEqual(self.req("POST", "/api/match", record(0), session=token)[0], 200)
        self.assertEqual(self.req("POST", "/api/match", record(1))[0], 200, "không đăng nhập vẫn gửi được (không gắn ai)")
        return token, self.auth("me", session=token, method="GET")[1]["id"]

    def test_D_334_match_linked_history_and_player_page(self) -> None:
        token, _ = self.player_with_match()
        got = self.req("GET", "/api/auth/history", session=token)[1]["matches"]
        self.assertEqual([(m["hero"], m["won"], m["items"]) for m in got], [("gorran", True, ["iron_branch"])],
                         "chỉ trận của mình, ô người (không phải ô bot)")
        code, page = self.req("GET", "/api/stats/player/" + urllib.parse.quote("lăng"))
        self.assertEqual((code, page["name"], page["games"], page["wins"]), (200, "Lăng", 1, 1))
        self.assertNotIn("email", json.dumps(page), "trang công khai không có email")
        self.assertEqual(self.req("GET", "/api/stats/player/khong-co")[0], 404)

    def test_D_334_admin_needs_token(self) -> None:
        self.assertEqual(self.req("GET", "/api/admin/accounts?q=")[0], 401)
        self.assertEqual(self.req("POST", "/api/admin/ban", {"id": 1}, token="sai")[0], 401)

    def test_D_334_ban_blocks_everything_then_unban(self) -> None:
        token, aid = self.player_with_match()
        found = self.req("GET", "/api/admin/accounts?q=an%40gmail", token="bi-mat")[1]["accounts"]
        self.assertEqual([(a["id"], a["games"]) for a in found], [(aid, 1)])
        self.assertTrue(self.req("POST", "/api/admin/ban", {"id": aid, "reason": "hack vàng"}, token="bi-mat")[1]["banned"])
        self.assertEqual(self.auth("me", session=token, method="GET")[0], 401, "ban → đăng xuất mọi máy")
        code, got = self.auth("login", {"email": "an@gmail.com", "password": "matkhau123"})
        self.assertEqual((code, got["code"]), (403, "BANNED"))
        self.assertIn("hack vàng", got["error"])
        self.assertEqual(self.req("GET", "/api/stats/player/Lăng".replace("ă", "%C4%83"))[0], 404, "trang người bị ban ẩn")
        self.req("POST", "/api/admin/unban", {"id": aid}, token="bi-mat")
        self.assertEqual(self.auth("login", {"email": "an@gmail.com", "password": "matkhau123"})[0], 200)
        log = self.req("GET", "/api/admin/log", token="bi-mat")[1]["log"]
        self.assertEqual([e["action"] for e in log], ["unban", "ban"], "nhật ký thao tác, mới nhất trước")

    def test_D_334_banned_upload_rejected(self) -> None:
        token, aid = self.player_with_match()
        fresh = self.auth("login", {"email": "an@gmail.com", "password": "matkhau123"})[1]["token"]
        con = stats._db(self.tmp.name)  # ban thẳng trong kho (giữ phiên) để thử nhánh gửi trận
        con.execute("UPDATE accounts SET banned = 1 WHERE id = ?", (aid,))
        con.commit()
        con.close()
        self.assertEqual(self.req("POST", "/api/match", record(0), session=fresh)[1].get("code"), "BANNED")

    def test_D_334_delete_matches_rename(self) -> None:
        token, aid = self.player_with_match()
        self.assertEqual(self.req("GET", "/api/stats/summary")[1]["matches"], 2)
        self.assertEqual(self.req("POST", "/api/admin/delete_matches", {"id": aid}, token="bi-mat")[1], {"deleted": 1})
        self.assertEqual(self.req("GET", "/api/stats/summary")[1]["matches"], 1, "trận của người hack biến khỏi thống kê")
        self.assertEqual(self.req("POST", "/api/admin/delete_match", {"match": 2}, token="bi-mat")[1], {"deleted": 1})
        self.assertEqual(self.req("POST", "/api/admin/delete_match", {"match": 2}, token="bi-mat")[0], 404)
        self.assertEqual(self.req("POST", "/api/admin/rename", {"id": aid, "name": "Người Chơi 1"}, token="bi-mat")[1]["name"],
                         "Người Chơi 1")
        self.assertEqual(self.req("POST", "/api/admin/rename", {"id": aid, "name": "x"}, token="bi-mat")[0], 400)

    def test_D_335_roles_admin_grants_mod_acts(self) -> None:
        boss = self.signup("boss@x.vn")
        mod = self.signup("mod@x.vn")
        user = self.signup("user@x.vn")
        ids = {k: self.auth("me", session=t, method="GET")[1]["id"] for k, t in (("boss", boss), ("mod", mod), ("user", user))}
        self.assertEqual(self.req("GET", "/api/admin/accounts?q=", session=user)[0], 403, "người chơi thường không vào được")
        self.assertEqual(self.req("POST", "/api/admin/set_role", {"id": ids["boss"], "role": "admin"}, token="bi-mat")[0], 200,
                         "mã quản trị cấp admin đầu tiên")
        self.assertEqual(self.req("GET", "/api/admin/whoami", session=boss)[1], {"name": "", "role": "admin"})
        self.assertEqual(self.req("POST", "/api/admin/set_role", {"id": ids["mod"], "role": "mod"}, session=boss)[1]["role"], "mod")
        self.assertEqual(self.auth("me", session=mod, method="GET")[1]["role"], "mod")
        self.assertEqual(self.req("POST", "/api/admin/ban", {"id": ids["user"], "reason": "spam"}, session=mod)[0], 200,
                         "mod ban được người chơi")
        self.assertEqual(self.req("POST", "/api/admin/ban", {"id": ids["boss"]}, session=mod)[0], 403, "mod không ban được admin")
        self.assertEqual(self.req("POST", "/api/admin/set_role", {"id": ids["user"], "role": "mod"}, session=mod)[0], 403,
                         "mod không cấp quyền")
        self.assertEqual(self.req("POST", "/api/admin/set_role", {"id": ids["boss"], "role": ""}, session=boss)[0], 403,
                         "không tự đổi quyền mình")
        log = self.req("GET", "/api/admin/log", session=boss)[1]["log"]
        self.assertEqual([(e["action"], e["actor"].split(" ")[0]) for e in log][:3],
                         [("ban", "#%d" % ids["mod"]), ("set_role", "#%d" % ids["boss"]), ("set_role", "mã")],
                         "nhật ký ghi ai làm")
        self.req("POST", "/api/admin/set_role", {"id": ids["mod"], "role": ""}, session=boss)
        self.assertEqual(self.req("GET", "/api/admin/accounts?q=", session=mod)[0], 403, "thu quyền → hết vào được")

    def test_D_334_old_database_upgraded(self) -> None:
        path = os.path.join(self.tmp.name, "stats")
        os.makedirs(path, exist_ok=True)
        old = sqlite3.connect(os.path.join(path, "stats.db"))
        old.execute("CREATE TABLE players (match_id INTEGER, team INTEGER, slot INTEGER, hero TEXT, bot INTEGER, won INTEGER, "
                    "kills INTEGER, deaths INTEGER, assists INTEGER, level INTEGER, gold INTEGER, last_hits INTEGER)")
        old.execute("CREATE TABLE accounts (id INTEGER PRIMARY KEY, email TEXT UNIQUE, pw_hash TEXT, verified INTEGER DEFAULT 0, "
                    "name TEXT, name_key TEXT UNIQUE, google_sub TEXT UNIQUE, created TEXT, fails INTEGER DEFAULT 0, "
                    "locked_until REAL DEFAULT 0)")
        old.commit()
        old.close()
        self.player_with_match()  # bảng cũ thiếu cột → tự thêm, chạy bình thường
        con = sqlite3.connect(os.path.join(path, "stats.db"))
        self.assertIn("account_id", {r[1] for r in con.execute("PRAGMA table_info(players)")})
        self.assertIn("banned", {r[1] for r in con.execute("PRAGMA table_info(accounts)")})
        con.close()


if __name__ == "__main__":
    import unittest
    unittest.main()
