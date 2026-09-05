extends SceneTree
## SpecialPointLayer headless 集成自检（t5 验证证据，scripts/c3/corridor_specials/ inScope）
## 用法：godot --headless --path F:\Godot\Spine\Spine --script res://scripts/c3/corridor_specials/special_layer_selftest.gd
## 内容：真实加载 c3_level.tscn → 挂 SpecialPointLayer → 结构走查 + 相位断言（travel 阈值触发）+
##       未屏息传送/屏息通过（真实 Corridor 判定链）+ 有限化与走到尽头（真实 per-frame 循环）+ D-R6 参数独立性。
## 退出码：0=PASS，1=FAIL。全部断言基于运行中游戏对象的读回，不修改任何场景/脚本文件。

var _layer: Node2D = null
var _corridor: Node = null
var _checks: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await _setup()
	await _assert_structure()
	await _assert_phase()
	_assert_teleport()
	_assert_pass()
	await _assert_finite_walk()
	_assert_dr6()
	_finish()


func _setup() -> void:
	var packed: PackedScene = load("res://scenes/c3_level.tscn")
	var level := packed.instantiate()
	root.add_child(level)
	# 隔离 C3Flow 阶段自动推进（玩家搬到走廊区会触发 on_player_left_study → set_stage → 关闭走廊）；
	# 本自检只测走廊判定链，设置其调试旗标使 _process 早退（与 --phase 调试入口同机制）。
	level.set("_phase_debug_loaded", true)
	await process_frame
	await process_frame
	await process_frame
	_corridor = level.get_node("Corridor")
	# 双套并存测试隔离：移除旧 _build_specials 节点（运行时移除，不改文件）
	for i in range(3):
		var old := _corridor.get_node_or_null("Special%d" % i)
		if old != null:
			old.queue_free()
	await process_frame
	var layer: Node2D = load("res://scripts/c3/corridor_specials/SpecialPointLayer.gd").new()
	layer.name = "SpecialPointLayer"
	layer.set("corridor_path", _corridor.get_path())
	level.add_child(layer)
	await process_frame
	await process_frame
	_layer = layer
	_checks.append("setup" if (_layer != null and _corridor != null) else "setup_FAIL")


func _assert_structure() -> void:
	if _layer == null:
		_checks.append("decorated_FAIL0")
		return
	var decorated: int = _layer.get_decorated_count()
	_checks.append("decorated3" if decorated == 3 else "decorated_FAIL(%d)" % decorated)
	var specials: Array = _layer.get_specials()
	if specials.size() >= 3:
		var cert := specials[0] as Node2D
		var book := specials[1] as Node2D
		var text := specials[2] as Node2D
		_checks.append("cert12" if _count(cert, "Cert") == 12 else "cert_FAIL(%d)" % _count(cert, "Cert"))
		_checks.append("book6" if _count(book, "Book") == 6 else "book_FAIL(%d)" % _count(book, "Book"))
		var t := text.get_node_or_null("Text")
		var text_ok := false
		if t is Label:
			var lab := t as Label
			text_ok = lab.text == "提升一分，干掉千人" and lab.get_theme_font_size("font_size") == 34
		_checks.append("text34" if text_ok else "text_FAIL")
	else:
		_checks.append("specials_FAIL")
	# 载体断言（B6 修复）：特异点父节点必须是 CorridorSegment（内容随段回跳）
	var on_segment := true
	for s in _layer.get_specials():
		var p := (s as Node2D).get_parent()
		if p == null or not p.has_method("get_anchor_x"):
			on_segment = false
	_checks.append("on_segment" if on_segment else "on_segment_FAIL")


func _assert_phase() -> void:
	var base: float = _corridor.call("get_anchor_x")
	var first: float = _corridor.get("first_special_dist")
	var span: float = _corridor.get("special_span")
	var w: float = _corridor.get("segment_width")
	var phase_ok := true
	var at_threshold_ok := true
	for t in [0.0, 400.0, 800.0, 1020.0, 1360.0, 1700.0, 2040.0, 3000.0]:
		_corridor.set("_travel_dist", t)
		_corridor.call("_apply_wall_offset")
		await process_frame
		for i in range(3):
			var tau: float = first + float(i) * span
			var expect: float = base + fposmod(tau, w) - fposmod(t, w)
			var wx: float = _layer.special_world_x(i)
			if absf(wx - expect) > 0.5:
				phase_ok = false
			if absf(t - tau) < 0.01 and absf(wx - base) > 0.5:
				at_threshold_ok = false
	_checks.append("phase8" if phase_ok else "phase_FAIL")
	_checks.append("threshold_center" if at_threshold_ok else "threshold_FAIL")
	_corridor.set("_travel_dist", 0.0)
	_corridor.call("_apply_wall_offset")


