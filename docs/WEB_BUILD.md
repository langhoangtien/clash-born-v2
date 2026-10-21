# Bản web chơi thử (iPhone / máy tính)

Người chơi dùng iPhone, chưa có máy Mac để xuất iOS → chơi thử bằng **bản web** (Godot Web,
không dùng luồng nên chạy được trên Safari iOS, không cần header COOP/COEP).

## Xuất lại

```
godot --headless --path . --export-release "Web" build/web/index.html
```

Cần export template web của Godot 4.7.2 (`web_nothreads_release.zip`) trong
`~/.local/share/godot/export_templates/4.7.2.stable/`. Thư mục `build/` không vào git.

## Đưa lên mạng

Nhánh `gh-pages` của repo chứa nội dung `build/web/` (kèm `.nojekyll`). Bật một lần trên
GitHub: **Settings → Pages → Build and deployment → Source: Deploy from a branch →
`gh-pages` / `(root)`**. Địa chỉ: https://langhoangtien.github.io/clash-born-v2/

Trên iPhone: mở bằng Safari → nút Chia sẻ → **Thêm vào MH chính** để chơi toàn màn hình,
xoay ngang.
