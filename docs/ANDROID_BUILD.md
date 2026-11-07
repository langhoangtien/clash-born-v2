# Bản APK (Android / HarmonyOS 2–4)

HarmonyOS 2, 3, 4 chạy APK như Android (người chơi: HarmonyOS 4.2). HarmonyOS NEXT / 5+ không
cài APK trực tiếp. Bản build: chỉ arm64-v8a, xoay ngang (D-116); trình vẽ Mobile (Vulkan, D-259 — máy không có Vulkan thì Godot tự quay về OpenGL), cảnh 3D dưới 100% phóng bằng FSR. Bản web vẫn GL Compatibility.

## Build

```
GODOT=/đường/dẫn/godot tools/build_android.sh     # → build/android/clashborn.apk
```

- Template: `android_release.apk` của Godot 4.7.2 trong
  `~/.local/share/godot/export_templates/4.7.2.stable/` (lấy từ gói export templates .tpz).
- Không cần Gradle / Android Studio: chỉ cần `apksigner` (Android SDK build-tools, hoặc gói apt
  `apksigner`) và editor setting `export/android/android_sdk_path` trỏ tới thư mục có
  `build-tools/<phiên bản>/apksigner` và `platform-tools/adb`.
- versionCode = số commit, nên bản mới luôn cài đè được bản cũ.
- Ký bằng `tools/android/clashborn-test.keystore` (mật khẩu công khai trong script) — **chỉ để
  chơi thử**. Trước khi phát hành thật: tạo khóa riêng, giữ ngoài repo.

## Đưa cho người chơi

`gh release create apk-<versionCode> build/android/clashborn.apk` → tải trên điện thoại ở trang
Releases của repo. Lần đầu cài: cho phép "Cài ứng dụng không rõ nguồn gốc".

## Dựng môi trường trong container mới (D-257)

1. Template: tải `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz`,
   chỉ giải nén `templates/android_release.apk`, `android_debug.apk`, `version.txt` vào
   `~/.local/share/godot/export_templates/4.7.2.stable/` (gói 1,3 GB — xóa sau khi giải nén).
2. `apt-get install -y apksigner`; tạo thư mục SDK giả: `<sdk>/build-tools/34.0.0/apksigner` (liên kết tới
   `/usr/bin/apksigner`) và `<sdk>/platform-tools/adb` (script rỗng `exit 0`).
3. `~/.config/godot/editor_settings-4.7.tres`: `export/android/android_sdk_path = "<sdk>"`,
   `export/android/java_sdk_path = "/usr/lib/jvm/java-21-openjdk-amd64"`.
4. Repo clone nông → `git fetch --unshallow origin thu-asset-tu-lam` trước khi build (versionCode = số commit).
5. `GODOT=... bash tools/build_android.sh`, rồi **`bash tools/publish_vps.sh "ghi chú bản này"`** (D-278, D-281): đẩy APK
   lên `https://clashborn.quest` (mã tải lên do proxy của môi trường gắn — form bảo mật, host `clashborn.quest`;
   không có thì xin lại bằng request_credential), máy chủ kiểm sha256 rồi ghi `version.json`; script tự kiểm trang
   báo đúng số. App hỏi clashborn.quest trước, GitHub Pages dự phòng.
6. Kiểm thêm: tải `https://clashborn.quest/download/clashborn.apk` về so `sha256sum` với `build/android/clashborn.apk`.
7. **GitHub Pages không đăng APK nữa** (APK ~96 MiB sát giới hạn 100 MiB / file). Bản cuối trên gh-pages là
   **0.1.479** — bản chuyển tiếp để máy cài bản cũ (chỉ hỏi GitHub) lên được bộ cập nhật mới. gh-pages vẫn giữ bản
   chơi trên trình duyệt (index.html…). Lỗi phát hành VPS: xem `docs/VPS_SETUP.md` mục 7 (nhật ký, quay lại bản cũ).
