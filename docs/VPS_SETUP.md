# Dựng VPS cho Clashborn (clashborn.quest)

Tài liệu cho **phiên Claude chạy trên VPS** (và người quản trị). Đọc hết trước khi làm. Quyết định: D-278, D-279 (nginx thay Caddy).

> **Trạng thái VPS (2026-11-07):** đã dựng bằng **nginx** (máy đã có nginx phục vụ `api.quitmood.net` → không cài
> Caddy). Xong: người dùng `clashborn`, `/srv/clashborn/{repo,www,incoming}` (repo clone nhánh `thu-asset-tu-lam`),
> mã bí mật, `clashborn-upload` chạy (`/api/health` ok ở 127.0.0.1:8787), web gốc đã chuyển từ
> `/var/www/clashborn.quest` cũ (index.html, icon.png, `releases/clashborn-0.1.470.apk`, `download/clashborn.apk` →
> bản đó). **Chưa có `version.json` ở gốc** — bản thật đầu tiên do phiên cloud đẩy. Cloudflare để **DNS only** (mây
> xám): gói miễn phí giới hạn 100 MB / yêu cầu tải lên, APK ~96 MiB. Chưa có bản ghi `www`. HTTPS chạy (chứng chỉ
> Let's Encrypt, webroot, tự gia hạn); ufw mở 80/443 cho mọi nguồn. Cách cũ (`clashborn-publish`,
> `/var/www/clashborn.quest`) đã gỡ.

## 0. Mục tiêu và phân vai

- VPS phục vụ **trang giới thiệu** và **bản cập nhật APK** ở `https://clashborn.quest`, thay GitHub Pages (APK
  ~96 MiB, sắp chạm giới hạn 100 MiB / file của GitHub).
- **Build APK không làm trên VPS.** Phiên Claude Code trên cloud build rồi đẩy lên VPS qua một cổng HTTPS có mã
  bí mật (`tools/publish_vps.sh`). VPS chỉ nhận file, kiểm tra, phát hành.
- VPS **clone repo** (`/srv/clashborn/repo`): lấy script cài đặt ở `tools/vps/`, và sau này chạy **máy chủ trận
  đấu online** bằng chính SIM của game (`godot --headless`). Chưa làm phần online ở đây.
- Không cần GitHub Actions.

Cấu trúc trên VPS:

```
/srv/clashborn/
  repo/          git clone (chỉ đọc) — tools/vps/* dùng từ đây
  www/           gốc web (nginx phục vụ)
    index.html   trang giới thiệu (đẩy từ cloud bằng /api/site)
    version.json bản mới nhất {code, name, apk, url, sha256, size, notes} — app đọc mỗi lần mở
    releases/    clashborn-0.1.N.apk — giữ 5 bản gần nhất
    download/clashborn.apk → ../releases/<bản mới nhất> (liên kết, nút "Tải game" trên web)
    play/        (sau này) bản chơi trên trình duyệt
  incoming/      file vừa tải lên, chờ kiểm tra
/etc/clashborn/upload_token   mã bí mật (chmod 640, root:clashborn)
```

## 1. DNS và tường lửa

1. Ở nhà cung cấp domain: bản ghi **A** cho `clashborn.quest` và `www.clashborn.quest` → IP của VPS (có IPv6 thì
   thêm AAAA). Kiểm: `dig +short clashborn.quest` ra đúng IP.
   Domain dùng nameserver Cloudflare: để bản ghi ở chế độ **DNS only** (mây xám). Proxy Cloudflare (mây cam) gói
   miễn phí chặn yêu cầu tải lên > 100 MB và không hợp tải APK lớn.
2. Mở cổng **80** và **443** cho mọi nguồn (certbot cần 80 để xin chứng chỉ). **Không** mở 8787 ra ngoài.
   - ufw: `ufw allow 80,443/tcp` (giữ cổng SSH đang dùng). Nếu máy từng chỉ mở 80/443 cho dải IP Cloudflare
     (có luật `DENY 80/tcp`, `DENY 443/tcp`), xóa các luật DENY đó trước — luật DENY đứng trước sẽ thắng.

## 2. Người dùng, thư mục, repo

```bash
useradd --system --home /srv/clashborn --shell /usr/sbin/nologin clashborn
mkdir -p /srv/clashborn/www /srv/clashborn/incoming /srv/clashborn/reports /etc/clashborn
git clone https://github.com/langhoangtien/clash-born-v2.git /srv/clashborn/repo   # repo riêng: dùng deploy key chỉ đọc
chown -R clashborn:clashborn /srv/clashborn/www /srv/clashborn/incoming /srv/clashborn/reports
```

