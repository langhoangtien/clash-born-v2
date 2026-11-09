#!/usr/bin/env python3
"""D-304: vẽ concept nhân vật bằng API ảnh OpenAI (chế độ sửa ảnh, nhiều ảnh mẫu). Key: biến môi trường OPEN_AI_API_KEY.

  python3 tools/concept_gen.py <ra.png> "mô tả" <mẫu1.png> [<mẫu2.png> ...] [--size 1536x1024] [--model gpt-image-1.5]

Dùng cho tờ 3 góc nhìn (trước / ngang / sau) → tools/split_turnaround.py tách thành <tên>_front/_side/_back.png cho Tripo.
"""
import argparse, base64, json, os, sys, uuid, urllib.request


def edit(refs, prompt, model, size):
    boundary = "----cg" + uuid.uuid4().hex
    parts = []
    def field(name, value):
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    for k, v in (("model", model), ("prompt", prompt), ("size", size), ("n", "1"), ("quality", "high")):
        field(k, v)
    for i, ref in enumerate(refs):
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="image[]"; filename="ref{i}.png"\r\n'
                     'Content-Type: image/png\r\n\r\n'.encode() + open(ref, "rb").read() + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    req = urllib.request.Request("https://api.openai.com/v1/images/edits", data=b"".join(parts), method="POST",
                                 headers={"Authorization": "Bearer " + os.environ["OPEN_AI_API_KEY"],
                                          "Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return base64.b64decode(json.load(r)["data"][0]["b64_json"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("prompt")
    ap.add_argument("refs", nargs="+")
    ap.add_argument("--size", default="1536x1024")
    ap.add_argument("--model", default="gpt-image-1.5")
    a = ap.parse_args()
    open(a.out, "wb").write(edit(a.refs, a.prompt, a.model, a.size))
    print(a.out)


if __name__ == "__main__":
    sys.exit(main())
