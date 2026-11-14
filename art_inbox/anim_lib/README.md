# Kho hoạt ảnh afk dùng chung (thử nghiệm D-398)

Câu hỏi: hoạt ảnh afk.ai của nhân vật A áp thẳng lên nhân vật afk B (xương cùng tên, dài ngắn khác) được không?
**Trả lời: CÓ ĐIỀU KIỆN.** Chân, thân, đầu: khớp như afk tự làm. Tay: thiếu bước "giữ tay khỏi thân" của afk-rig.

## Khảo sát xương (tools/models/anim_lib/survey_rig.py)

- 7 file afk (Duy Anh, Brakk, Phong Tiến, Gorran, Myra, Noctis, Vexa): cùng 66 xương, cùng tên, cùng cây cha–con.
- Xoay nghỉ (rest rotation) **khác nhau** giữa các tướng: thân / tay / chân lệch tới 25–45°, ngón tay tới ~95°.
  Tư thế nghỉ đều là chữ A, hướng xương gần giống nhau (lệch ≤ ~15°).
- Độ dài xương lệch nhiều: cánh tay trên 0,045 (Phong Tiến) – 0,156 (Gorran), cổ 0,053 – 0,139.
- Track dời chỉ có ở `root` (đứng yên = vị trí nghỉ; hoạt ảnh `_RM` có dời) và `pelvis`; không có track co giãn.
- **afk.ai trả cho mọi tướng CÙNG một bộ số xoay cục bộ** (trung bình lệch < 2°), bất kể xoay nghỉ khác nhau. Dời
  hông = dời nguồn + (nghỉ đích − nghỉ nguồn), KHÔNG co giãn theo chiều cao hông. Phần khác duy nhất là tay
  (xương đòn, cánh tay trên, cẳng tay, bàn tay): bước "Keeping the arms out of the body" của afk-rig chạy trên máy
  người dùng sau khi tải (afk.log: "frames with an arm through it: 27947, now 4612"), riêng cho lưới từng tướng.
- Vì vậy: chép nguyên track xoay theo tên xương (không chuyển theo hệ thế giới — cách đó lệch xa hơn: tay 11–22 cm,
  chân 6–7 cm trên Gorran).

## Kết quả đo (do_lech_copy.txt; 10 hoạt ảnh, kho = tướng khác)

| Kho → đích | lệch tay TB (max) | lệch chân | lún / trượt chân thêm |
|---|---|---|---|
| Phong Tiến → Gorran (to, vai rộng) | 3,5–12 cm (32 cm ở Bow Pull Back) | 0,0–0,1 cm | không |
| Vexa → Gorran | 4,8–12,5 cm (31,5) | 0,0 cm | không |
| Phong Tiến → Vexa (mảnh) | 0,0–5,2 cm (7,8) | 0,0–0,1 cm | không |
| Gorran → Vexa | 3,4–9 cm (23) | 0,0 cm | không |

Lệch tay = afk đẩy tay tướng to ra khỏi thân (Gorran: tay xa trục ngực hơn 5–9 cm). Kho lấy từ tướng to áp lên
tướng mảnh thì tay dang thừa; từ tướng mảnh áp lên tướng to thì tay lún vào bụng / ngực.

Video (trái afk trả cho chính tướng, phải lấy từ kho): `gorran_afk_vs_kho.mp4`, `vexa_afk_vs_kho.mp4` (10 hoạt ảnh),
`*_gan.mp4` (4 hoạt ảnh lệch nhiều nhất). File thử: `gorran_cmp.glb`, `vexa_cmp.glb` (`AFK <tên>` / `LIB <tên>`).

## Công cụ

```
python3 -I tools/models/anim_lib/make_lib.py tướng_afk.glb kho.glb [--only REGEX] [--prefix "MX "]
python3 -I tools/models/anim_lib/apply_anims.py kho.glb tướng_mới_afk.glb ra.glb --anims Idle_A,Run,…
python3 -I tools/models/anim_lib/measure.py kho.glb tướng_afk.glb --anims … --height 1.4   # nếu tướng có bản afk đủ
xvfb-run -a godot --path . --rendering-method mobile --rendering-driver vulkan --fixed-fps 30 --write-movie x.avi \
  --quit-after 180 -s tools/models/anim_lib/pair_compare.gd -- cmp.glb "A,B" 5
```

## Dung lượng kho

- Một bản đủ 593 hoạt ảnh, bỏ lưới / ảnh: 47,8 MB (gzip 19 MB). Phần lớn là track xoay (26 MB, trong đó ngón tay
  10,9 MB); 67 track mỗi hoạt ảnh dùng chung một mảng thời gian nhưng afk ghi riêng (6,6 MB, gộp lại còn 0,07 MB).
- Nhóm theo việc: `make_lib.py --only '^(Sword|Shield|SS_|GS_)'` → 48 hoạt ảnh, 3,1 MB.

## Mixamo

`MX <tên>` (retarget.py, Duy Anh) chép sang tướng khác: chân nổi ≤ 3 cm, trượt thêm ~2 cm/khung ở đòn nhảy — vì
retarget.py khớp theo tư thế nghỉ của Duy Anh, không theo bộ số chung của afk. Dùng được cho đòn nhanh; cần sửa chân
(khóa chân chạm đất) nếu dùng nhiều.