Repo **riêng tư**: tạo deploy key **chỉ đọc** (`ssh-keygen -t ed25519`, thêm khóa công khai ở GitHub → repo →
Settings → Deploy keys, không tick "write"), clone bằng `git@github.com:langhoangtien/clash-born-v2.git`.

## 3. Mã bí mật tải lên

```bash
openssl rand -hex 32 > /etc/clashborn/upload_token
chown root:clashborn /etc/clashborn/upload_token && chmod 640 /etc/clashborn/upload_token
```

- **Không** commit mã, **không** dán vào chat, **không** in ra log.
- Người dùng tự đọc mã trên VPS (`cat /etc/clashborn/upload_token`) rồi nhập vào **form bảo mật** của phiên Claude
  Code trên cloud khi phiên đó hỏi (host `clashborn.quest`, kiểu Bearer). Proxy của phiên cloud tự gắn header
  `Authorization: Bearer …` cho mọi yêu cầu tới host này; phiên cloud không nhìn thấy mã.
- Đổi mã: ghi mã mới vào file (máy chủ đọc lại mỗi yêu cầu, không cần khởi động lại), rồi nhập lại ở form cloud.

## 4. nginx (web + HTTPS)

VPS đã có nginx (site khác dùng chung cổng 80/443) → dùng nginx + certbot, **không** cài Caddy (D-279).

```bash
apt install -y nginx certbot python3-certbot-nginx     # nếu chưa có
# a) Cấu hình tạm chỉ để xin chứng chỉ (webroot):
cat > /etc/nginx/sites-available/clashborn.quest <<'EOF'
server {
    listen 80; listen [::]:80;
    server_name clashborn.quest;
    location /.well-known/acme-challenge/ { root /srv/clashborn/www; }
    location / { return 404; }
}
EOF
ln -sfn /etc/nginx/sites-available/clashborn.quest /etc/nginx/sites-enabled/clashborn.quest
nginx -t && systemctl reload nginx
# b) Xin chứng chỉ (tự gia hạn qua cùng webroot):
certbot certonly --webroot -w /srv/clashborn/www -d clashborn.quest --non-interactive --agree-tos -m <email>
# c) Cấu hình thật:
cp /srv/clashborn/repo/tools/vps/nginx-clashborn.conf /etc/nginx/sites-available/clashborn.quest
nginx -t && systemctl reload nginx
```

Cần `/etc/letsencrypt/options-ssl-nginx.conf` (có sẵn khi đã từng dùng `certbot --nginx`; thiếu thì cài
`python3-certbot-nginx` hoặc bỏ dòng `include`).

`tools/vps/nginx-clashborn.conf`: 80 → chuyển sang HTTPS (trừ `/.well-known/acme-challenge/`); phục vụ
`/srv/clashborn/www`; `/api/` → máy chủ nhận file ở `127.0.0.1:8787` (giới hạn 400 MB, không đệm thân yêu cầu,
timeout 600 s); `version.json` và `download/` không cache; `releases/*.apk` cache lâu (tên theo số bản, không đổi
nội dung); kiểu MIME APK đúng. nginx (www-data) cần đọc được `/srv/clashborn/www` (thư mục 755, file 644 là đủ).
Thêm `www.clashborn.quest`: bản ghi A (DNS only), bỏ chú thích ở hai `server_name`, xin lại chứng chỉ thêm
`-d www.clashborn.quest`.

## 5. Máy chủ nhận bản build

`tools/vps/upload_server.py` — Python 3 thư viện chuẩn, chỉ nghe `127.0.0.1:8787`:

| Lệnh | Việc |
|---|---|
| `GET /api/health` | `{"ok": true}` (không cần mã) |
| `PUT /api/upload/<tên>` | lưu vào `incoming/` (chỉ nhận `clashborn-0.1.N.apk`, `site.tar.gz`; ≤ 400 MB) |
| `POST /api/publish` | JSON `{code, name, file, sha256, notes}` → kiểm sha256 → `releases/`, trỏ `download/`, ghi `version.json` (ghi tạm rồi đổi tên — không bao giờ lộ bản dở), giữ 5 bản |
| `POST /api/site` | giải nén `incoming/site.tar.gz` thành trang web; từ chối đường dẫn lạ / liên kết / mục `releases`, `version.json`, `download`, `play` |

Mọi lệnh ghi cần `Authorization: Bearer <mã>` (so sánh thời gian hằng). Không ghi header vào log.

```bash
cp /srv/clashborn/repo/tools/vps/clashborn-upload.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now clashborn-upload
```

## 6. Trang tạm và kiểm tra