func _assert_teleport() -> void:
	root.get_node("GameState").set_process_flag("hold_breath_unlocked", false)
	_corridor.set("_hold_time", 0.0)
	_corridor.set("_travel_dist", _corridor.get("first_special_dist") + 0.01)
	_corridor.set("_next_special", 0)
	_corridor.call("_handle_specials")
	var travel: float = _corridor.get("_travel_dist")
	var next_special: int = _corridor.get("_next_special")
	var expect_back: float = _corridor.get("first_special_dist") - _corridor.get("special_span")
	var ok := absf(travel - expect_back) < 0.5 and next_special == 0
	_checks.append("teleport1" if ok else "teleport_FAIL(t=%f n=%d)" % [travel, next_special])


func _assert_pass() -> void:
	root.get_node("GameState").set_process_flag("hold_breath_unlocked", true)
	_corridor.set("_hold_time", _corridor.get("hold_threshold") + 0.1)
	_corridor.set("_travel_dist", _corridor.get("first_special_dist") + 0.01)
	_corridor.set("_next_special", 0)
	_corridor.call("_handle_specials")
	var n1: int = _corridor.get("_next_special")
	_checks.append("pass1" if n1 == 1 else "pass_FAIL1(n=%d)" % n1)
	_corridor.set("_travel_dist", _corridor.call("_finite_dist") + 0.01)
	_corridor.set("_next_special", 0)
	_corridor.call("_handle_specials")
	var n3: int = _corridor.get("_next_special")
	_checks.append("pass3" if n3 == 3 else "pass_FAIL3(n=%d)" % n3)


func _assert_finite_walk() -> void:
	_corridor.set("enabled", true)
	_corridor.call("_enter_moving")
	_corridor.set("_travel_dist", _corridor.call("_finite_dist") + 0.01)
	_corridor.call("_check_finite")
	var flag_ok: bool = root.get_node("GameState").get_process_flag("corridor_end")
	var mode_finite: int = _corridor.get("_mode")
	_checks.append("finite1" if (flag_ok and mode_finite == 2) else "finite_FAIL(flag=%s mode=%d)" % [str(flag_ok), mode_finite])
	var player: Node2D = _corridor.call("_get_player")
	player.global_position.x = _corridor.get("end_wall_x") - 40.0
	await process_frame
	await process_frame
	var mode_before: int = _corridor.get("_mode")
	_checks.append("still_finite" if mode_before == 2 else "still_finite_FAIL(mode=%d)" % mode_before)
	player.global_position.x = _corridor.get("end_wall_x") + 1.0
	await process_frame
	await process_frame
	await process_frame
	var mode_after: int = _corridor.get("_mode")
	_checks.append("end_wall_done" if mode_after == 3 else "end_wall_FAIL(mode=%d)" % mode_after)


func _assert_dr6() -> void:
	_layer.set("hold_threshold", 0.35)
	_layer.call("_apply_hold_threshold")
	var hd: float = _corridor.get("hold_threshold")
	_checks.append("sync035" if absf(hd - 0.35) < 0.001 else "sync_FAIL(%f)" % hd)
	_corridor.set("_hold_time", 0.4)
	var holding: bool = _corridor.call("is_holding_breath")
	_checks.append("judge04" if holding else "judge04_FAIL")
	var breath := root.get_node("C3Level/Breath")
	var bd: float = breath.get("hold_burst_delay")
	_checks.append("burst05" if absf(bd - 0.5) < 0.001 else "burst_FAIL(%f)" % bd)


func _count(node: Node2D, name_prefix: String) -> int:
	var n := 0
	for child in node.get_children():
		if child.name.begins_with(name_prefix):
			n += 1
	return n


func _finish() -> void:
	var failed := false
	for c in _checks:
		if c.contains("FAIL"):
			failed = true
		print("[special_layer_selftest] CHECK " + c)
	print("[special_layer_selftest] " + ("PASS" if not failed else "FAIL"))
	quit(1 if failed else 0)
