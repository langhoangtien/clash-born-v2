"""D-333: test tài khoản (accounts.py + /api/auth/*) với mail giả và Google giả.
Chạy: python3 -m unittest discover -s tools/vps -p 'test_*.py'"""
import json, os, re, sys, time, urllib.error, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import accounts  # noqa: E402
from test_reports import ServerCase  # noqa: E402


class AccountCase(ServerCase):
    """Máy chủ thử + mail / Google giả + gọi /api/auth (test_admin.py dùng lại); không có test riêng."""

    def setUp(self) -> None:
        super().setUp()
        self.mails = []
        accounts.send_mail = lambda to, subject, body: self.mails.append((to, subject, body))
        accounts.google_cfg = lambda: {"client_id": "cid", "client_secret": "sec"}
        self.google_user = {"sub": "g-1", "email": "an@gmail.com", "email_verified": True}
        accounts.http_json = lambda url, form=None, bearer="": (
            {"access_token": "at"} if "token" in url else dict(self.google_user))

    def tearDown(self) -> None:
        accounts.send_mail, accounts.http_json, accounts.google_cfg = accounts._smtp_send, accounts._http_json, accounts._google_cfg
        super().tearDown()

    def auth(self, path, body=None, session=None, method="POST"):
        data = json.dumps(body or {}).encode() if method == "POST" else None
        req = urllib.request.Request(self.url + "/api/auth/" + path, data=data, method=method)
        if session:
            req.add_header("X-Clashborn-Session", session)
        try:
            with urllib.request.urlopen(req) as r:
                return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read())

    def code(self) -> str:
        return re.search(r"\b(\d{6})\b", self.mails[-1][2]).group(1)

    def signup(self, email="an@gmail.com", password="matkhau123") -> str:
        self.assertEqual(self.auth("register", {"email": email, "password": password})[0], 200)
        return self.auth("verify", {"email": email, "code": self.code()})[1]["token"]

