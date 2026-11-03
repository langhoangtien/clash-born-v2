# Mô hình Tripo để gắn xương bằng afk.ai / Mixamo

Tripo dựng mô hình với **mặt nhìn sang ngang (+X)**, trong khi afk.ai và Mixamo cần **mặt nhìn thẳng ra trước
(+Z)**. Nạp file gốc `<tên>.glb` thì công cụ gắn xương đoán sai trước / sau / trái / phải → xương lệch, tay chân
lung tung. Dùng file **`<tên>_front.glb`** (đã xoay mặt ra trước bằng `tools/models/glb_yaw.py --deg -90`); trên
afk.ai chọn hướng 0 (đã nhìn ra trước).
