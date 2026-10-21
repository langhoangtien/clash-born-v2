# Yêu cầu tạo ảnh — Clashborn v2

File này là **phiếu việc cho công cụ tạo ảnh** (Codex hoặc công cụ khác). Đọc hết
phần "Quy tắc chung" trước khi tạo bất kỳ ảnh nào.

## Cách làm việc (bắt buộc)

1. Làm **theo từng đợt**, đúng thứ tự. Mỗi đợt xong thì **DỪNG**, báo người dùng để
   duyệt. Chỉ làm đợt sau khi người dùng đồng ý.
2. **Đợt 0 là ảnh neo phong cách.** Sau khi được duyệt, mọi ảnh của các đợt sau phải
   đính kèm **cả hai** ảnh tham chiếu:
   - `docs/art/reference_style_01.png` (ảnh mẫu gốc),
   - `art_inbox/00_style/style_sheet.png` (ảnh neo đã duyệt).
   Ảnh hero từ đợt 3 còn đính kèm thêm bảng nhân vật của chính hero đó.
3. Lưu đúng **thư mục và tên file** ghi trong bảng (chữ thường, gạch dưới, đuôi `.png`).
   Không tự đổi tên, không thêm hậu tố như `_final`, `_v2`.
4. Làm xong ảnh nào thì đánh dấu `[x]` ở dòng đó trong file này. Ảnh phải làm lại thì
   ghi ngắn lý do sau dòng đó.
5. Không sửa bất kỳ file nào ngoài thư mục `art_inbox/`.

## Quy tắc chung cho mọi ảnh

- **Phong cách:** giống `docs/art/reference_style_01.png` — game mobile 2D, chibi,
  góc nhìn 3/4 từ trên xuống (camera nghiêng khoảng 45–55°), nét viền tối dày, tô màu
  phẳng 2–3 tông, màu bão hòa, ánh sáng từ **trên–trái**.
- **Nền:** trong suốt (PNG có alpha). Nếu công cụ không xuất được nền trong suốt: nền
  **một màu đồng nhất `#FF00FF`** (hồng tím), không gradient, không bóng, không
  vật thể nào dùng màu này.
  - Ngoại lệ: ô nền lặp (`tile_*`) phải **phủ kín**, không trong suốt.
- **Không** chữ, logo, chữ ký, watermark, khung, bóng đổ dưới chân (trừ khi ghi rõ).
- **Một vật thể mỗi ảnh**, nằm giữa khung, không bị cắt mép, cách mép ít nhất 8%.
- **Vật đứng** (nhân vật, cây, trụ): chân/gốc nằm ở khoảng **1/5 dưới** của khung, để
  game đặt đúng chỗ đứng.
- **Nhân vật quay mặt sang phải** (game tự lật ảnh khi đi sang trái).
- **Cặp xanh/đỏ phải cùng hình dáng.** Luôn làm bản xanh trước, rồi tạo bản đỏ bằng cách
  **đính kèm bản xanh và yêu cầu chỉ đổi các phần màu phe sang đỏ**, giữ nguyên hình
  khối, chi tiết, kích thước, vị trí trong khung.
- Màu phe: Blue `#3D8BFF` (xanh dương), Red `#FF4D4D` (đỏ). Phe chỉ thể hiện ở áo,
  mũ, cờ, pha lê — không đổi màu da hay màu cây cỏ.

### Câu lệnh gốc (ghép vào trước mô tả của từng ảnh)

```
Mobile MOBA 2D game asset, chibi stylized, 3/4 top-down view, bold dark outlines,
flat cel shading with 2-3 tones, saturated colors, soft light from top-left,
same art style as the attached reference images, single object centered,
transparent background, no text, no watermark, no ground shadow.
```

Với ô nền lặp thay bằng:

```
Seamless tileable top-down ground texture for a mobile 2D game, chibi stylized,
flat cel shading, saturated colors, same art style as the attached reference images,
fills the whole square, no objects, no text, edges must tile seamlessly.
```

---

## Đợt 0 — Ảnh neo phong cách — ✅ ĐÃ DUYỆT 2026-10-13

