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
