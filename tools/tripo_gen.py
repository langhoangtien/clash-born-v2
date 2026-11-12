#!/usr/bin/env python3
"""Tạo mô hình 3D từ ảnh qua Tripo API (kit map, art_inbox/YEU_CAU_KIT_MAP.md).

Chạy: python3 tools/tripo_gen.py <ảnh.png> [<ảnh.png> ...] --faces 900 [--out art_inbox/3d]
Key đọc từ biến môi trường TRIPO_API_KEY hoặc file ~/.secrets/tripo_key (không commit key vào repo).
Mỗi ảnh → <out>/<tên>.glb; in số credit trước và sau.
--multiview: mỗi tham số là tên chung của bộ ảnh 3 hướng (phiếu T8, <tên>_front/_side/_back.png; _side là
nghiêng phải) → một mô hình <out>/<tên>.glb dựng từ cả ba ảnh; --views front,back: bỏ hướng có ảnh lệch tư thế; side_left: ảnh _side là nhìn từ bên trái (mũi vật quay sang trái ảnh — D-224).
--prompt "mô tả" (D-299): tham số là tên file ra, dựng từ câu mô tả (text_to_model) thay vì ảnh.
--model-version / --detailed (D-378): chọn đời mô hình Tripo và hình + ảnh màu chi tiết; --faces 0 = không giới hạn (giảm
tam giác sau bằng tools/models/decimate.py — giữ mặt / ngón tay tốt hơn face_limit của Tripo).
"""
import argparse, json, os, sys, time, urllib.request

API = "https://api.tripo3d.ai/v2/openapi"


def key():
    k = os.environ.get("TRIPO_API_KEY")
    if not k:
        k = open(os.path.expanduser("~/.secrets/tripo_key")).read().strip()
    return k


def call(path, data=None, headers=None, raw=None):
    h = {"Authorization": "Bearer " + key(), "User-Agent": "curl/8"} | (headers or {})  # D-347: API cũng chặn UA urllib (403)
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


def request(png, faces, multiview, use=("front", "side", "back"), prompt=None):
    if prompt:
        return {"type": "text_to_model", "prompt": prompt}
    if not multiview:
        return {"type": "image_to_model", "file": {"type": "png", "file_token": upload(png)}}
    # thứ tự Tripo: trước, trái, sau, phải; thiếu hướng nào để trống (D-211: bỏ ảnh nghiêng lệch tư thế)
    side = png + "_side.png"
    views = [png + "_front.png" if "front" in use else None, side if "side_left" in use else None,
             png + "_back.png" if "back" in use else None, side if "side" in use else None]
    files = [{"type": "png", "file_token": upload(v)} if v else {} for v in views]
    return {"type": "multiview_to_model", "files": files}


def wait(task):
    """Chờ task Tripo xong, trả dữ liệu task; lỗi nếu không thành công."""
    while True:
        d = call(f"/task/{task}")
        if d["status"] in ("success", "failed", "cancelled", "banned", "expired"):
            break
        time.sleep(5)
    if d["status"] != "success":
        raise RuntimeError(f"task {task}: {d['status']}")
    return d


def generate(png, faces, out_dir, multiview=False, use=("front", "side", "back"), prompt=None, extra=None):
    name = os.path.splitext(os.path.basename(png))[0]
    note = os.path.join(out_dir, name + ".task")
    if os.path.exists(note):  # đã gửi trước đó: chỉ chờ / tải lại, không tốn credit
        task = open(note).read().strip()
    else:
        body = request(png, faces, multiview, use, prompt) | {"texture": True, "pbr": False} | (extra or {})
        if faces > 0:
            body["face_limit"] = faces
        task = call("/task", body)["task_id"]
        open(note, "w").write(task)
    print(name, "task", task, flush=True)
    o = wait(task)["output"]
    url = o.get("model") or o.get("pbr_model") or o.get("base_model")
    print(name, "url", url, flush=True)
    dst = os.path.join(out_dir, name + ".glb")
    req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})  # CDN Tripo chặn UA mặc định của urllib (403)
    with urllib.request.urlopen(req, timeout=300) as r, open(dst, "wb") as f:
        f.write(r.read())
    return dst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("images", nargs="+")
    ap.add_argument("--faces", type=int, default=1000)
    ap.add_argument("--out", default="art_inbox/3d")
    ap.add_argument("--multiview", action="store_true")
    ap.add_argument("--views", default="front,side,back", help="hướng dùng khi --multiview (vd front,back)")
    ap.add_argument("--prompt", default=None, help="dựng từ câu mô tả; tham số đầu là tên file ra")
    ap.add_argument("--model-version", default=None, help="vd v3.0-20250812")
    ap.add_argument("--detailed", action="store_true", help="geometry_quality + texture_quality = detailed")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    print("credit trước:", call("/user/balance")["balance"])
    for png in a.images:
        extra = {"model_version": a.model_version} if a.model_version else {}
        if a.detailed:
            extra |= {"geometry_quality": "detailed", "texture_quality": "detailed"}
        print("→", generate(png, a.faces, a.out, a.multiview, a.views.split(","), a.prompt, extra), flush=True)
    print("credit sau:", call("/user/balance")["balance"])


if __name__ == "__main__":
    sys.exit(main())