Từ đây mọi ảnh phải đính kèm `art_inbox/00_style/style_sheet.png`. Lính, trụ, cây, đá
trong các đợt sau phải **cùng thiết kế** với ảnh neo này (cùng nét, cùng tỉ lệ, cùng độ bão hòa).

| Xong | File | Kích thước | Mô tả |
|---|---|---|---|
| [x] | `00_style/style_sheet.png` | 1536 × 1024 | Lineup on transparent background, evenly spaced, same scale: a small blue-team melee minion with a short sword, a small red-team melee minion, a blue stone tower with a glowing blue crystal on top and a blue banner, a tall pine tree, a round leafy tree, a grey boulder. All standing on an invisible ground line. |

---

## Đợt 1 — Môi trường (map) — ✅ ĐÃ DUYỆT 2026-10-14 (kể cả 3 ảnh làm lại)

**Làm lại** (lý do: bản đỏ khác hình dáng bản xanh). Đính kèm bản xanh tương ứng làm
tham chiếu, chỉ đổi màu phe sang đỏ, giữ nguyên mọi thứ khác:

- [x] `01_env/tower_red.png` — phải cùng hình dáng `tower_blue.png` (tháp vuông, lỗ châu mai, cờ treo trước, pha lê trên đỉnh), chỉ đổi pha lê, cờ, viền sang đỏ.
- [x] `01_env/tower_red_destroyed.png` — cùng hình dáng `tower_blue_destroyed.png`, chỉ đổi màu.
- [x] `01_env/guard_red.png` — cùng hình dáng `guard_blue.png` (ba ngọn tháp pha lê), chỉ đổi màu.

Còn lại đạt: ô nền ghép liền không lộ đường nối (đã đo), cây, đá, cầu, bậc thang,
nhà chính, fountain, cờ dùng được.

### Ô nền lặp — 512 × 512, phủ kín

| Xong | File | Mô tả |
|---|---|---|
| [x] | `01_env/tile_grass_01.png` | Bright green grass, subtle darker tufts |
| [x] | `01_env/tile_grass_02.png` | Same grass, a few tiny flowers |
| [x] | `01_env/tile_grass_03.png` | Same grass, slightly darker variant |
| [x] | `01_env/tile_lane_stone_01.png` | Sandy beige stone-paved road, irregular flagstones |
| [x] | `01_env/tile_lane_stone_02.png` | Same road, some cracks and small pebbles |
| [x] | `01_env/tile_water_01.png` | Clear blue river water, light ripples |
| [x] | `01_env/tile_base_blue.png` | Grey stone plaza floor with thin blue trim lines |
| [x] | `01_env/tile_base_red.png` | Same plaza floor with thin red trim lines |

### Cây, bụi, đá — nền trong suốt

| Xong | File | Kích thước | Mô tả |
|---|---|---|---|
| [x] | `01_env/tree_pine_s_01.png` | 256 × 256 | Small pine tree |
| [x] | `01_env/tree_pine_m_01.png` | 384 × 384 | Medium pine tree, same design as the pine in style_sheet.png |
| [x] | `01_env/tree_pine_m_02.png` | 384 × 384 | Medium pine tree, different shape |
| [x] | `01_env/tree_pine_l_01.png` | 512 × 512 | Large tall pine tree |
| [x] | `01_env/tree_round_s_01.png` | 256 × 256 | Small round leafy tree |
| [x] | `01_env/tree_round_m_01.png` | 384 × 384 | Medium round leafy tree, same design as the round tree in style_sheet.png |
| [x] | `01_env/tree_round_m_02.png` | 384 × 384 | Medium round leafy tree, different shape |
| [x] | `01_env/tree_round_l_01.png` | 512 × 512 | Large round leafy tree |
| [x] | `01_env/bush_01.png` | 256 × 256 | Low green bush |
| [x] | `01_env/bush_02.png` | 256 × 256 | Fern-like plant |
| [x] | `01_env/flower_01.png` | 128 × 128 | Small orange flower cluster |
| [x] | `01_env/flower_02.png` | 128 × 128 | Small white-pink flower cluster |
| [x] | `01_env/rock_small_01.png` | 128 × 128 | Small grey rock |
| [x] | `01_env/rock_small_02.png` | 128 × 128 | Two small grey rocks |
| [x] | `01_env/cliff_rock_01.png` | 256 × 256 | Blocky grey stone chunk for a cliff wall, flat-topped |
| [x] | `01_env/cliff_rock_02.png` | 256 × 256 | Another stone chunk, slightly taller |
| [x] | `01_env/cliff_rock_03.png` | 256 × 256 | Stone chunk with moss on top |
| [x] | `01_env/cliff_rock_04.png` | 256 × 256 | Low wide stone chunk |
| [x] | `01_env/bridge_wood.png` | 512 × 256 | Wooden plank bridge with posts, seen from above at 3/4, running left-to-right |
| [x] | `01_env/ramp_stairs.png` | 256 × 256 | Short flight of stone stairs going up, seen from 3/4 |