```bash
echo '<!doctype html><meta charset="utf-8"><title>Clashborn</title><h1>Clashborn — sắp ra mắt</h1>' > /srv/clashborn/www/index.html
chown clashborn:clashborn /srv/clashborn/www/index.html
curl -s https://clashborn.quest/api/health                    # {"ok": true}
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://clashborn.quest/api/site   # 401 (thiếu mã — đúng)
curl -sI https://clashborn.quest/ | head -1                   # HTTP/2 200, chứng chỉ hợp lệ
```

**Không** thử phát hành bằng file giả (sẽ đổi `version.json` mà app đang đọc). Bản thật đầu tiên do phiên cloud
đẩy lên.

Báo lại cho người dùng: domain chạy HTTPS, `/api/health` ok, mã đã tạo (người dùng tự lấy trên VPS).

## 7. Vận hành

- Cập nhật: `sudo bash /srv/clashborn/repo/tools/vps/update.sh` (xem dưới).
- Nhật ký: `journalctl -u clashborn-upload -n 100`, `/var/log/nginx/error.log`.
- **Quay lại bản trước** (bản mới lỗi): trong `releases/` vẫn còn 4 bản cũ.
  ```bash
  cd /srv/clashborn/www
  ln -sfn ../releases/clashborn-0.1.<CŨ>.apk download/clashborn.apk
  # sửa version.json: code / name / apk / url / sha256 / size theo bản cũ (sha256sum releases/…)
  ```
  App chỉ mời cập nhật khi `code` **lớn hơn** bản đang cài → quay lại chỉ có tác dụng với người chưa lên bản lỗi;
  cách chắc hơn là phiên cloud build lại một bản mới (số lớn hơn) đã sửa lỗi.
- Dung lượng: 5 APK ≈ 500 MB (APK 65 MB từ D-286). Báo cáo hiệu năng: tối đa 200 file × ≤ 4 MB.
- **Báo cáo hiệu năng (D-287)**: game gửi `POST /api/report` (không cần mã, nginx giới hạn 6 lần / phút / IP, máy
  chủ kiểm cỡ + dạng, giữ 200 bản mới nhất trong `/srv/clashborn/reports/` — ngoài `www/`, không ai xem được qua
  web). Đọc: `GET /api/reports`, `GET /api/reports/<mã|latest>` (cần mã bí mật; phía cloud dùng
  `tools/fetch_reports.sh`). Không lưu IP. Test: `python3 -m unittest discover -s tools/vps -p 'test_*.py'`.
- **Cập nhật VPS bằng một lệnh (D-288)**: `sudo bash /srv/clashborn/repo/tools/vps/update.sh` — kéo code, chạy test máy
  chủ, tạo thư mục, cài service / nginx khi đổi (sao lưu, `nginx -t` lỗi thì trả lại), khởi động lại, ghi commit vào
  `/srv/clashborn/deployed` (hiện ở `/api/health`). Việc riêng từng đợt: `docs/VPS_TASKS.md`.

## 8. Phía cloud (phiên Claude Code build game — để biết, không làm trên VPS)

1. Mở mạng tới `clashborn.quest` cho môi trường cloud và nhập mã qua form bảo mật (host `clashborn.quest`).
2. Bộ cập nhật trong game (`app/updater.gd`): địa chỉ → `https://clashborn.quest/`; kiểm **sha256** sau khi tải,
   trước khi mở màn cài; GitHub làm nguồn dự phòng trong thời gian chuyển.
3. **Chuyển tiếp**: bản đầu tiên trỏ về domain được đăng lên **cả** GitHub Pages lẫn VPS (vẫn dưới 100 MiB) — máy
   đang cài bản cũ (chỉ hỏi GitHub) cập nhật một lần lên bản đó; từ đó chỉ đăng lên VPS.
4. Phát hành: `bash tools/build_android.sh` rồi `bash tools/publish_vps.sh "ghi chú"`.
5. Trang giới thiệu: mã nguồn trong repo (`web/site/`); `bash tools/site/publish_site.sh` dựng (thêm dữ liệu tướng,
   ảnh) rồi `PUT /api/upload/site.tar.gz` + `POST /api/site` (D-284).

## 9. Sau này: máy chủ trận online (chưa làm)

Máy chủ trận sẽ chạy SIM của game không giao diện (`godot --headless` + script máy chủ trong repo), lệnh của người
chơi qua mạng (D-30: cùng seed + cùng nhật ký Command → cùng trận). Khi làm: dành một cổng riêng (UDP / WebSocket)
sau nginx, chạy bằng người dùng `clashborn`, đọc code từ `/srv/clashborn/repo`. Mô hình mạng (lockstep hay máy
chủ quyết định) chốt khi bắt đầu (D-30).