class AccountTest(AccountCase):
    def test_D_333_register_verify_login_name_logout(self) -> None:
        self.assertEqual(self.auth("register", {"email": "An@Gmail.com ", "password": "matkhau123"})[0], 200)
        self.assertEqual(self.mails[-1][0], "an@gmail.com", "email chuẩn hóa")
        code, got = self.auth("login", {"email": "an@gmail.com", "password": "matkhau123"})
        self.assertEqual((code, got["code"]), (403, "NOT_VERIFIED"))
        self.assertEqual(self.auth("verify", {"email": "an@gmail.com", "code": "000000"})[1].get("code"), "BAD_CODE")
        code, got = self.auth("verify", {"email": "an@gmail.com", "code": self.code()})
        self.assertEqual(code, 200)
        token = got["token"]
        self.assertEqual(self.auth("me", session=token, method="GET")[1]["email"], "an@gmail.com")
        code, got = self.auth("login", {"email": "an@gmail.com", "password": "matkhau123"})
        self.assertEqual(code, 200)
        self.assertEqual(self.auth("name", {"name": "Lăng Tiến"}, session=token)[1]["name"], "Lăng Tiến", "tên tiếng Việt")
        other = self.signup("binh@gmail.com")
        self.assertEqual(self.auth("name", {"name": "lăng tiến"}, session=other)[1]["code"], "NAME_TAKEN", "không trùng (hoa / thường)")
        self.assertEqual(self.auth("name", {"name": "ab"}, session=other)[1]["code"], "BAD_NAME")
        self.assertEqual(self.auth("logout", session=token)[0], 200)
        self.assertEqual(self.auth("me", session=token, method="GET")[0], 401)
        self.assertEqual(self.auth("register", {"email": "an@gmail.com", "password": "khac12345"})[1]["code"], "EMAIL_TAKEN")

    def test_D_333_bad_input_and_lockout(self) -> None:
        self.assertEqual(self.auth("register", {"email": "khong-phai-mail", "password": "matkhau123"})[1]["code"], "BAD_EMAIL")
        self.assertEqual(self.auth("register", {"email": "c@x.vn", "password": "ngan"})[1]["code"], "BAD_PASSWORD")
        self.signup("c@x.vn")
        for _ in range(accounts.LOCK_FAILS):
            self.assertEqual(self.auth("login", {"email": "c@x.vn", "password": "sai-mat-khau"})[1]["code"], "BAD_LOGIN")
        self.assertEqual(self.auth("login", {"email": "c@x.vn", "password": "matkhau123"})[1]["code"], "LOCKED",
                         "sai 10 lần → khóa, kể cả mật khẩu đúng")
        self.assertEqual(self.auth("login", {"email": "khong@co.vn", "password": "x" * 9})[1]["code"], "BAD_LOGIN",
                         "email không có cùng câu báo (không lộ)")

    def test_D_333_code_tries_and_reset_password(self) -> None:
        old = self.signup("d@x.vn")
        self.assertEqual(self.auth("reset", {"email": "khong@co.vn"})[1], {"sent": True}, "không lộ email nào có tài khoản")
        self.assertEqual(len([m for m in self.mails if m[0] == "khong@co.vn"]), 0)
        self.auth("reset", {"email": "d@x.vn"})
        for _ in range(accounts.CODE_TRIES):
            self.auth("reset_finish", {"email": "d@x.vn", "code": "999999", "password": "moi-12345"})
        code = self.code()
        self.assertEqual(self.auth("reset_finish", {"email": "d@x.vn", "code": code, "password": "moi-12345"})[1]["code"],
                         "CODE_EXPIRED", "sai 5 lần → mã hết hiệu lực")
        self.auth("reset", {"email": "d@x.vn"})
        code, got = self.auth("reset_finish", {"email": "d@x.vn", "code": self.code(), "password": "moi-12345"})
        self.assertEqual(code, 200)
        self.assertEqual(self.auth("me", session=old, method="GET")[0], 401, "đặt lại mật khẩu → đăng xuất máy khác")
        self.assertEqual(self.auth("login", {"email": "d@x.vn", "password": "moi-12345"})[0], 200)

    def test_D_333_google_login_links_same_email(self) -> None:
        email_token = self.signup("an@gmail.com")
        code, start = self.auth("google/start")
        self.assertIn("accounts.google.com", start["url"])
        self.assertIn("state=" + start["sid"], start["url"])
        self.assertEqual(self.auth("google/poll", {"sid": start["sid"]})[1], {"pending": True})
        with urllib.request.urlopen(self.url + "/api/auth/google/callback?code=abc&state=" + start["sid"]) as r:
            self.assertIn("Đã đăng nhập", r.read().decode())
        code, got = self.auth("google/poll", {"sid": start["sid"]})
        self.assertEqual(got["account"]["id"], self.auth("me", session=email_token, method="GET")[1]["id"],
                         "cùng email đã xác minh → cùng tài khoản")
        self.assertTrue(got["account"]["google"])
        self.assertEqual(self.auth("google/poll", {"sid": start["sid"]})[0], 410, "phiên Google dùng một lần")
        self.google_user = {"sub": "g-2", "email": "moi@gmail.com", "email_verified": True}
        sid = self.auth("google/start")[1]["sid"]
        urllib.request.urlopen(self.url + "/api/auth/google/callback?code=x&state=" + sid).read()
        got = self.auth("google/poll", {"sid": sid})[1]
        self.assertEqual((got["account"]["email"], got["account"]["has_password"]), ("moi@gmail.com", False), "tài khoản mới")
        with urllib.request.urlopen(self.url + "/api/auth/google/callback?code=x&state=gia-mao") as r:
            self.assertIn("Chưa đăng nhập được", r.read().decode())

    def test_D_333_delete_account(self) -> None:
        token = self.signup("f@x.vn")
        self.assertEqual(self.auth("delete")[0], 401, "cần phiên")
        self.assertEqual(self.auth("delete", session=token)[1], {"deleted": True})
        self.assertEqual(self.auth("me", session=token, method="GET")[0], 401)
        self.assertEqual(self.auth("login", {"email": "f@x.vn", "password": "matkhau123"})[1]["code"], "BAD_LOGIN")
        self.signup("f@x.vn")  # đăng ký lại được bằng email đó

    def test_D_333_secrets_never_stored_plain(self) -> None:
        token = self.signup("e@x.vn", "bi-mat-123")
        with open(os.path.join(self.tmp.name, "stats", "stats.db"), "rb") as f:
            db = f.read()
        self.assertNotIn(b"bi-mat-123", db)
        self.assertNotIn(token.encode(), db)


if __name__ == "__main__":
    import unittest
    unittest.main()