### Công trình — nền trong suốt

| Xong | File | Kích thước | Mô tả |
|---|---|---|---|
| [x] | `01_env/tower_blue.png` | 512 × 768 | Exactly the same blue tower as in style_sheet.png (stone tower, glowing blue crystal on top, blue banner with diamond emblem), redrawn alone and centered |
| [x] | `01_env/tower_red.png` | 512 × 768 | Same tower as tower_blue, but glowing **red** crystal and red banner; identical shape |
| [x] | `01_env/tower_blue_destroyed.png` | 512 × 768 | Same blue tower collapsed into rubble, crystal shattered |
| [x] | `01_env/tower_red_destroyed.png` | 512 × 768 | Same red tower collapsed into rubble |
| [x] | `01_env/guard_blue.png` | 512 × 768 | Bigger, more ornate blue base tower (last defense), two crystals |
| [x] | `01_env/guard_red.png` | 512 × 768 | Same ornate tower in red |
| [x] | `01_env/core_blue.png` | 768 × 768 | Team base core: large floating blue crystal over a stone altar with steps |
| [x] | `01_env/core_red.png` | 768 × 768 | Same core, red crystal |
| [x] | `01_env/fountain_blue.png` | 512 × 512 | Healing fountain: round stone basin with glowing blue water and a small crystal |
| [x] | `01_env/fountain_red.png` | 512 × 512 | Same fountain with red glow |
| [x] | `01_env/banner_blue.png` | 256 × 384 | Blue team banner on a wooden pole |
| [x] | `01_env/banner_red.png` | 256 × 384 | Red team banner on a wooden pole |

---

## Đợt 2 — Lính và quái rừng (nền trong suốt, quay sang phải) — ✅ ĐÃ DUYỆT 2026-10-14

Ghi chú duyệt: vài ảnh cách mép dưới 8% nhưng không bị cắt; công cụ nhập ảnh sẽ tự
căn lề, không cần làm lại. Đợt sau vẫn giữ lề 8%.

| Xong | File | Kích thước | Mô tả |
|---|---|---|---|
| [x] | `02_units/creep_melee_blue.png` | 256 × 256 | Exactly the blue minion from style_sheet.png: chibi knight, closed helmet with blue plume, blue scarf and tabard, short sword |
| [x] | `02_units/creep_melee_red.png` | 256 × 256 | Exactly the red minion from style_sheet.png (same knight, red plume, scarf and tabard) |
| [x] | `02_units/creep_ranged_blue.png` | 256 × 256 | Chibi archer in the same armor style as the minions: open helmet with blue plume, blue scarf, leather vest, short bow |
| [x] | `02_units/creep_ranged_red.png` | 256 × 256 | Same archer with red plume and scarf |
| [x] | `02_units/creep_siege_blue.png` | 384 × 384 | Small wooden catapult on wheels with blue cloth |
| [x] | `02_units/creep_siege_red.png` | 384 × 384 | Same catapult with red cloth |
| [x] | `02_units/neutral_small.png` | 256 × 256 | Forest wolf pup, grey-brown |
| [x] | `02_units/neutral_medium.png` | 384 × 384 | Mossy forest golem, small |
| [x] | `02_units/neutral_large.png` | 512 × 512 | Big horned forest beast |
| [x] | `02_units/neutral_boss.png` | 768 × 768 | Ancient stone-and-vine guardian, huge, glowing green eyes |
| [x] | `02_units/hex_frog.png` | 256 × 256 | Cute green frog (the form a hexed hero turns into) |

