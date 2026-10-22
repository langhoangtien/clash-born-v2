# Yêu cầu âm thanh — Clashborn v2 (dành cho Codex)

Nguồn: **ElevenLabs Sound Effects API** bằng tài khoản của người chơi (D-111).

## Đợt A1 — 47 hiệu ứng + 13 câu thông báo tiếng Anh + 2 bản nhạc nền — LÀM NGAY (2026-10-22)

1. Lấy khóa API ElevenLabs từ người chơi, đặt vào biến môi trường `ELEVENLABS_API_KEY`.
   **Tuyệt đối không ghi khóa vào file nào trong repo, không commit.**
2. Chạy (chỉ cần Python 3, không cài thêm gì):
   ```
   python tools/sfx_gen/generate.py
   ```
   Script đọc `tools/sfx_gen/sounds.json`, gọi API, ghi `art_inbox/06_audio/<id>.mp3`, bỏ qua
   tiếng đã có (chạy lại an toàn nếu bị ngắt). Gồm 3 loại: hiệu ứng (Sound Effects), giọng
   thông báo `vo_*` (Text to Speech, mặc định giọng Adam; nếu tài khoản có giọng nam trầm hùng
   tráng hợp hơn kiểu người dẫn đấu trường thì đặt `ELEVENLABS_VOICE_ID` rồi chạy
   `--kind vo_ --force`), nhạc nền `music_*` (Music, 90 s và 150 s — lâu hơn, chạy cuối).
   Nếu tài khoản không có quyền Music API thì bỏ qua nhạc, ghi lại ở mục Ghi chú.
3. Nghe thử vài tiếng. Tiếng nào rõ ràng hỏng (có giọng người, có nhạc, sai hẳn nội dung) thì
   làm lại: `python tools/sfx_gen/generate.py --only <id> --force`.
4. **Không sửa** `sounds.json` / `generate.py` (Claude giữ). Thấy câu lệnh nào luôn ra kết quả xấu
   thì ghi vào mục "Ghi chú của Codex" cuối file này.
5. Commit + push `art_inbox/06_audio/` và file này lên `main` (`git pull --rebase` nếu bị từ chối).

Claude sẽ tự cân âm lượng, cắt khoảng lặng, chuyển sang .ogg và nhập vào game.

## Ghi chú của Codex

- 2026-10-22: Đã chạy đợt A1 bằng biến môi trường `ELEVENLABS_API_KEY`. ElevenLabs trả HTTP 401, `missing_permissions`: khóa thiếu quyền `sound_generation`. Chưa tạo được file âm thanh nào (0/47), chưa thể nghe thử. Cần người chơi bật quyền Sound Generation hoặc cấp khóa có quyền đó rồi chạy lại. Không sửa `generate.py` / `sounds.json`; không lưu khóa vào repo.
