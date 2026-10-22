#!/usr/bin/env python3
"""Tạo hiệu ứng âm thanh bằng ElevenLabs Sound Effects API (D-111).

  set ELEVENLABS_API_KEY=...          (Windows)   /  export ELEVENLABS_API_KEY=...
  python tools/sfx_gen/generate.py                # tạo các tiếng chưa có
  python tools/sfx_gen/generate.py --only ui_buy cast_brakk_q --force   # làm lại vài tiếng
  python tools/sfx_gen/generate.py --variants 3   # mỗi tiếng 3 bản: <id>__v1.mp3… để chọn
  python tools/sfx_gen/generate.py --kind music_   # chỉ nhạc nền (vo_ = giọng thông báo)

Gồm: hiệu ứng (Sound Effects), giọng thông báo tiếng Anh (Text to Speech), nhạc nền (Music).

Ghi ra art_inbox/06_audio/<id>.mp3. KHÔNG commit khóa API. Chỉ dùng thư viện chuẩn Python.
"""
import argparse, json, os, sys, time, urllib.request, urllib.error

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LIST = os.path.join(os.path.dirname(__file__), "sounds.json")
OUT = os.path.join(ROOT, "art_inbox", "06_audio")
API = "https://api.elevenlabs.io/v1"
URL = API + "/sound-generation?output_format=mp3_44100_128"


def post(key, url, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST",
                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return r.read()


def jobs(data):
    """(id, url, body) cho mọi tiếng: hiệu ứng, giọng thông báo, nhạc."""
    for s in data["sounds"]:
        body = {"text": s["text"] + ", " + data["style"], "model_id": "eleven_text_to_sound_v2",
                "prompt_influence": s.get("influence", 0.4), "loop": s.get("loop", False)}
        if s.get("duration"):
            body["duration_seconds"] = s["duration"]
        yield s["id"], URL, body
    v = data["voice"]
    voice = os.environ.get("ELEVENLABS_VOICE_ID") or v["voice_id"]
    for line in v["lines"]:
        yield line["id"], f"{API}/text-to-speech/{voice}?output_format=mp3_44100_128", \
            {"text": line["text"], "model_id": v["model_id"], "voice_settings": v["settings"]}
    m = data["music"]
    for t in m["tracks"]:
        yield t["id"], f"{API}/music?output_format=mp3_44100_128", \
            {"prompt": t["prompt"], "music_length_ms": t["length_ms"], "model_id": m["model_id"], "force_instrumental": True}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--variants", type=int, default=1)
    ap.add_argument("--kind", default=None, help="chỉ làm id bắt đầu bằng: vo_ (giọng), music_ (nhạc)…")
    a = ap.parse_args()
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        sys.exit("Thiếu biến môi trường ELEVENLABS_API_KEY")
    data = json.load(open(LIST, encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)
    for sid, url, body in jobs(data):
        if a.only and sid not in a.only:
            continue
        if a.kind and not sid.startswith(a.kind):
            continue
        for v in range(1, a.variants + 1):
            name = sid + (f"__v{v}" if a.variants > 1 else "") + ".mp3"
            path = os.path.join(OUT, name)
            if os.path.exists(path) and not a.force:
                print("  có rồi", name)
                continue
            for attempt in range(3):
                try:
                    audio = post(key, url, body)
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
