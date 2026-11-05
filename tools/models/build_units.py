#!/usr/bin/env python3
"""Dựng lại mọi mô hình đơn vị afk.ai cho game (D-216): chọn hoạt ảnh (glb_anims.py) rồi thu ảnh (glb_slim.py).

  python3 -I tools/models/build_units.py [tên …]     # không tên: dựng tất cả
Nguồn: art_inbox/3d/<nguồn>_afk.glb (afk.ai, đủ hoạt ảnh — giữ để sau đổi / thêm hoạt ảnh không phải rig lại), hoặc
tên file `.glb` trong art_inbox/3d (vd bản Mixamo gộp bằng mixamo_pack.py, D-238).
Tên hoạt ảnh game theo rig `Creature` (units_3d.json): idle / run / attack / hit / death, `stun` tùy chọn (ST-01).
Đổi hoạt ảnh: sửa bảng UNITS; `impact` (điểm trúng của đòn) nằm trong units_3d.json.
"""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
FINGERS = "^(index|middle|pinky|ring|thumb)_|_leaf"  # bộ xương người: bỏ ngón tay (D-209)
TEAM = ["--team", "--hue", "195-245"]  # màu phe xanh → đỏ (D-209)

# tên: (nguồn, đích trong assets/models/style/, hoạt ảnh, bỏ xương (True = FINGERS, hoặc regex), màu phe
#       [, vũ khí gắn cứng "tệp:xương"])
UNITS = {
    "creep_melee": ("creep_melee", "units/creep_melee",
                    "Idle_A=idle,Jog=run,OverhandThrow=attack,Hit_Chest=hit,Death_B=death,Dizzy=stun", True, True),
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
    "duy_anh": ("duy_anh_afk_mx.glb", "heroes/duy_anh",  # D-242: rig afk.ai; W chuyển từ Mixamo (retarget.py); D-243: R nhảy 3 đoạn afk
                "Fighting Idle=idle,Sprint@0-0.83=run,OverhandThrow=attack,Hit_Chest=hit,Death_B=death,Idle Hurt=stun,"
                "Sword_Regular_A+Sword_Regular_A_Rec@0.6=cast,Shield_OneShot=skill_1,MX sword and shield slash=skill_2,"
                "Sprint=sprint,Jump_Start@0.2-0.6+Jump_air@0-0.3+Jump_Land@0-0.6=dash", True, False,
                ["duy_anh_sword_hand:hand_r", "duy_anh_shield_hand:hand_l"]),
    "noctis": ("noctis", "heroes/noctis",  # D-246: vẽ lại T9c (áo choàng gọn sau lưng), hai dao
               "Fighting Idle=idle,Sprint@0-0.83=run,Punch_Cross=attack,Hit_Chest=hit,Death_B=death,Idle Hurt=stun,"
               "Sword_Regular_A=cast,Spell_Simple_Shoot=skill_2,Throw Object=skill_3,Sprint=sprint,Run_Stealth=stealth,"
               "Sword_Dash_RM~@0.2-0.9=dash", True, False,
               ["noctis_dagger_r:hand_r", "noctis_dagger_l:hand_l"]),
    "brakk": ("brakk", "heroes/brakk",
              "Fighting Idle=idle,Jog=run,Melee_Hook+Melee_Hook_Rec=attack,Hit_Chest=hit,Death_B=death,Idle Hurt=stun,"
              "Punch_Cross=cast,NinjaJump_Start@0.2-0.96+NinjaJump_Land@0-0.7=skill_1,Defend=skill_2,Power Up=skill_3,"
              "Sprint=sprint",
              True, False),
}


def build(name):
    src, dst, keep, fingers, team = UNITS[name][:5]
    attach = UNITS[name][5] if len(UNITS[name]) > 5 else []
    with tempfile.TemporaryDirectory() as tmp:
        mid = os.path.join(tmp, "anims.glb")
        cmd = [sys.executable, "-I", os.path.join(HERE, "glb_anims.py"),
               os.path.join(ROOT, "art_inbox", "3d", src if src.endswith(".glb") else src + "_afk.glb"), mid,
               "--keep", keep]
        for spec in attach:
            f, bone = spec.split(":", 1)
            cmd += ["--attach", os.path.join(ROOT, "art_inbox", "3d", f + ".glb") + ":" + bone]
        subprocess.run(cmd + (["--drop-bones", fingers if isinstance(fingers, str) else FINGERS] if fingers else []), check=True)
        out = os.path.join(ROOT, "assets", "models", "style", dst + ".glb")
        subprocess.run([sys.executable, "-I", os.path.join(HERE, "glb_slim.py"), mid, out, "--size", "1024"]
                       + (TEAM if team else []), check=True)


def main():
    for name in sys.argv[1:] or UNITS:
        build(name)


if __name__ == "__main__":
    main()
