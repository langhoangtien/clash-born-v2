extends TestCase
## D-287: gửi kết quả đo lên clashborn.quest — gói gửi đi, câu báo theo trả lời máy chủ, nút + ô ghi chú trên bảng.


func test_D_287_body_has_kind_note_summary_and_data() -> void:
	var data: Dictionary = {"meta": {"version": "0.1.490"}, "segments": []}
	var body: Dictionary = JSON.parse_string(PerfUpload.body(&"bench", "  máy nóng  ", "tóm tắt", data))
	assert_eq(body["kind"], "bench")
	assert_eq(body["note"], "máy nóng", "bỏ khoảng trắng thừa")
	assert_eq(body["summary"], "tóm tắt")
	assert_eq(body["data"]["meta"]["version"], "0.1.490")
	var long: Dictionary = JSON.parse_string(PerfUpload.body(&"log", "x".repeat(900), "", {}))
	assert_eq((long["note"] as String).length(), PerfUpload.NOTE_MAX, "ghi chú dài bị cắt như máy chủ")


func test_D_287_body_is_compact() -> void:
	var body: String = PerfUpload.body(&"log", "", "", {"rows": [[1, 2], [3, 4]]})
	assert_false(body.contains("\n") or body.contains("\t"), "không thụt lề: log trận nhỏ hơn nhiều")


func test_D_287_reply_success_shows_report_id() -> void:
	var r: Dictionary = PerfUpload.reply(HTTPRequest.RESULT_SUCCESS, 200, '{"id": "B-0042"}'.to_utf8_buffer())
	assert_true(r["ok"])
	assert_true((r["message"] as String).contains("B-0042"), r["message"])


func test_D_287_reply_errors_say_what_to_do() -> void:
	var busy: Dictionary = PerfUpload.reply(HTTPRequest.RESULT_SUCCESS, 429, PackedByteArray())
	assert_false(busy["ok"])
	assert_true((busy["message"] as String).contains("phút"), busy["message"])
	var big: Dictionary = PerfUpload.reply(HTTPRequest.RESULT_SUCCESS, 413, PackedByteArray())
	assert_true((big["message"] as String).contains("Lưu JSON"), big["message"])
	var net: Dictionary = PerfUpload.reply(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedByteArray())
	assert_false(net["ok"])
	assert_true((net["message"] as String).contains("thử lại"), net["message"])
	var odd: Dictionary = PerfUpload.reply(HTTPRequest.RESULT_SUCCESS, 200, "không phải json".to_utf8_buffer())
	assert_false(odd["ok"], "200 mà không có mã báo cáo: coi là lỗi")


func test_D_287_panel_upload_sends_note() -> void:
	var panel: PerfExportPanel = PerfExportPanel.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	var got: Array[String] = []
	panel.upload.connect(func(note: String) -> void: got.append(note))
	(panel.find_child("Note", true, false) as LineEdit).text = "lag lúc giao tranh"
	(panel.find_child("Upload", true, false) as Button).pressed.emit()
	assert_eq(got, ["lag lúc giao tranh"] as Array[String])
	panel.queue_free()
