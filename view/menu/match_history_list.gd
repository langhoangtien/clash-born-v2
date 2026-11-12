class_name MatchHistoryList
extends ScrollContainer
## D-334 / D-343: danh sách trận gần nhất ở màn Tài khoản → Lịch sử trận — mỗi trận: kết quả, tướng mình, K/D/A, chế độ,
## thời lượng; rồi hai dòng đội mình / đội địch (tên trong game nếu là người, "bot" nếu là bot, K/D/A). Cuộn được.

const ROWS: int = 10
const HEIGHT: float = 440.0


func _init() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func show_matches(matches: Array) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	for m: Dictionary in matches.slice(0, ROWS):
		var l: Array[String] = lines(m)
		box.add_child(_label(l[0], 22, UiStyle.GREEN if m.get("won") else UiStyle.RED_TEXT))
		for i: int in range(1, l.size()):
			box.add_child(_label(l[i], 17, UiStyle.DIM))
		box.add_child(HSeparator.new())


## Chữ của một trận (cũng dùng trong test): [kết quả, đội mình, đội địch] — trận cũ chưa có đội thì chỉ dòng đầu.
static func lines(m: Dictionary) -> Array[String]:
	var dur: int = int(m.get("duration_s", 0))
	var out: Array[String] = ["%s · %s · %d/%d/%d · %s · %d:%02d" % [("Thắng" if m.get("won") else "Thua") + (" (đã rời)" if m.get("left", false) else ""), _hero(m.get("hero", "")),
		m.get("kills", 0), m.get("deaths", 0), m.get("assists", 0), m.get("mode", ""), dur / 60, dur % 60]]
	if m.has("allies"):
		out.append("Đội mình: " + _team(m["allies"]))
		out.append("Đội địch: " + _team(m["enemies"]))
	return out


static func _team(players: Array) -> String:
	var parts: PackedStringArray = []
	for p: Dictionary in players:
		var who: String = _hero(p.get("hero", ""))
		var gone: String = ", đã rời" if p.get("left", false) else ""  # NET-12 (D-405): rớt giữa trận, bot đánh thay
		if p.get("me", false):
			who = "★ " + who + (" (đã rời)" if gone != "" else "")
		elif p.get("bot", false):
			who += " (bot)"
		elif String(p.get("name", "")) != "":
			who += " (%s%s)" % [p["name"], gone]
		elif gone != "":
			who += " (đã rời)"
		parts.append("%s %d/%d/%d" % [who, p.get("kills", 0), p.get("deaths", 0), p.get("assists", 0)])
	return " · ".join(parts)


static func _hero(id: String) -> String:
	return id.capitalize()


func _label(text: String, size_px: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", UiStyle.serif(size_px > 20))
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l
