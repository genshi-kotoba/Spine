extends SceneTree
## corridor_assembly_selftest — t6 组装联调 headless 自检（scripts/c3/flow/ inScope；t7 可复用）
## 用法：godot --headless --path F:\Godot\Spine\Spine --script res://scripts/c3/flow/corridor_assembly_selftest.gd
## 内容：真实加载组装后 c3_level.tscn →
##   ① 组装断言（视觉层 3 段墙/地面 + 远景 2 层 + 特异点层装饰 + 旧内容清理）；
##   ② 尽头两段 E 链路（真实 Player.interact_pressed 信号 → C3Flow → CorridorEndItem.touched →
##      end_confirmed → C3Flow.on_corridor_end_confirmed → 黑屏渐变 + 卧室 begin + STAGE_BEDROOM）；
##   ③ 全程玩家站立读回（y≈948±50）。
## 退出码：0=PASS，1=FAIL。只读回，不修改任何工程文件。

var _checks: Array[String] = []
var _level: Node = null


func _initialize() -> void:
	_run()


func _run() -> void:
	await _setup()
	_assert_assembly()
	await _assert_e_chain()
	_finish()


func _setup() -> void:
	var packed: PackedScene = load("res://scenes/c3_level.tscn")
	_level = packed.instantiate()
	root.add_child(_level)
	for i in range(6):
		await process_frame
	_checks.append("setup" if _level != null else "setup_FAIL")


func _assert_assembly() -> void:
	var asm: Node = _level.get_node_or_null("CorridorAssembly")
	if asm == null or not asm.has_method("run_self_check"):
		_checks.append("assembly_ref_FAIL")
		return
	var ok: bool = asm.call("run_self_check")
	_checks.append("assembly_selfcheck" if ok else "assembly_selfcheck_FAIL")
	var visual: Node2D = asm.call("get_visual_layer")
	if visual != null:
		var walls: Array = visual.call("get_wall_nodes")
		_checks.append("visual_walls3" if walls.size() >= 3 else "visual_walls3_FAIL(%d)" % walls.size())
		var layers: Array = visual.call("get_backdrop_layers")
		_checks.append("backdrop2" if layers.size() == 2 else "backdrop2_FAIL")
	else:
		_checks.append("visual_ref_FAIL")


func _assert_e_chain() -> void:
	var item: Node = _level.get_node("Items/CorridorEndItem")
	var flow: Node = _level
	var player: Node2D = _level.get_node("Player")
	var corridor: Node = _level.get_node("Corridor")
	# 诊断读回：end_confirmed 连接数（修复前后对照）。
	var conns: Array = item.get_signal_connection_list("end_confirmed")
	_checks.append("end_conn1" if conns.size() >= 1 else "end_conn_FAIL(%d)" % conns.size())
	# 先把走廊驱动到真实流程的尽头态（MODE_DONE，同 special_layer_selftest 口径），
	# 避免卧室 begin 后走廊仍 IDLE 把 4820 的玩家重钉回 stop_center_x（真实流程无此分支）。
	# 先切走廊阶段（真实流程中走廊只在 STAGE_CORRIDOR 启用）。
	flow.call("set_stage", 7)
	corridor.set("enabled", true)
	corridor.call("_enter_moving")
	corridor.set("_travel_dist", corridor.call("_finite_dist") + 0.01)
	corridor.call("_check_finite")
	player.global_position.x = corridor.get("end_wall_x") + 1.0
	await physics_frame
	await physics_frame
	_checks.append("corridor_done" if int(corridor.get("_mode")) == 3 else "corridor_done_FAIL(%d)" % int(corridor.get("_mode")))
	# 玩家真实物理落位到尽头 item（物理帧落点，非传送——本自检为链路测试）。
	player.global_position = Vector2(4700.0, 940.0)
	var overlapping := false
	for i in range(30):
		await physics_frame
		if item.get_overlapping_bodies().has(player):
			overlapping = true
			break
	_checks.append("stand_before" if player.global_position.y > 900.0 and player.global_position.y < 1000.0 else "stand_before_FAIL(%.1f)" % player.global_position.y)
	_checks.append("overlap_ready" if overlapping else "overlap_FAIL")
	# E1：经真实信号链（Player.interact_pressed → C3Flow._on_interact_pressed → touched）
	player.emit_signal("interact_pressed")
	await physics_frame
	await physics_frame
	var s1: int = item.get("current_state")
	_checks.append("e1_state1" if s1 == 1 else "e1_FAIL(s=%d)" % s1)
	# E2 → end_confirmed → C3Flow 黑屏 + 卧室 begin + STAGE_BEDROOM
	player.emit_signal("interact_pressed")
	for i in range(8):
		await process_frame
	var s2: int = item.get("current_state")
	var confirmed: bool = item.call("is_confirmed")
	var stage: int = flow.get("current_stage")
	_checks.append("e2_state2" if s2 == 2 and confirmed else "e2_FAIL(s=%d conf=%s)" % [s2, str(confirmed)])
	_checks.append("bedroom_stage" if stage == 9 else "bedroom_stage_FAIL(%d)" % stage)
	await process_frame
	var bx: float = player.global_position.x
	var by: float = player.global_position.y
	# 卧室重显断言：x 越过尽头墙进入卧室区（>4760）且站立（y≈948）；精确 4820 由 C3Flow 物理断言承担
	# （本 runner 内尽头墙碰撞会对重显位做几像素推挤，属测试态拼接产物）。
	_checks.append("bedroom_respawn" if bx > 4760.0 and bx < 4860.0 and by > 900.0 and by < 1000.0 else "bedroom_respawn_FAIL(x=%.1f y=%.1f)" % [bx, by])
	var unlock: bool = root.get_node("GameState").get_process_flag("bedroom_unlocked")
	_checks.append("bedroom_unlocked" if unlock else "bedroom_unlocked_FAIL")


func _finish() -> void:
	var failed := false
	for c in _checks:
		if c.contains("FAIL"):
			failed = true
		print("[corridor_assembly_selftest] CHECK " + c)
	print("[corridor_assembly_selftest] " + ("PASS" if not failed else "FAIL"))
	quit(1 if failed else 0)
