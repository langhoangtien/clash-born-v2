#!/usr/bin/env python3
"""D-302: vẽ icon kỹ năng bằng API ảnh OpenAI, lấy một icon có sẵn làm mẫu style (viền vàng tròn, nền xanh than,
vẽ tay kiểu MOBA điện thoại). Key đọc từ biến môi trường OPEN_AI_API_KEY (không commit key).

  python3 tools/icons/gen_icon.py <mẫu.png> <ra.png> "mô tả nội dung icon" [--model gpt-image-1.5]

Ảnh ra 1024 px nền trong suốt → lưu nguyên vào art_inbox/04_icons (skill_<art_id>.png); tools/import_icons.py thu về 256 px.
"""
import argparse, base64, json, os, sys, uuid, urllib.request

STYLE = ("Mobile MOBA skill icon in exactly the same art style as the reference image: circular icon, thick golden "
         "rim, dark navy background inside the circle, bold hand-painted cartoon shading, clean readable silhouette, "
         "transparent background outside the circle, no text, no letters. Content: ")


def edit(ref, prompt, model):
    boundary = "----icon" + uuid.uuid4().hex
    parts = []
    def field(name, value):
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    field("model", model)
    field("prompt", STYLE + prompt)
    field("size", "1024x1024")
    field("background", "transparent")
    field("n", "1")
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="image[]"; filename="ref.png"\r\n'
                 'Content-Type: image/png\r\n\r\n'.encode() + open(ref, "rb").read() + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    req = urllib.request.Request("https://api.openai.com/v1/images/edits", data=b"".join(parts), method="POST",
                                 headers={"Authorization": "Bearer " + os.environ["OPEN_AI_API_KEY"],
                                          "Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(req, timeout=300) as r:
        return base64.b64decode(json.load(r)["data"][0]["b64_json"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ref")
    ap.add_argument("out")
    ap.add_argument("prompt")
    ap.add_argument("--model", default="gpt-image-1.5")
    a = ap.parse_args()
    open(a.out, "wb").write(edit(a.ref, a.prompt, a.model))
    print(a.out)


if __name__ == "__main__":
    sys.exit(main())
