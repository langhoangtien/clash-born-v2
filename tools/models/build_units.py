#!/usr/bin/env python3
"""Dựng lại mọi mô hình đơn vị afk.ai cho game (D-216): chọn hoạt ảnh (glb_anims.py) rồi thu ảnh (glb_slim.py).

  python3 -I tools/models/build_units.py [tên …]     # không tên: dựng tất cả
Nguồn: art_inbox/3d/<nguồn>_afk.glb (afk.ai, đủ hoạt ảnh — giữ để sau đổi / thêm hoạt ảnh không phải rig lại).
Tên hoạt ảnh game theo rig `Creature` (units_3d.json): idle / run / attack / hit / death, `stun` tùy chọn (ST-01).
Đổi hoạt ảnh: sửa bảng UNITS; `impact` (điểm trúng của đòn) nằm trong units_3d.json.
"""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
FINGERS = "^(index|middle|pinky|ring|thumb)_|_leaf"  # bộ xương người: bỏ ngón tay (D-209)
TEAM = ["--team", "--hue", "195-245"]  # màu phe xanh → đỏ (D-209)

# tên: (nguồn, đích trong assets/models/style/, hoạt ảnh, bỏ xương, màu phe)
UNITS = {
    "creep_melee": ("creep_melee", "units/creep_melee",
                    "Idle_Sword=idle,Jog=run,OverhandThrow=attack,Hit_Chest=hit,Death_B=death,Dizzy=stun", True, True),
    "creep_ranged": ("creep_ranged", "units/creep_ranged",
                     "Idle_A=idle,Jog=run,OverhandThrow=attack,Hit_Chest=hit,Death_B=death,Dizzy=stun", True, True),
    "neutral_wolf": ("neutral_wolf", "creatures/wolf", "Idle=idle,Run=run,Attack=attack,Hit=hit,Death=death", False, False),
    "neutral_bear": ("neutral_bear", "creatures/bear", "Idle=idle,Run=run,Attack=attack,Hit=hit,Death=death", False, False),
    "neutral_buffalo": ("neutral_buffalo", "creatures/golem",
                        "Fighting Idle=idle,Jog=run,Sword_Attack@0.5-1.92=attack,Hit_Chest=hit,Death_B=death,Dizzy=stun",
                        True, False),
    "neutral_shaman": ("neutral_shaman", "creatures/shaman",
                       "Idle_A=idle,Jog=run,OverhandThrow=attack,Hit_Chest=hit,Death_B=death,Dizzy=stun", True, False),
    # D-228: hero Tripo + afk.ai (skill_1/2/3 = chiêu Q/W/R, cast = tung chiêu chung; RM = có dời gốc → không dùng)
    "duy_anh": ("duy_anh", "heroes/duy_anh",
                "Idle_Sword=idle,Jog=run,Sword_Regular_A+Sword_Regular_A_Rec@0.6=attack,Hit_Chest=hit,Death_B=death,"
                "Idle Hurt=stun,Sword_Regular_B@0.5+Sword_Regular_B_Rec=cast,Shield_OneShot=skill_1,"
                "Sword_Attack@0.5-1.92=skill_2,Sprint=sprint,Sword_Dash_RM~@0.2-0.9=dash", True, False),
    "brakk": ("brakk", "heroes/brakk",
              "Fighting Idle=idle,Jog=run,Fighting Right Jab=attack,Hit_Chest=hit,Death_B=death,Idle Hurt=stun,"
              "Punch_Cross=cast,Attack_Ground_Pound@1.05-2.4=skill_1,Defend=skill_2,Power Up=skill_3,Sprint=sprint",
              True, False),
}


def build(name):
    src, dst, keep, fingers, team = UNITS[name]
    with tempfile.TemporaryDirectory() as tmp:
        mid = os.path.join(tmp, "anims.glb")
        cmd = [sys.executable, "-I", os.path.join(HERE, "glb_anims.py"),
               os.path.join(ROOT, "art_inbox", "3d", src + "_afk.glb"), mid, "--keep", keep]
        subprocess.run(cmd + (["--drop-bones", FINGERS] if fingers else []), check=True)
        out = os.path.join(ROOT, "assets", "models", "style", dst + ".glb")
        subprocess.run([sys.executable, "-I", os.path.join(HERE, "glb_slim.py"), mid, out, "--size", "1024"]
                       + (TEAM if team else []), check=True)


def main():
    for name in sys.argv[1:] or UNITS:
        build(name)


if __name__ == "__main__":
    main()
