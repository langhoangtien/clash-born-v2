# File gốc Mixamo (D-251) — giữ để thêm hoạt ảnh về sau

Mỗi hero một thư mục. Nhân vật đã gắn xương vẫn nằm trong tài khoản Mixamo của bạn; muốn thêm hoạt ảnh thì chọn lại
nhân vật đó trên Mixamo, tải hoạt ảnh mới (FBX Binary, 30 fps, Keyframe Reduction none, Without Skin được), bỏ vào thư
mục hero rồi báo Claude. Nếu Mixamo mất nhân vật: tải lên lại `art_inbox/3d/<hero>_mixamo.fbx` (cùng thân với bản
afk.ai — bắt buộc để chuyển hoạt ảnh sang rig afk).

| Hero | File có thân (With Skin) | Ghi chú |
|---|---|---|
| duy_anh | `duy_anh/duy_anh_mixamo.fbx` (T-pose) | gói Pro Sword and Shield + file tự tải (đuôi `- tu tao`) |
| noctis | `noctis/Mutant Punch.fbx` | |

Dựng lại (Claude làm):
1. `<venv bpy>/bin/python tools/models/mixamo_pack.py <file có thân> art_inbox/3d/<hero>_mixamo.glb art_inbox/3d/mixamo/<hero>`
2. `python3 -I tools/models/retarget.py art_inbox/3d/<hero>_afk.glb art_inbox/3d/<hero>_mixamo.glb art_inbox/3d/<hero>_afk_mx.glb "tên hoạt ảnh" …`
3. Thêm `MX <tên>` vào `tools/models/build_units.py`, chạy `build_units.py <hero>`.

Tên file chỉ khác hoa / thường bị Windows coi là trùng → đặt tên khác hẳn.