---

## Đợt 3 — Bốn hero

Làm **từng hero một**: bảng nhân vật → dừng chờ duyệt → ảnh thân và chân dung.
Ảnh thân và chân dung phải đính kèm bảng nhân vật đã duyệt để giữ đúng nhân vật.

| Hero (id) | Mô tả nhân vật (dùng trong mọi ảnh của hero này) |
|---|---|
| Brakk (`brakk`) | Huge armored warrior, heavy steel plate armor, enormous iron gauntlets, no weapon, short beard, steel grey with orange accents, sturdy and broad |
| Myra (`myra`) | Petite mage girl, long flowing robe, staff topped with an ice crystal, white hair, icy blue and white palette, calm expression |
| Noctis (`noctis`) | Hooded assassin, face mask, twin daggers, tattered cloak, purple-black with teal accents, crouched ready stance |
| Vexa (`vexa`) | Young witch, tall pointed hat, floating spellbook beside her, small frog on her shoulder, green and purple palette, mischievous smile |

Mỗi hero 3 ảnh (thay `<id>` bằng id ở trên):

| Xong | File | Kích thước | Mô tả |
|---|---|---|---|
| [ ] | `03_heroes/<id>_sheet.png` | 1536 × 1024 | Character reference sheet: the same character shown twice side by side — front 3/4 view and back 3/4 view, full body, neutral standing pose, identical design |
| [ ] | `03_heroes/<id>_body.png` | 512 × 512 | Full body, facing right, idle combat stance, feet in the lower fifth of the frame |
| [ ] | `03_heroes/<id>_portrait.png` | 512 × 512 | Head and shoulders portrait, facing slightly right, plain transparent background |

Danh sách đánh dấu:

- [x] brakk_sheet  - [ ] brakk_body  - [ ] brakk_portrait
- [ ] myra_sheet  - [ ] myra_body  - [ ] myra_portrait
- [ ] noctis_sheet  - [ ] noctis_body  - [ ] noctis_portrait
- [ ] vexa_sheet  - [ ] vexa_body  - [ ] vexa_portrait

---

## Đợt 4 — Icon

> **Cập nhật 2026-10-17 (người dùng đồng ý):** Đợt 4 được làm **ngay**, không chờ Đợt 3
> xong (icon không phụ thuộc ảnh thân hero). Thứ tự trong đợt này:
>
> 1. **4a — Icon mẫu (neo phong cách icon):** chỉ làm 4 file `skill_brakk_q`, `skill_myra_r`,
>    `state_stunned`, `item_frost_orb`. Xong thì **DỪNG** chờ duyệt. Sau khi duyệt, mọi icon
>    còn lại đính kèm thêm 4 icon mẫu này làm tham chiếu để cùng một bộ.
>    **→ 2026-10-21: 4a ĐÃ DUYỆT** (4 icon đã nhập vào game). Dùng đúng 4 file này làm ảnh
>    tham chiếu phong cách cho mọi icon sau.
> 2. **4b — 14 icon skill còn lại** + **4c — icon trạng thái: LÀM LIỀN MỘT LƯỢT**, xong cả
>    hai mới dừng. Đánh dấu `[x]` vào bảng, rồi **commit + push thư mục `art_inbox/`** lên `main`.
> 3. **4d — Icon trang bị: ĐÃ CHỐT danh sách (2026-10-21),** làm sau 4c, theo lô 10 món.
>    **→ 2026-10-22: lô 1 ĐÃ DUYỆT và nhập vào game.** Làm tiếp **liền các lô còn lại (44 món)**,
>    mỗi lô xong thì commit + push lên `main` rồi làm lô kế, không cần chờ duyệt. Hai món cùng
>    loại (vd các loại găng, giày, áo) phải khác nhau rõ về màu / hình dáng.
>
> Phân biệt loại bằng **màu viền**: skill thường viền theo màu bảng dưới; **nội tại** viền
> bạc mảnh hơn; **ultimate (R)** viền đôi vàng kim dày hơn. Mỗi icon chỉ **một** hình chính,
> to, chiếm ~70% vòng tròn, không chi tiết vụn.

