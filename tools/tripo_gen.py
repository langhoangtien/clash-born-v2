#!/usr/bin/env python3
"""Tạo mô hình 3D từ ảnh qua Tripo API (kit map, art_inbox/YEU_CAU_KIT_MAP.md).

Chạy: python3 tools/tripo_gen.py <ảnh.png> [<ảnh.png> ...] --faces 900 [--out art_inbox/3d/kit]
Key đọc từ biến môi trường TRIPO_API_KEY hoặc file ~/.secrets/tripo_key (không commit key vào repo).
Mỗi ảnh → <out>/<tên>.glb; in số credit trước và sau.
"""
import argparse, json, os, sys, time, urllib.request

API = "https://api.tripo3d.ai/v2/openapi"


def key():
    k = os.environ.get("TRIPO_API_KEY")
    if not k:
        k = open(os.path.expanduser("~/.secrets/tripo_key")).read().strip()
    return k


def call(path, data=None, headers=None, raw=None):
    h = {"Authorization": "Bearer " + key()} | (headers or {})
    body = raw if raw is not None else (json.dumps(data).encode() if data is not None else None)
    if data is not None:
        h["Content-Type"] = "application/json"
    req = urllib.request.Request(API + path, data=body, headers=h, method="POST" if body else "GET")
    with urllib.request.urlopen(req, timeout=120) as r:
        out = json.load(r)
    if out.get("code") != 0:
        raise RuntimeError(f"{path}: {out}")
    return out["data"]


def upload(png):
    boundary = "----tripo" + str(int(time.time() * 1000))
    name = os.path.basename(png)
    head = f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{name}"\r\nContent-Type: image/png\r\n\r\n'
    raw = head.encode() + open(png, "rb").read() + f"\r\n--{boundary}--\r\n".encode()
    return call("/upload", headers={"Content-Type": f"multipart/form-data; boundary={boundary}"}, raw=raw)["image_token"]


def generate(png, faces, out_dir):
    name = os.path.splitext(os.path.basename(png))[0]
    note = os.path.join(out_dir, name + ".task")
    if os.path.exists(note):  # đã gửi trước đó: chỉ chờ / tải lại, không tốn credit
        task = open(note).read().strip()
    else:
        task = call("/task", {"type": "image_to_model", "file": {"type": "png", "file_token": upload(png)},
                              "face_limit": faces, "texture": True, "pbr": False})["task_id"]
        open(note, "w").write(task)
    print(name, "task", task, flush=True)
    while True:
        d = call(f"/task/{task}")
        if d["status"] in ("success", "failed", "cancelled", "banned", "expired"):
            break
        time.sleep(5)
    if d["status"] != "success":
        raise RuntimeError(f"{png}: {d['status']}")
    o = d["output"]
    url = o.get("model") or o.get("pbr_model") or o.get("base_model")
    print(name, "url", url, flush=True)
    dst = os.path.join(out_dir, name + ".glb")
    urllib.request.urlretrieve(url, dst)
    return dst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("images", nargs="+")
    ap.add_argument("--faces", type=int, default=1000)
    ap.add_argument("--out", default="art_inbox/3d/kit")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    print("credit trước:", call("/user/balance")["balance"])
    for png in a.images:
        print("→", generate(png, a.faces, a.out), flush=True)
    print("credit sau:", call("/user/balance")["balance"])


if __name__ == "__main__":
    sys.exit(main())
