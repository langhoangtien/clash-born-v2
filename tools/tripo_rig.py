#!/usr/bin/env python3
"""Gắn xương + hoạt ảnh cho mô hình Tripo đã dựng (D-205).

Chạy: python3 tools/tripo_rig.py art_inbox/3d/neutral_wolf [--rig-type quadruped] [--anim preset:quadruped:walk]
Tham số là đường dẫn không đuôi; đọc <tên>.task (do tools/tripo_gen.py ghi) để biết task mô hình gốc.
Kết quả: <tên>_rig.glb (xương, tư thế gốc) và <tên>_<hoạt ảnh>.glb (mỗi --anim một file).
Mỗi bước ghi task vào <tên>_rig.task / <tên>_<hoạt ảnh>.task — chạy lại chỉ tải lại, không tốn credit.
Tripo rig 4 chân chỉ có hoạt ảnh đi (D-174) và với sói thì hỏng (D-205): thú 4 chân dùng
tools/models/rig_quadruped.py thay thế.
"""
import argparse, os, sys

sys.path.insert(0, os.path.dirname(__file__))
from tripo_gen import call, wait  # noqa: E402


def run(note, body):
    if os.path.exists(note):
        task = open(note).read().strip()
    else:
        task = call("/task", body)["task_id"]
        open(note, "w").write(task)
    print(os.path.basename(note), "task", task, flush=True)
    try:
        return task, wait(task)
    except RuntimeError:
        os.remove(note)  # task lỗi: lần chạy sau gửi lại
        raise


def save(d, dst):
    import urllib.request
    o = d["output"]
    url = o.get("model") or o.get("pbr_model") or o.get("base_model")
    urllib.request.urlretrieve(url, dst)
    print("→", dst, flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("base")
    ap.add_argument("--rig-type", default="quadruped")
    ap.add_argument("--anim", action="append", default=[])
    a = ap.parse_args()
    model = open(a.base + ".task").read().strip()
    print("credit trước:", call("/user/balance")["balance"])
    _, chk = run(a.base + "_check.task", {"type": "animate_prerigcheck", "original_model_task_id": model})
    print("prerigcheck:", chk.get("output"))
    rig, d = run(a.base + "_rig.task", {"type": "animate_rig", "original_model_task_id": model,
                                         "out_format": "glb", "rig_type": a.rig_type, "spec": "tripo",
                                         "model_version": "v2.0-20250506"})
    save(d, a.base + "_rig.glb")
    for anim in a.anim:
        tag = anim.split(":")[-1]
        _, d = run(f"{a.base}_{tag}.task", {"type": "animate_retarget", "original_model_task_id": rig,
                                             "out_format": "glb", "animation": anim})
        save(d, f"{a.base}_{tag}.glb")
    print("credit sau:", call("/user/balance")["balance"])


if __name__ == "__main__":
    sys.exit(main())
