#!/usr/bin/env python3
"""Nhập âm thanh từ art_inbox/06_audio/<id>.mp3 vào assets/audio/<id>.ogg (D-113). Cần ffmpeg.

  python3 tools/import_audio.py            # nhập tất cả (bỏ qua bản thử <id>__vN.mp3)
  python3 tools/import_audio.py --report   # chỉ in độ lớn trước / sau

- Cân độ lớn theo nhóm (LUFS mục tiêu dưới, đo trên file gốc), bộ giới hạn giữ đỉnh ≤ -1 dBFS.
  Clip < 0.4 s sau khi cắt đo ra -70 LUFS là do ebur128 cần ≥ 0.4 s, không phải câm.
- Hiệu ứng / giọng: mono, cắt khoảng lặng cuối, mờ dần 30 ms ở cuối.
- Nhạc và tiếng nền: stereo, giữ nguyên độ dài (lặp trong game).
OGG Vorbis: Godot (cả bản web) đọc tốt, nhỏ, lặp liền mạch (MP3 có khoảng hở ở đầu/cuối).
"""
import argparse, os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "art_inbox", "06_audio")
DST = os.path.join(ROOT, "assets", "audio")
# (tiền tố, LUFS mục tiêu); tiếng không khớp tiền tố nào dùng DEFAULT.
GROUPS = [("music_", -20.0), ("amb_", -26.0), ("vo_", -14.0), ("ui_", -19.0), ("creep_", -21.0),
          ("hit_", -18.0), ("shot_", -18.0), ("tower_", -17.0), ("cast_", -16.0), ("state_", -17.0)]
DEFAULT = -16.0
LONG = ("music_", "amb_")
PEAK_LIMIT = -1.0
MAX_GAIN = 24.0  # tiếng gần như câm thì không kéo lên quá mức (sẽ ra tiếng ồn)


def measure(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=sample",
                          "-f", "null", "-"], capture_output=True, text=True).stderr
    lufs = float(re.findall(r"^\s+I:\s+(-?[\d.]+) LUFS", out, re.M)[-1])
    peak = float(re.findall(r"^\s+Peak:\s+(-?[\d.inf]+) dBFS", out, re.M)[-1])
    return lufs, peak


def target(sid):
    for prefix, lufs in GROUPS:
        if sid.startswith(prefix):
            return lufs
    return DEFAULT


def convert(sid, src, dst):
    lufs, _peak = measure(src)
    gain = max(-30.0, min(MAX_GAIN, target(sid) - lufs))
    chain = [f"volume={gain:.2f}dB", f"alimiter=limit={10 ** (PEAK_LIMIT / 20):.3f}:level=disabled"]
    if sid.startswith(LONG):
        args = ["-ac", "2", "-q:a", "3"]
    else:  # cắt khoảng lặng cuối, mờ dần 30 ms ở cuối
        chain = ["areverse", "silenceremove=start_periods=1:start_threshold=-50dB", "afade=t=in:d=0.03",
                 "areverse"] + chain
        args = ["-ac", "1", "-q:a", "4"]
    subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", src, "-af", ",".join(chain),
                    "-ar", "44100", "-c:a", "libvorbis"] + args + [dst], check=True)
    return lufs, gain

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()
    if not os.path.isdir(SRC):
        sys.exit("chưa có " + SRC)
    os.makedirs(DST, exist_ok=True)
    for name in sorted(os.listdir(SRC)):
        if not name.endswith(".mp3") or "__v" in name:
            continue
        sid = name[:-4]
        src, dst = os.path.join(SRC, name), os.path.join(DST, sid + ".ogg")
        if a.report:
            print("  %-22s %6.1f LUFS" % (sid, measure(src)[0]))
            continue
        lufs, gain = convert(sid, src, dst)
        after = measure(dst)[0]
        print("  %-22s %6.1f -> %6.1f LUFS (%+.1f dB)" % (sid, lufs, after, gain))


if __name__ == "__main__":
    main()
