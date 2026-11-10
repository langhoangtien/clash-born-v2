#!/usr/bin/env python3
"""M9.3 (D-336): so hai kết quả kiểm tra tất định (SyncCheck) — file JSON của tools/sync_check.gd hoặc báo cáo S-xxxx
lấy từ máy chủ (GET /api/reports/S-0001, phần "data"). In giây lệch đầu tiên và các đơn vị lệch ở giây đó.
  python3 -I tools/sync_compare.py a.json b.json
"""
import json, sys


def load(path: str) -> dict:
    d = json.load(open(path, encoding="utf-8"))
    return d.get("data", d)


def main() -> int:
    a, b = load(sys.argv[1]), load(sys.argv[2])
    print("A:", a["meta"])
    print("B:", b["meta"])
    for sa, sb in zip(a["seconds"], b["seconds"]):
        if sa["hash"] != sb["hash"]:
            ua, ub = sa["units"], sb["units"]
            diff = sorted({k for k in set(ua) | set(ub) if ua.get(k) != ub.get(k)}, key=int)
            print("LỆCH ở giây %d: %d đơn vị khác — id %s" % (sa["t"], len(diff), diff[:30]))
            if not diff:
                print("  (mọi đơn vị giống — lệch ở RNG / cửa hàng / bộ đếm PRD / số đơn vị)")
            return 1
    n = min(len(a["seconds"]), len(b["seconds"]))
    print("KHỚP: %d giây giống hệt nhau" % n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
