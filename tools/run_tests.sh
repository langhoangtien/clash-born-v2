#!/usr/bin/env bash
# Chạy toàn bộ test (bản Linux/macOS). GODOT=đường dẫn tới godot 4.7.2.
# Dùng: tools/run_tests.sh [--filter=CRP_05] [--verbose]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1
"$GODOT" --headless --path "$ROOT" -s res://tests/run_all.gd -- "$@"
