"""D-331: test Clashborn Stats (stats.py + đường /api/match, /api/matches, /api/stats/*).
Chạy: python3 -m unittest discover -s tools/vps -p 'test_*.py'"""
import copy, os, sys, unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_reports import ServerCase  # noqa: E402  (máy chủ thử + call())


def record(winner=0, heroes=("gorran", "myra"), kind="pvb", items0=("iron_branch",)):
    players = []
    for i, h in enumerate(heroes):
        team = i // (len(heroes) // 2)
        players.append({"hero": h, "team": team, "slot": i % (len(heroes) // 2), "bot": i > 0, "won": team == winner,
                        "kills": 2, "deaths": 1, "assists": 3, "level": 12, "gold": 900, "last_hits": 80,
                        "items": list(items0) if i == 0 else ["boots"], "buys": [[12.5, "iron_branch"], [300.0, "boots"]]})
    n = len(heroes) // 2
    return {"schema": 1, "version": "0.1.560", "mode": "%dv%d" % (n, n), "kind": kind, "duration_s": 1500.0,
            "winner": winner, "seed": 1, "cheats": False, "players": players}


class StatsTest(ServerCase):
    def test_D_331_match_saved_without_token_and_counted(self) -> None:
        self.assertEqual(self.call("POST", "/api/match", record(0))[0], 200)
        self.assertEqual(self.call("POST", "/api/match", record(1))[0], 200)
        code, got = self.call("GET", "/api/stats/heroes")
        self.assertEqual(code, 200)
        g = {h["hero"]: h for h in got["heroes"]}
        self.assertEqual((g["gorran"]["games"], g["gorran"]["wins"], g["gorran"]["winrate"], g["gorran"]["pickrate"]),
                         (2, 1, 0.5, 1.0))
        code, got = self.call("GET", "/api/stats/items")
        it = {i["item"]: i for i in got["items"]}
        self.assertEqual((it["iron_branch"]["games"], it["iron_branch"]["first_buy_s"]), (2, 12.5))
        code, got = self.call("GET", "/api/stats/hero/gorran")
        self.assertEqual(got["vs"][0]["hero"], "myra")
        self.assertEqual(got["start_items"][0]["item"], "iron_branch")
        code, got = self.call("GET", "/api/stats/summary")
        self.assertEqual((got["matches"], got["versions"], got["kinds"]), (2, ["0.1.560"], {"pvb": 2}))

    def test_D_331_filters_by_mode_kind_version(self) -> None:
        self.call("POST", "/api/match", record(0))
        self.call("POST", "/api/match", record(1, ("brakk", "myra", "vexa", "noctis", "gorran", "duy_anh"), "bvb"))
        got = self.call("GET", "/api/stats/heroes?mode=3v3")[1]["heroes"]
        self.assertEqual(len(got), 6)
        got = self.call("GET", "/api/stats/heroes?kind=pvb&version=0.1.560")[1]["heroes"]
        self.assertEqual(sorted(h["hero"] for h in got), ["gorran", "myra"])
        self.assertEqual(self.call("GET", "/api/stats/heroes?version=0.1.1")[1]["heroes"], [])
        self.assertEqual(self.call("GET", "/api/stats/summary?mode=bad")[1]["matches"], 2, "bộ lọc lạ = tất cả")

    def test_D_331_bad_records_rejected(self) -> None:
        bad = []
        r = record(); r["cheats"] = True; bad.append(r)
        r = record(heroes=("gorran", "gorran")); bad.append(r)
        r = record(); r["mode"] = "9v9"; bad.append(r)
        r = record(); r["duration_s"] = 5.0; bad.append(r)
        r = record(); r["players"][0]["hero"] = "../../etc"; bad.append(r)
        r = record(); r["players"][0]["items"] = ["x"] * 7; bad.append(r)
        r = record(); r["players"].pop(); bad.append(r)
        r = record(); r["winner"] = -1; bad.append(r)
        for r in bad:
            self.assertEqual(self.call("POST", "/api/match", r)[0], 400, str(r)[:120])
        self.assertEqual(self.call("POST", "/api/match", b"{not json")[0], 400)
        self.assertEqual(self.call("GET", "/api/stats/summary")[1]["matches"], 0)
        self.assertEqual(self.call("GET", "/api/stats/hero/..%2Ftoken")[0], 404)

    def test_D_331_batch_needs_token(self) -> None:
        body = {"matches": [record(0), record(1)]}
        self.assertEqual(self.call("POST", "/api/matches", body)[0], 401)
        code, got = self.call("POST", "/api/matches", body, token="bi-mat")
        self.assertEqual((code, len(got["ids"])), (200, 2))
        broken = copy.deepcopy(body)
        broken["matches"][1]["kind"] = "x"
        self.assertEqual(self.call("POST", "/api/matches", broken, token="bi-mat")[0], 400, "một trận sai → bỏ cả lô")
        self.assertEqual(self.call("GET", "/api/stats/summary")[1]["matches"], 2)


if __name__ == "__main__":
    unittest.main()