Icon skill và đồ: **256 × 256**, hình tròn, viền phát sáng theo màu ghi chú, nền tối
bên trong vòng tròn, ngoài vòng tròn trong suốt, nhìn rõ khi thu nhỏ còn 64 px.
Câu lệnh thêm: `round game skill icon, glowing rim, dark inner background, high
contrast, readable at small size`.

### Skill (16)

| Xong | File | Màu viền | Mô tả |
|---|---|---|---|
| [x] | `04_icons/skill_brakk_innate.png` | cam | Iron fist hitting, stars of a stun burst |
| [x] | `04_icons/skill_brakk_q.png` | cam | Fist slamming the ground, shockwave ring |
| [x] | `04_icons/skill_brakk_w.png` | cam | Steel shield bubble around armor |
| [x] | `04_icons/skill_brakk_r.png` | xanh lục | Translucent green ghostly warrior silhouette |
| [x] | `04_icons/skill_myra_innate.png` | xanh băng | Staff with quickening magic pulses |
| [x] | `04_icons/skill_myra_q.png` | xanh băng | Ice beam shooting forward |
| [x] | `04_icons/skill_myra_w.png` | xanh băng | Magic circle with vines rooting the ground |
| [x] | `04_icons/skill_myra_r.png` | cam lửa | Meteors falling from the sky |
| [x] | `04_icons/skill_noctis_innate.png` | tím | Dagger with a critical strike flash |
| [x] | `04_icons/skill_noctis_q.png` | tím | Shadow dash with dagger trail |
| [x] | `04_icons/skill_noctis_w.png` | tím | Hooded figure fading into darkness |
| [x] | `04_icons/skill_noctis_r.png` | đỏ | Glowing death mark sigil over a target |
| [x] | `04_icons/skill_vexa_innate.png` | xanh lục | Glowing brain energy flowing into a hand |
| [x] | `04_icons/skill_vexa_q.png` | xanh lục | Person turning into a frog in a puff of magic |
| [x] | `04_icons/skill_vexa_w.png` | xanh lục | Swirling gust of wind pushing |
| [x] | `04_icons/skill_vexa_r.png` | tím | Magic being ripped away from a figure |

### Trang bị (55) — **ĐÃ CHỐT 2026-10-21** (danh sách đồ D-106), làm sau 4b

Icon đồ: **khung tròn viền vàng đồng** (khác viền skill). Món cơ bản (giá ≤ 1800 trong
`docs/CONTENT.md`) dùng viền đồng mảnh; món ghép dùng viền vàng dày hơn. Một vật thể to ở
giữa, không chữ. Làm theo lô 10 món, mỗi lô xong thì báo.

