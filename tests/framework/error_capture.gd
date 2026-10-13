class_name ErrorCapture
extends Logger
## Bắt lỗi engine/script xảy ra trong lúc chạy một test, để lỗi script biến thành
## test đỏ thay vì chỉ in ra rồi bị bỏ qua. Lồng được (test chạy runner khác).

var _stack: Array[PackedStringArray] = []
var _mutex: Mutex = Mutex.new()


func begin() -> void:
	_mutex.lock()
	_stack.append(PackedStringArray())
	_mutex.unlock()


func end() -> PackedStringArray:
	_mutex.lock()
	var out: PackedStringArray = _stack.pop_back() if not _stack.is_empty() else PackedStringArray()
	_mutex.unlock()
	return out


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var text: String = rationale if not rationale.is_empty() else code
	_mutex.lock()
	if not _stack.is_empty():
		_stack[-1].append("script error: %s (%s:%d %s)" % [text, file, line, function])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass
