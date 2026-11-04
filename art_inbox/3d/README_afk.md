# Mô hình Tripo để gắn xương bằng afk.ai / Mixamo

Tripo dựng mô hình với **mặt nhìn sang ngang (+X)**, trong khi afk.ai và Mixamo cần **mặt nhìn thẳng ra trước
(+Z)**. Nạp file gốc `<tên>.glb` thì công cụ gắn xương đoán sai trước / sau / trái / phải → xương lệch, tay chân
lung tung. Dùng file **`<tên>_front.glb`** (đã xoay mặt ra trước bằng `tools/models/glb_yaw.py --deg -90`); trên
afk.ai chọn hướng 0 (đã nhìn ra trước).

## Hero cầm vũ khí (D-231)

afk.ai gắn xương lưới còn cầm kiếm / khiên dang ra thì đặt sai xương tay ("4 cái tay"). Cách làm:
1. `tools/models/split_weapons.py <tên>_front.glb <tên>_body.glb --part sword:<hộp> --part shield:<hộp>` — tách vũ khí
   (hộp tọa độ glTF x, y, z), ra `<tên>_body.glb` và `<tên>_body_<vũ khí>.glb`.
2. Gắn xương **thân trơn** `<tên>_body.glb` trên afk.ai (hướng 0).
3. `build_units.py` (cột vũ khí, vd `duy_anh_sword:hand_r`) gắn vũ khí cứng vào xương bàn tay — cùng hệ tọa độ, cùng ảnh màu.

## Cách bền: vẽ tay không, vũ khí riêng (D-235)

Tách vũ khí khỏi lưới cũ để lại chỗ ngón tay dính khiên; tốt nhất Codex vẽ thân **tay không** và từng vũ khí riêng:
1. Tripo dựng thân + từng vật (`<tên>.glb`, `<tên>_sword.glb`, `<tên>_shield.glb`).
2. Thân → `<tên>_front.glb` (bỏ sàn, `glb_yaw.py --deg -90`) → afk.ai (hướng 0) → `<tên>_afk.glb`.
3. Đặt vật vào nắm tay (thử, xem render, chỉnh):
   `python3 -I tools/models/place_prop.py duy_anh_afk.glb duy_anh_sword.glb duy_anh_sword_hand.glb --bone hand_r --size 0.48 --grip 0.12 --rot 90,0,0`
   `python3 -I tools/models/place_prop.py duy_anh_afk.glb duy_anh_shield.glb duy_anh_shield_hand.glb --bone hand_l --size 0.34 --grip 0.5 --grip-depth 0.1 --rot 0,-30,0 --offset 0.02,0,0`
4. `build_units.py` cột vũ khí `["duy_anh_sword_hand:hand_r", "duy_anh_shield_hand:hand_l"]` — vật dính cứng, ảnh màu riêng.

## Hoạt ảnh Mixamo (D-238)

1. `to_mixamo.py` xuất thân tay không → `<tên>_mixamo.fbx`, tải lên Mixamo (Standard Skeleton, Use Symmetry).
2. Tải gói / hoạt ảnh: FBX Binary, 30 fps, Keyframe Reduction none; một file With Skin (hoặc nhân vật T-pose), còn lại
   Without Skin được; tick In Place nếu có (không có thì dùng `tên~` trong build_units để khóa dời ngang hông).
3. `<venv bpy>/bin/python tools/models/mixamo_pack.py thân.fbx art_inbox/3d/<tên>_mixamo.glb thư_mục_fbx…`
4. `place_prop.py <tên>_mixamo.glb vật.glb <tên>_sword_mx.glb --bone mixamorig:RightHand …` (cùng số như afk.ai).
5. build_units: nguồn `"<tên>_mixamo.glb"`, bỏ xương `MIXAMO_FINGERS`, vũ khí `"<tên>_sword_mx:mixamorig:RightHand"`.
