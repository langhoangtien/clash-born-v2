#!/usr/bin/env bash
# Build APK (D-116). Cần: Godot 4.7.2 (GODOT=...), template android_release.apk trong
# ~/.local/share/godot/export_templates/4.7.2.stable/, apksigner (Android SDK build-tools hoặc
# gói apt `apksigner`), editor settings trỏ export/android/android_sdk_path.
# Khóa ký: tools/android/clashborn-test.keystore (khóa THỬ NGHIỆM, công khai — chỉ dùng cho
# bản chơi thử; phát hành thật phải đổi khóa riêng, giữ bí mật).
# Dùng: GODOT=godot tools/build_android.sh   → build/android/clashborn.apk + version.json
# (đăng cả hai lên gh-pages để bản cũ tự thấy bản mới, D-148)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
CODE="$(git -C "$ROOT" rev-list --count HEAD)"   # versionCode tăng dần để cài đè bản cũ
sed -i "s/^version\/code=.*/version\/code=$CODE/; s/^version\/name=.*/version\/name=\"0.1.$CODE\"/" "$ROOT/export_presets.cfg"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ROOT/tools/android/clashborn-test.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=clashborn
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=clashborn-test
mkdir -p "$ROOT/build/android"
# D-148: bản đang chạy (app đọc để so với version.json trên gh-pages khi tự cập nhật).
printf '{"code": %s, "name": "0.1.%s"}\n' "$CODE" "$CODE" > "$ROOT/app/build.json"
printf '{"code": %s, "name": "0.1.%s", "apk": "clashborn.apk"}\n' "$CODE" "$CODE" > "$ROOT/build/android/version.json"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1
"$GODOT" --headless --path "$ROOT" --export-release "Android" "$ROOT/build/android/clashborn.apk"
echo "APK: $ROOT/build/android/clashborn.apk (versionCode $CODE)"