| Xong | File | Mô tả |
|---|---|---|
| [x] | `04_icons/item_iron_branch.png` | Small iron-bark tree branch with a few leaves |
| [x] | `04_icons/item_circlet.png` | Simple gold circlet headband |
| [x] | `04_icons/item_gauntlets.png` | Pair of red leather strength gauntlets |
| [x] | `04_icons/item_slippers.png` | Light green elven slippers |
| [x] | `04_icons/item_mantle.png` | Blue scholar mantle with a gem clasp |
| [x] | `04_icons/item_ring_protection.png` | Silver ring with a small shield emblem |
| [x] | `04_icons/item_ring_regen.png` | Green gem ring with a tiny leaf |
| [x] | `04_icons/item_sages_mask.png` | Calm golden sage mask |
| [x] | `04_icons/item_blades_attack.png` | Pair of short steel blades crossed |
| [x] | `04_icons/item_gloves_haste.png` | Red gloves with speed streak marks |
| [x] | `04_icons/item_boots.png` | Plain brown leather boots |
| [x] | `04_icons/item_cloak.png` | Purple cloak with a faint anti-magic rune |
| [x] | `04_icons/item_chainmail.png` | Steel chainmail shirt |
| [x] | `04_icons/item_belt_strength.png` | Wide leather belt with an iron buckle |
| [x] | `04_icons/item_band_elvenskin.png` | Green elven arm band with leaf pattern |
| [x] | `04_icons/item_robe_magi.png` | Blue wizard robe with stars |
| [x] | `04_icons/item_vitality_booster.png` | Glowing red heart-shaped crystal |
| [x] | `04_icons/item_energy_booster.png` | Glowing blue mana crystal |
| [x] | `04_icons/item_quarterstaff.png` | Wooden fighting staff with metal caps |
| [x] | `04_icons/item_broadsword.png` | Broad steel sword |
| [ ] | `04_icons/item_ogre_axe.png` | Huge crude ogre axe |
| [ ] | `04_icons/item_blade_alacrity.png` | Thin swift blade with green wind wisps |
| [ ] | `04_icons/item_staff_wizardry.png` | Wizard staff topped with a blue orb |
| [ ] | `04_icons/item_platemail.png` | Heavy steel plate armor |
| [ ] | `04_icons/item_claymore.png` | Large two-handed claymore |
| [ ] | `04_icons/item_hyperstone.png` | Sharp golden-orange speed crystal with motion lines |
| [ ] | `04_icons/item_demon_edge.png` | Dark demonic sword with red runes |
| [ ] | `04_icons/item_wraith_band.png` | Green spectral wristband |
| [ ] | `04_icons/item_bracer.png` | Iron bracer with an orange gem |
| [ ] | `04_icons/item_null_talisman.png` | Blue talisman amulet with a rune |
| [ ] | `04_icons/item_boots_haste.png` | Red boots with small wings and speed lines |
| [ ] | `04_icons/item_boots_arcane.png` | Blue magic boots with glowing runes |
| [ ] | `04_icons/item_boots_guard.png` | Armored steel boots |
| [ ] | `04_icons/item_battle_axe.png` | Large double-headed battle axe with red trim |
| [ ] | `04_icons/item_wind_bow.png` | Elegant longbow wrapped in green wind |
| [ ] | `04_icons/item_butterfly.png` | Slender sword with a butterfly-wing guard, teal glow |
| [ ] | `04_icons/item_steel_armor.png` | Polished steel breastplate |
| [ ] | `04_icons/item_magic_cloak.png` | Long purple cloak shimmering with a protective rune |
| [ ] | `04_icons/item_assault_plate.png` | Ornate golden plate armor with spikes |
| [ ] | `04_icons/item_giant_heart.png` | Huge glowing red heart wrapped in iron bands |
| [ ] | `04_icons/item_storm_staff.png` | Staff crackling with blue lightning |
| [ ] | `04_icons/item_crit_blade.png` | Curved sword with a red critical spark |
| [ ] | `04_icons/item_divine_blade.png` | Large holy golden blade with a red jewel |
| [ ] | `04_icons/item_grapes.png` | Bunch of three purple grapes |
| [ ] | `04_icons/item_ghost_scepter.png` | Pale green scepter with a ghostly wisp |
| [ ] | `04_icons/item_resolute_armor.png` | Black and gold breastplate radiating golden aura |
| [x] | `04_icons/item_frost_orb.png` | Icy blue orb with frost crystals |
| [ ] | `04_icons/item_reveal_dust.png` | Small pouch spilling glittering dust |
| [ ] | `04_icons/item_cyclone_staff.png` | Staff with a small swirling tornado |
| [ ] | `04_icons/item_shadow_blade.png` | Dark curved blade dissolving into shadow |
| [ ] | `04_icons/item_hex_scythe.png` | Ornate scythe with a frog-shaped gem |
| [ ] | `04_icons/item_cleansing_charm.png` | Glowing white charm amulet |
| [ ] | `04_icons/item_stun_hammer.png` | Heavy war hammer with stun stars |
| [ ] | `04_icons/item_observer_ward.png` | Golden eye on a small wooden stake |
| [ ] | `04_icons/item_sentry_ward.png` | Blue eye on a small wooden stake with a faint sight ring |

