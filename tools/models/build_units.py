#!/usr/bin/env python3
"""Dựng lại mọi mô hình đơn vị afk.ai cho game (D-216): chọn hoạt ảnh (glb_anims.py) rồi thu ảnh (glb_slim.py).

  python3 -I tools/models/build_units.py [tên …] [--out thư_mục]     # không tên: dựng tất cả
--out (D-367): ghi <thư_mục>/<tên>.glb thay vì assets/models/style/<đích>.glb — bản thử chưa vào game.
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
    # afk.ai human); W Lọ Độc = ném qua vai, Q Vũng Axit = tung lựu đạn. D-322: giảm mặt + 2 kiếm Blender. D-323: đánh thường
    # = đấm móc; Cuồng Hóa (R) rút hai kiếm sau vai (GS_Draw đối xứng `%`), đánh luân phiên tay phải / tay trái (bản soi
    # gương `^`) — units_3d.json effect_looks. D-325: chém = đòn dựng bằng code `!` (glb_slash.py: giơ cao qua vai phải,
    # chém chéo xuống hông trái, chân đứng yên). D-324: bao kiếm + cán kiếm đeo sau lưng (gắn spine_03), cán ẩn khi đã rút.
    "gorran": ("gorran/gorran_lo", "heroes/gorran",
               "Fighting Idle=idle,Jog=run,Melee_Hook+Melee_Hook_Rec=attack,"
               "Fighting Idle!@0-0.1=attack_rage,Fighting Idle!^@0-0.1=attack_rage_l,"
               "Hit_Chest=hit,Death_B=death,Idle Hurt=stun,"
               "Throw_Generic=cast,Grenade_Toss=skill_1,OverhandThrow=skill_2,GS_Draw%@0.2-1.3=skill_3,Sprint=sprint",
               True, False, ["gorran/gorran_sword_r:hand_r", "gorran/gorran_sword_l:hand_l", "gorran/gorran_sheath_r:spine_03",
                                "gorran/gorran_sheath_l:spine_03", "gorran/gorran_hilt_r:spine_03", "gorran/gorran_hilt_l:spine_03"]),
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
    # D-347: Phong Tiễn (chuẩn quy trình tướng mới): Codex tờ 3 góc khăn choàng NGẮN, tay không → split_turnaround → Tripo
    # multiview 2500 + cung riêng → glb_yaw −90 → afk.ai human (593 hoạt ảnh) → cung gắn cứng tay trái (place_prop --rot 90,0,0).
    # Đánh = kéo dây + buông (bỏ đoạn hạ cung); Q né xoay người; W kéo nhanh + buông (tung 0,3 s); R bị động.
    # D-350 (đã hoàn tác): đẩy tay cung ra 12 cm lúc chạy bằng afk-rig adjust — người chơi thấy không đẹp bằng, vẫn vào chân.
    "phong_tien": ("phong_tien/phong_tien", "heroes/phong_tien",
                   "Bow_Casual=idle,Run_Female=run,Bow Pull Back@0.5-1.25+Bow Release=attack,Hit_Chest=hit,Death_B=death,"
                   "Idle_Dizzy=stun,Bow Pull Back@0.75-1.25+Bow Release=cast,Dodge_left=skill_1,"
                   "Bow_Draw@1.3-2.07+Bow Release=skill_2,Sprint=sprint",
                   True, False, ["phong_tien/phong_tien_bow_hand:hand_l"]),
    # D-367: Phong Tiễn PA3 (D-364, D-366) — bản thử số tam giác (A2), chỉ dựng với --out art_inbox/3d/phong_tien_v2;
    # 6k / 12k GIỮ xương ngón tay (fingers = False), 3k = giảm tam giác chính lưới 6k (decimate.py) rồi gắn xương lại, bỏ ngón
    "phong_tien_v2_3k": ("phong_tien_v2/f3000/phong_tien_v2", "heroes/phong_tien",
                         "Bow_Casual=idle,Run_Female=run,Bow Pull Back@0.5-1.25+Bow Release=attack,Hit_Chest=hit,Death_B=death,"
                         "Idle_Dizzy=stun,Bow Pull Back@0.75-1.25+Bow Release=cast,Dodge_left=skill_1,"
                         "Bow_Draw@1.3-2.07+Bow Release=skill_2,Sprint=sprint",
                         True, False, ["phong_tien_v2/f3000/phong_tien_v2_bow_nostring_hand:hand_l"]),
    "phong_tien_v2_6k": ("phong_tien_v2/f6000/phong_tien_v2", "heroes/phong_tien",
                         "Bow_Casual=idle,Run_Female=run,Bow Pull Back@0.5-1.25+Bow Release=attack,Hit_Chest=hit,Death_B=death,"
                         "Idle_Dizzy=stun,Bow Pull Back@0.75-1.25+Bow Release=cast,Dodge_left=skill_1,"
                         "Bow_Draw@1.3-2.07+Bow Release=skill_2,Sprint=sprint",
                         "_leaf", False, ["phong_tien_v2/f6000/phong_tien_v2_bow_nostring_hand:hand_l"]),
    "phong_tien_v2_12k": ("phong_tien_v2/f12000/phong_tien_v2", "heroes/phong_tien",
                         "Bow_Casual=idle,Run_Female=run,Bow Pull Back@0.5-1.25+Bow Release=attack,Hit_Chest=hit,Death_B=death,"
                         "Idle_Dizzy=stun,Bow Pull Back@0.75-1.25+Bow Release=cast,Dodge_left=skill_1,"
                         "Bow_Draw@1.3-2.07+Bow Release=skill_2,Sprint=sprint",
                         "_leaf", False, ["phong_tien_v2/f12000/phong_tien_v2_bow_nostring_hand:hand_l"]),
    # D-372: Phong Tiễn style mới (D-370, người chơi chọn 6k + ngón tay)
    "phong_tien_v3": ("phong_tien_v3/phong_tien_v3", "heroes/phong_tien",
                         "Bow_Casual=idle,Run_Female=run,Bow Pull Back@0.5-1.25+Bow Release=attack,Hit_Chest=hit,Death_B=death,"
                         "Idle_Dizzy=stun,Bow Pull Back@0.75-1.25+Bow Release=cast,Dodge_left=skill_1,"
                         "Bow_Draw@1.3-2.07+Bow Release=skill_2,Sprint=sprint",
                         "_leaf", False, ["phong_tien_v3/phong_tien_v3_bow_nostring_hand:hand_l"]),
    # D-373: Phong Tiễn mới + hoạt ảnh Mixamo Pro Longbow (người chơi tải): dựng thẳng từ rig Mixamo (ngón trỏ + cái
    # nắm cán cung), cung đặt theo khung ngắm (bow_grip.py); bỏ xương đầu mút (_End, ngón đốt 4)
    "phong_tien_v3_mx": ("phong_tien_v3/phong_tien_v3_mx.glb", "heroes/phong_tien",
                         "standing idle 01=idle,standing run forward~=run,standing draw arrow+standing aim recoil=attack,"
                         "standing react small from front=hit,standing death backward 01=death,standing idle 02 looking=stun,"
                         "standing draw arrow@0-1.07+standing aim recoil@0-0.73=cast,standing dodge left~=skill_1,"
                         "standing aim overdraw@1.2-2.6+standing aim recoil@0-0.72=skill_2,standing run forward@0-0.9~=sprint",
                         "_End$|4$", False, ["phong_tien_v3/phong_tien_v3_bow_grip:mixamorig:LeftHand"]),
    # D-379: lưới Tripo v3.0 chi tiết 6k (mặt đầy, D-378) + Mixamo Pro Longbow (rig 1 ngón)
    "phong_tien_v4_mx": ("phong_tien_v4/phong_tien_v4_mx.glb", "heroes/phong_tien",
                         "standing idle 01=idle,standing run forward~=run,standing draw arrow+standing aim recoil=attack,"
                         "standing react small from front=hit,standing death backward 01=death,standing idle 02 looking=stun,"
                         "standing draw arrow@0-1.07+standing aim recoil@0-0.73=cast,standing dodge left~=skill_1,"
                         "standing aim overdraw@1.2-2.6+standing aim recoil@0-0.72=skill_2,standing run forward@0-0.9~=sprint",
                         "_End$|4$", False, ["phong_tien_v4/phong_tien_v4_bow_grip:mixamorig:LeftHand"]),
    # D-379b: lưới mặt đầy (D-378) + afk.ai, cung đặt theo khung Bow Pull Back (bow_grip.py) — người chơi chọn afk thay Mixamo
    "phong_tien_v4": ("phong_tien_v4/phong_tien_v4", "heroes/phong_tien",
                         "Bow_Casual=idle,Run_Female=run,Bow Pull Back@0.5-1.25+Bow Release=attack,Hit_Chest=hit,Death_B=death,"
                         "Idle_Dizzy=stun,Bow Pull Back@0.75-1.25+Bow Release=cast,Dodge_left=skill_1,"
                         "Bow_Draw@1.3-2.07+Bow Release=skill_2,Sprint=sprint",
                         "_leaf", False, ["phong_tien_v4/phong_tien_v4_bow_afk:hand_l"]),
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


def build(name, out_dir=None):
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
        out = os.path.join(out_dir, name + ".glb") if out_dir else os.path.join(ROOT, "assets", "models", "style", dst + ".glb")
        subprocess.run([sys.executable, "-I", os.path.join(HERE, "glb_slim.py"), mid, out, "--size", "1024"]
                       + (TEAM if team else []) + slim, check=True)


def main():
    args = sys.argv[1:]
    out_dir = None
    if "--out" in args:
        i = args.index("--out")
        out_dir = args[i + 1]
        del args[i:i + 2]
    for name in args or [n for n in UNITS if not n.startswith("phong_tien_v")]:  # bản thử chỉ dựng khi gọi tên
        build(name, out_dir)


if __name__ == "__main__":
    main()
