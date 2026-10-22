#!/usr/bin/env python3
"""Tạo hiệu ứng âm thanh bằng ElevenLabs Sound Effects API (D-111).

  set ELEVENLABS_API_KEY=...          (Windows)   /  export ELEVENLABS_API_KEY=...
  python tools/sfx_gen/generate.py                # tạo các tiếng chưa có
  python tools/sfx_gen/generate.py --only ui_buy cast_brakk_q --force   # làm lại vài tiếng
  python tools/sfx_gen/generate.py --variants 3   # mỗi tiếng 3 bản: <id>__v1.mp3… để chọn

Ghi ra art_inbox/06_audio/<id>.mp3. KHÔNG commit khóa API. Chỉ dùng thư viện chuẩn Python.
"""
import argparse, json, os, sys, time, urllib.request, urllib.error

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LIST = os.path.join(os.path.dirname(__file__), "sounds.json")
OUT = os.path.join(ROOT, "art_inbox", "06_audio")
URL = "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128"


def generate(key, text, duration, influence, loop):
    body = {"text": text, "model_id": "eleven_text_to_sound_v2", "prompt_influence": influence, "loop": loop}
    if duration:
        body["duration_seconds"] = duration
    req = urllib.request.Request(URL, data=json.dumps(body).encode(), method="POST",
                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--variants", type=int, default=1)
    a = ap.parse_args()
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        sys.exit("Thiếu biến môi trường ELEVENLABS_API_KEY")
    data = json.load(open(LIST, encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)
    for s in data["sounds"]:
        if a.only and s["id"] not in a.only:
            continue
        for v in range(1, a.variants + 1):
            name = s["id"] + (f"__v{v}" if a.variants > 1 else "") + ".mp3"
            path = os.path.join(OUT, name)
            if os.path.exists(path) and not a.force:
                print("  có rồi", name)
                continue
            text = s["text"] + ", " + data["style"]
            for attempt in range(3):
                try:
                    audio = generate(key, text, s.get("duration"), s.get("influence", 0.4), s.get("loop", False))
                    open(path, "wb").write(audio)
                    print("  xong", name, len(audio), "byte")
                    break
                except urllib.error.HTTPError as e:
                    print("  lỗi", name, e.code, e.read()[:300])
                    if e.code in (401, 403, 422):
                        break
                    time.sleep(5 * (attempt + 1))


if __name__ == "__main__":
    main()
