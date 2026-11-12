"""D-287: test cổng báo cáo hiệu năng. Chạy: python3 -m unittest discover -s tools/vps -p 'test_*.py'"""
import json, os, sys, tempfile, threading, unittest, urllib.error, urllib.request
from http.server import ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reports, upload_server  # noqa: E402


class ServerCase(unittest.TestCase):
    """Máy chủ thử trong thư mục tạm (test_stats.py dùng lại); không có test riêng."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        upload_server.ROOT = self.tmp.name
        upload_server.TOKEN_FILE = os.path.join(self.tmp.name, "token")
        with open(upload_server.TOKEN_FILE, "w") as f:
            f.write("bi-mat\n")
        upload_server.ROOMS_TOKEN_FILE = os.path.join(self.tmp.name, "rooms_token")  # ST.5 (D-405)
        with open(upload_server.ROOMS_TOKEN_FILE, "w") as f:
            f.write("phong-bi-mat\n")
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), upload_server.Handler)
        self.url = "http://127.0.0.1:%d" % self.server.server_address[1]
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.tmp.cleanup()

    def call(self, method: str, path: str, body=None, token=None):
        data = body if isinstance(body, bytes) or body is None else json.dumps(body).encode()
        req = urllib.request.Request(self.url + path, data=data, method=method)
        if token:
            req.add_header("Authorization", "Bearer " + token)
        try:
            with urllib.request.urlopen(req) as res:
                return res.status, json.loads(res.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read())
        except urllib.error.URLError:  # máy chủ trả 413 rồi đóng kết nối, không đọc hết gói quá cỡ
            return 413, {}

class ReportServerTest(ServerCase):
    def report(self, kind="bench", note="máy nóng"):
        return {"kind": kind, "note": note, "summary": "Benchmark A/B …",
                "data": {"meta": {"version": "0.1.490", "device": "BTKR-W09"}, "segments": []}}

    def test_D_287_report_saved_without_token_and_read_with_token(self) -> None:
        code, got = self.call("POST", "/api/report", self.report())
        self.assertEqual((code, got["id"]), (200, "B-0001"))
        code, got = self.call("POST", "/api/report", self.report("log"))
        self.assertEqual(got["id"], "L-0002", "B và L chung một dãy số")
        code, got = self.call("GET", "/api/reports", token="bi-mat")
        self.assertEqual([r["id"] for r in got["reports"]], ["L-0002", "B-0001"], "mới nhất trước")
        self.assertEqual(got["reports"][1]["device"], "BTKR-W09")
        code, got = self.call("GET", "/api/reports/B-0001", token="bi-mat")
        self.assertEqual((code, got["note"], got["data"]["meta"]["version"]), (200, "máy nóng", "0.1.490"))
        code, got = self.call("GET", "/api/reports/latest", token="bi-mat")
        self.assertEqual(got["id"], "L-0002")
        self.assertFalse(os.path.exists(os.path.join(self.tmp.name, "www", "reports")), "không nằm trong www/")

    def test_D_336_sync_report_kind(self) -> None:
        code, got = self.call("POST", "/api/report", {"kind": "sync", "data": {"meta": {"version": "0.1.580"}, "seconds": []}})
        self.assertEqual((code, got["id"]), (200, "S-0001"))
        self.assertEqual(self.call("GET", "/api/reports/S-0001", token="bi-mat")[1]["kind"], "sync")

    def test_D_287_reading_needs_token(self) -> None:
        self.call("POST", "/api/report", self.report())
        self.assertEqual(self.call("GET", "/api/reports")[0], 401)
        self.assertEqual(self.call("GET", "/api/reports/B-0001", token="sai")[0], 401)
        self.assertEqual(self.call("GET", "/api/reports/../token", token="bi-mat")[0], 404)

    def test_D_287_rejects_bad_reports(self) -> None:
        self.assertEqual(self.call("POST", "/api/report", b"khong phai json")[0], 400)
        self.assertEqual(self.call("POST", "/api/report", {"kind": "khac", "data": {}})[0], 400)
        self.assertEqual(self.call("POST", "/api/report", {"kind": "log", "data": [1]})[0], 400)
        self.assertEqual(self.call("POST", "/api/report", {"kind": "log", "data": {}, "note": 5})[0], 400)
        big = {"kind": "log", "data": {"x": "a" * (reports.MAX_BYTES + 1)}}
        self.assertEqual(self.call("POST", "/api/report", big)[0], 413)
        self.assertEqual(self.call("GET", "/api/reports", token="bi-mat")[1]["reports"], [], "không lưu báo cáo hỏng")

    def test_D_288_hostile_reports_do_not_break_server(self) -> None:
        deep = b'{"kind": "log", "data": {"x": ' + b"[" * 200000 + b"]" * 200000 + b"}}"
        self.assertEqual(self.call("POST", "/api/report", deep)[0], 400, "lồng sâu: từ chối, không sập luồng")
        odd = {"kind": "bench", "data": {"meta": 5}, "note": "<script>alert(1)</script>"}
        self.assertEqual(self.call("POST", "/api/report", odd)[0], 200)
        self.call("POST", "/api/report", {"kind": "log", "data": {"meta": {"version": ["x"], "device": {"a": 1}}}})
        code, got = self.call("GET", "/api/reports", token="bi-mat")
        self.assertEqual(code, 200, "meta sai kiểu không làm hỏng danh sách")
        self.assertEqual([(r["version"], r["device"]) for r in got["reports"]], [("", ""), ("", "")])
        self.assertEqual(self.call("GET", "/api/health")[0], 200, "máy chủ vẫn chạy")

    def test_D_288_health_reports_deployed_commit(self) -> None:
        with open(os.path.join(self.tmp.name, "deployed"), "w") as f:
            f.write("abc1234\n")
        self.assertEqual(self.call("GET", "/api/health")[1], {"ok": True, "commit": "abc1234"})

    def test_D_287_note_is_trimmed(self) -> None:
        self.call("POST", "/api/report", self.report(note="  " + "x" * 900))
        got = self.call("GET", "/api/reports/latest", token="bi-mat")[1]
        self.assertEqual(len(got["note"]), reports.NOTE_MAX)

    def test_D_287_keeps_newest_reports_only(self) -> None:
        old = reports.KEEP
        reports.KEEP = 3
        try:
            for _ in range(5):
                self.call("POST", "/api/report", self.report())
        finally:
            reports.KEEP = old
        got = self.call("GET", "/api/reports", token="bi-mat")[1]
        self.assertEqual([r["id"] for r in got["reports"]], ["B-0005", "B-0004", "B-0003"])
        self.assertEqual(self.call("POST", "/api/report", self.report())[1]["id"], "B-0006", "số không quay lại")


if __name__ == "__main__":
    unittest.main()
