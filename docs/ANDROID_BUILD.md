# Bản APK (Android / HarmonyOS 2–4)

HarmonyOS 2, 3, 4 chạy APK như Android (người chơi: HarmonyOS 4.2). HarmonyOS NEXT / 5+ không
cài APK trực tiếp. Bản build: chỉ arm64-v8a, renderer GL Compatibility, xoay ngang (D-116).

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
