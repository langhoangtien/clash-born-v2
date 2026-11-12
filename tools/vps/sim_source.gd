extends SceneTree
## NET-10 (D-403): ghi mã băm mã nguồn SIM vào app/net/sim_source.json — chạy sau MỌI lần đổi sim/, content/, data/maps/
## hoặc app/net/net_codec.gd (test test_NET_10_sim_source_file_is_current đỏ nhắc việc này):
##   godot --headless --path . -s tools/vps/sim_source.gd


func _initialize() -> void:
	var h: String = SimSource.compute()
	var f: FileAccess = FileAccess.open(SimSource.FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"hash": h}) + "\n")
	f.close()
	print("sim_source: %s → %s" % [h, SimSource.FILE])
	quit()