### Trạng thái (12) — 64 × 64, biểu tượng đơn giản, nét đậm, nền trong suốt

| Xong | File | Mô tả |
|---|---|---|
| [x] | `04_icons/state_stunned.png` | Yellow spinning stars |
| [x] | `04_icons/state_rooted.png` | Green vine chain |
| [x] | `04_icons/state_silenced.png` | Purple crossed-out mouth |
| [x] | `04_icons/state_disarmed.png` | Red crossed swords with a slash |
| [x] | `04_icons/state_slowed.png` | Light blue snowflake |
| [x] | `04_icons/state_revealed.png` | Orange eye |
| [x] | `04_icons/state_ghost.png` | Green ghost |
| [x] | `04_icons/state_invulnerable.png` | Golden shield |
| [x] | `04_icons/state_magic_immune.png` | Golden shield with a magic rune |
| [x] | `04_icons/state_hexed.png` | Green frog head |
| [x] | `04_icons/state_shield.png` | White bubble shield |
| [x] | `04_icons/state_burning.png` | Small orange flame |
| [x] | `04_icons/state_recall.png` | Blue swirl portal with a small house shape (nút Về thành, 256 × 256 như icon skill, viền xanh dương) |

---

## Đợt 5 — Giao diện (nền trong suốt)

Kiểu: viền đá/kim loại tối, phát sáng xanh như nút skill trong ảnh mẫu.

| Xong | File | Kích thước | Mô tả |
|---|---|---|---|
| [ ] | `05_ui/skill_button_frame.png` | 256 × 256 | Empty round button frame, dark metal ring, soft blue glow, empty transparent center |
| [ ] | `05_ui/attack_button.png` | 320 × 320 | Big round attack button with a sword emblem |
| [ ] | `05_ui/joystick_base.png` | 320 × 320 | Translucent round joystick base ring |
| [ ] | `05_ui/joystick_knob.png` | 160 × 160 | Round joystick knob |
| [ ] | `05_ui/minimap_frame.png` | 512 × 512 | Rounded-square frame, dark stone border, transparent center |
| [ ] | `05_ui/panel_frame.png` | 256 × 256 | Dark panel with ornate border; corners must work as a 9-slice with 48 px margins |
| [ ] | `05_ui/button_generic.png` | 256 × 96 | Rectangular button, dark with light border; works as a 9-slice with 24 px margins |
| [ ] | `05_ui/hp_bar_frame.png` | 256 × 48 | Thin dark health bar frame, empty transparent inside |

---

## Đợt 6 — Ảnh nền hiệu ứng (TRẮNG/XÁM trên nền trong suốt, để game tô màu)

Không màu, chỉ trắng → xám → trong suốt, mép mềm.

| Xong | File | Kích thước | Mô tả |
|---|---|---|---|
| [ ] | `06_vfx/slash_arc.png` | 512 × 512 | Crescent sword slash arc |
| [ ] | `06_vfx/glow_circle.png` | 256 × 256 | Soft radial glow |
| [ ] | `06_vfx/sparkle.png` | 128 × 128 | Four-point sparkle star |
| [ ] | `06_vfx/smoke_puff.png` | 256 × 256 | Soft round smoke puff |
| [ ] | `06_vfx/ice_shard.png` | 256 × 256 | Single ice crystal shard |
| [ ] | `06_vfx/magic_circle.png` | 512 × 512 | Ornate magic circle with runes (used to telegraph area skills) |
| [ ] | `06_vfx/lightning.png` | 512 × 256 | Horizontal lightning bolt |
| [ ] | `06_vfx/flame.png` | 256 × 256 | Small stylized flame |
| [ ] | `06_vfx/shockwave_ring.png` | 512 × 512 | Thin expanding shockwave ring |
| [ ] | `06_vfx/leaf.png` | 128 × 128 | Single leaf |

---

## Khi xong

Báo người dùng: đợt nào đã xong, file nào phải làm lại và vì sao. Không chép ảnh vào
`assets/`; việc nhập ảnh vào game do agent lập trình làm theo `docs/ART.md`.
