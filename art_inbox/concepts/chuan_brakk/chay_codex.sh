#!/usr/bin/env bash
# D-364: chờ Codex đăng nhập rồi vẽ song song các concept (prompt = _chung.txt + <phương án>.txt trong từng thư mục).
#   bash art_inbox/concepts/chuan_brakk/chay_codex.sh phong_tien/pa1 phong_tien/pa2 canh_vat/huong1 …
cd "$(dirname "$0")/../../.." || exit 1
for i in $(seq 1 3); do codex login status 2>&1 | grep -q "^Logged in" && break; sleep 10; done
codex login status 2>&1 | grep -q "^Logged in" || { echo "chưa đăng nhập Codex"; exit 3; }
for job in "$@"; do
  dir="art_inbox/concepts/chuan_brakk/$(dirname "$job")"
  prompt="$(cat "$dir/_chung.txt")

$(cat "$dir/$(basename "$job").txt")"
  codex exec --sandbox workspace-write --skip-git-repo-check -C "$PWD" "$prompt" > "$dir/$(basename "$job").log" 2>&1 &
done
wait
for job in "$@"; do f="art_inbox/concepts/chuan_brakk/$job.png"; [ -f "$f" ] && echo "có $f" || echo "THIẾU $f"; done
