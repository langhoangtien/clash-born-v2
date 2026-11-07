# Dựng VPS cho Clashborn (clashborn.quest)

Tài liệu cho **phiên Claude chạy trên VPS** (và người quản trị). Đọc hết trước khi làm. Quyết định: D-278.

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
  www/           gốc web (Caddy phục vụ)
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
2. Mở cổng **80** và **443** (Caddy cần 80 để xin chứng chỉ). **Không** mở 8787 ra ngoài.
   - ufw: `ufw allow 80,443/tcp` (giữ cổng SSH đang dùng).

## 2. Người dùng, thư mục, repo

```bash
useradd --system --home /srv/clashborn --shell /usr/sbin/nologin clashborn
mkdir -p /srv/clashborn/www /srv/clashborn/incoming /etc/clashborn
git clone https://github.com/langhoangtien/clash-born-v2.git /srv/clashborn/repo   # repo riêng: dùng deploy key chỉ đọc
chown -R clashborn:clashborn /srv/clashborn/www /srv/clashborn/incoming
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

## 4. Caddy (web + HTTPS)

```bash
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install -y caddy
cp /srv/clashborn/repo/tools/vps/Caddyfile /etc/caddy/Caddyfile
systemctl reload caddy
```

`tools/vps/Caddyfile`: phục vụ `/srv/clashborn/www`; `/api/*` → máy chủ nhận file ở `127.0.0.1:8787` (giới hạn
400 MB); `version.json` và `download/` không cache; `releases/*.apk` cache lâu (tên theo số bản, không đổi nội
dung); kiểu MIME APK đúng. Caddy cần đọc được `/srv/clashborn/www` (mặc định thư mục 755, file 644 là đủ).

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

- Cập nhật script: `cd /srv/clashborn/repo && git pull && systemctl restart clashborn-upload` (đổi Caddyfile thì
  chép lại rồi `systemctl reload caddy`).
- Nhật ký: `journalctl -u clashborn-upload -n 100`, `journalctl -u caddy -n 100`.
- **Quay lại bản trước** (bản mới lỗi): trong `releases/` vẫn còn 4 bản cũ.
  ```bash
  cd /srv/clashborn/www
  ln -sfn ../releases/clashborn-0.1.<CŨ>.apk download/clashborn.apk
  # sửa version.json: code / name / apk / url / sha256 / size theo bản cũ (sha256sum releases/…)
  ```
  App chỉ mời cập nhật khi `code` **lớn hơn** bản đang cài → quay lại chỉ có tác dụng với người chưa lên bản lỗi;
  cách chắc hơn là phiên cloud build lại một bản mới (số lớn hơn) đã sửa lỗi.
- Dung lượng: 5 APK ≈ 500 MB.

## 8. Phía cloud (phiên Claude Code build game — để biết, không làm trên VPS)

1. Mở mạng tới `clashborn.quest` cho môi trường cloud và nhập mã qua form bảo mật (host `clashborn.quest`).
2. Bộ cập nhật trong game (`app/updater.gd`): địa chỉ → `https://clashborn.quest/`; kiểm **sha256** sau khi tải,
   trước khi mở màn cài; GitHub làm nguồn dự phòng trong thời gian chuyển.
3. **Chuyển tiếp**: bản đầu tiên trỏ về domain được đăng lên **cả** GitHub Pages lẫn VPS (vẫn dưới 100 MiB) — máy
   đang cài bản cũ (chỉ hỏi GitHub) cập nhật một lần lên bản đó; từ đó chỉ đăng lên VPS.
4. Phát hành: `bash tools/build_android.sh` rồi `bash tools/publish_vps.sh "ghi chú"`.
5. Trang giới thiệu: mã nguồn trong repo (`web/site/`), đóng `site.tar.gz`, `PUT /api/upload/site.tar.gz` rồi
   `POST /api/site`.

## 9. Sau này: máy chủ trận online (chưa làm)

Máy chủ trận sẽ chạy SIM của game không giao diện (`godot --headless` + script máy chủ trong repo), lệnh của người
chơi qua mạng (D-30: cùng seed + cùng nhật ký Command → cùng trận). Khi làm: dành một cổng riêng (UDP / WebSocket)
sau Caddy, chạy bằng người dùng `clashborn`, đọc code từ `/srv/clashborn/repo`. Mô hình mạng (lockstep hay máy
chủ quyết định) chốt khi bắt đầu (D-30).
