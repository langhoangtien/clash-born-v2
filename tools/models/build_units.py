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
#       [, vũ khí gắn cứng "tệp:xương"] [, tham số thêm cho glb_slim])
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
    "noctis": ("noctis_afk_mx.glb", "heroes/noctis",  # D-248: T9d (bỏ áo choàng); D-249: đánh + lén từ Mixamo
               "Fighting Idle=idle,Sprint@0-0.83=run,MX Mutant Punch=attack,MX Stable Sword Outward Slash@0.4-1.4=attack_2,"
               "Hit_Chest=hit,Death_B=death,Idle Hurt=stun,Sword_Regular_A=cast,Spell_Simple_Shoot=skill_2,"
               "Throw Object=skill_3,Sprint=sprint,MX Run (1)~=stealth,Sword_Dash_RM~@0.2-0.9=dash", True, False,
               ["noctis_dagger_r:hand_r", "noctis_dagger_l:hand_l"]),
    "brakk": ("brakk", "heroes/brakk",
              "Fighting Idle=idle,Jog=run,Melee_Hook+Melee_Hook_Rec=attack,Hit_Chest=hit,Death_B=death,Idle Hurt=stun,"
              "Punch_Cross=cast,NinjaJump_Start@0.2-0.96+NinjaJump_Land@0-0.7=skill_1,Defend=skill_2,Power Up=skill_3,"
              "Sprint=sprint",
              True, False),
    # D-304: Myra / Vexa bản người lớn (concept_gen.py → split_turnaround.py → Tripo multiview → afk.ai), tay không
    # D-321: Gorran dựng lại theo quy trình Brakk (concept T9 bỏ goblin trên lưng — Codex T15 → Tripo multiview → glb_yaw −90 →
    # afk.ai human); W Lọ Độc = ném qua vai, Q Vũng Axit = tung lựu đạn, R Cuồng Hóa = gồng sức; D-322: đánh = chém kiếm,
    # Cuồng Hóa đánh bằng combo hai kiếm (attack_rage, units_3d.json effect_looks).
    "gorran": ("gorran/gorran_lo", "heroes/gorran",  # D-322: Blender giảm 6002 → 3200 tam giác rồi rig lại; 2 kiếm Blender
               "Fighting Idle=idle,Jog=run,Sword_Regular_A+Sword_Regular_A_Rec=attack,Dual_Weapon_Combo@2.2-3.3=attack_rage,"
               "Hit_Chest=hit,Death_B=death,Idle Hurt=stun,"
               "Throw_Generic=cast,Grenade_Toss=skill_1,OverhandThrow=skill_2,Power Up=skill_3,Sprint=sprint",
               True, False, ["gorran/gorran_sword_r:hand_r", "gorran/gorran_sword_l:hand_l"]),
    "myra": ("myra_v2", "heroes/myra",
             "Idle_A=idle,Run_Female=run,Magic_1H_Attack=attack,Hit_Chest=hit,Death_B=death,Idle Hurt=stun,"
             "Magic_1H_Cast=cast,Magic_1H_Cast@0.7-1.5=skill_1,Magic_Area_2@1.2-2.2=skill_2,Magic_Area@0.6-1.8=skill_3,"
             "Sprint=sprint",  # D-321: đoạn ~1 s quanh lúc ra đòn (đứng vung 0,3–0,4 s, cast_time)
             True, False),
    "vexa": ("vexa_v2", "heroes/vexa",
             "Idle_A=idle,Run_Female=run,Magic_1H_Attack_2=attack,Hit_Chest=hit,Death_B=death,Idle Hurt=stun,"
             "Magic_1H_Cast=cast,Magic_2H_Attack_2@0.6-1.6=skill_1,Spell_Wide@1.0-2.2=skill_2,Magic_1H_Cast@0.7-1.5=skill_3,"
             "Sprint=sprint",  # D-321
             True, False),
    # D-307b: tê giác theo style ảnh mẫu người chơi (concept_gen.py từ ảnh mẫu → split_turnaround.py →
    # Tripo multiview → glb_yaw -90 → afk.ai: dragon / horse → fix-stretching)
    # D-309: Người Đá thay rồng (concept_gen theo ảnh mẫu bãi đấu → Tripo → afk.ai human); fix-stretching + drop_loose (tam giác lẻ kéo dài); đòn đánh = đấm móc (đấm đất kéo méo nắm tay)
    # D-318: bản rêu bỏ hai tấm đá mỏng sau bàn tay (lưới Tripo có sẵn, gắn xương ngón → đấm là văng): drop_loose --max-tris 40
    "golem_moss": ("golem/golem_moss_afk_drop.glb", "creatures/golem_moss",
                   "Fighting Idle=idle,Walk_Large=run,Melee_Hook+Melee_Hook_Rec=attack,Hit_Chest=hit,Death_B=death,Idle Hurt=stun",
                   True, False),
    "golem_lava": ("golem/golem_lava_afk_clean.glb", "creatures/golem_lava",
                   "Fighting Idle=idle,Walk_Large=run,Melee_Hook+Melee_Hook_Rec=attack,Hit_Chest=hit,Death_B=death,Idle Hurt=stun",
                   True, False),
    "rhino": ("creatures/rhino_afk_fix.glb", "creatures/rhino", "Idle=idle,Run=run,Head_But=attack,Hit=hit,Death=death",
              False, False),
}


def build(name):
    src, dst, keep, fingers, team = UNITS[name][:5]
    attach = UNITS[name][5] if len(UNITS[name]) > 5 else []
    slim = UNITS[name][6] if len(UNITS[name]) > 6 else []  # D-307c: tham số thêm cho glb_slim (vd --tint)
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
                       + (TEAM if team else []) + slim, check=True)


def main():
    for name in sys.argv[1:] or UNITS:
        build(name)


if __name__ == "__main__":
    main()
