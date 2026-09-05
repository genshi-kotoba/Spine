extends SceneTree
## study_door_selftest — t14 开场书房门 headless 诊断 runner（scripts/c3/flow/ inScope）
## 用法：godot --headless --path F:\Godot\Spine\Spine --script res://scripts/c3/flow/study_door_selftest.gd
## 场景 C（门洞停留/接近开门）：书房态 x=1260 近门 → 门开；x=1285 门洞内停留不被弹回（blocker 未启用）。
## 场景 A（正常信号链）：真实输入（Input.action_press move_right）行走 320→1320+：门先开、可出门、
##   x≤1319 仍 STAGE_STUDY（锁定余量）、x≥1320 触发 on_player_left_study（锁门+blocker 启用）。
## 场景 B（断开 body_entered/exited 信号 = 窗口信号丢失模拟）：重置回书房后仍由兜底轮询开门、出门、锁定。
## 场景 D（trigger_margin）：两扇 auto door 读回 == 80。
## 退出码：0=PASS，1=FAIL。全部断言基于运行中游戏对象读回，不改任何工程文件。

var _checks: Array[String] = []
var _level: Node = null
var _flow: Node = null
var _player: Node2D = null
var _door: Node = null
var _door2: Node = null


func _initialize() -> void:
	_run()


func _run() -> void:
	await _setup()
	await _scenario_c()
	await _reset_study_state(false)
	await _scenario_a()
	await _reset_study_state(true)
	await _scenario_b()
	_scenario_d()
	_finish()


func _setup() -> void:
	var packed: PackedScene = load("res://scenes/c3_level.tscn")
	_level = packed.instantiate()
	root.add_child(_level)
	for i in range(5):
		await process_frame
	_flow = _level
	_player = _level.get_node("Player")
	_door = _level.get_node("WhiteModel/Doors/AutoDoorStudyLiving")
	_door2 = _level.get_node("WhiteModel/Doors/AutoDoorLivingDining")
	_checks.append("setup" if (_level != null and _player != null and _door != null and _door2 != null) else "setup_FAIL")


## 场景 C：接近开门（信号链正常）+ 门洞内停留不被弹回（锁定前 blocker 未启用）。
func _scenario_c() -> void:
	_player.global_position = Vector2(1260.0, 940.0)
	var opened := false
	for i in range(30):
		await physics_frame
		if bool(_door.get("is_open")):
			opened = true
			break
	_checks.append("c_approach_open" if opened else "c_approach_open_FAIL")
	_player.global_position = Vector2(1285.0, 940.0)
	var pushed := false
	for i in range(60):
		await physics_frame
		if absf(_player.global_position.x - 1285.0) > 3.0:
			pushed = true
	_checks.append("c_doorway_stay" if not pushed else "c_doorway_stay_FAIL")


## 场景 A：真实输入行走（信号链正常）：门先开 → 出门 → x≥1320 锁门 + blocker。
func _scenario_a() -> void:
	var door_closed0: bool = not bool(_door.get("is_open"))
	_checks.append("a_start_door_closed" if door_closed0 else "a_start_closed_FAIL")
	Input.action_press("move_right")
	var opened_before_cross := false
	var crossed := false
	var stage_at_1310 := -1
	var stage_after_lock := -1
	var blocker_after_lock := false
	for i in range(700):
		await physics_frame
		var px: float = _player.global_position.x
		var open_now: bool = bool(_door.get("is_open"))
		if open_now and px < 1290.0:
			opened_before_cross = true
		if not crossed and px > 1300.0:
			crossed = true
		if px >= 1305.0 and px <= 1319.0:
			stage_at_1310 = int(_flow.get("current_stage"))
		if crossed and px >= 1320.0:
			stage_after_lock = int(_flow.get("current_stage"))
			blocker_after_lock = _blocker_active()
			break
	Input.action_release("move_right")
	_checks.append("a_door_opened" if opened_before_cross else "a_door_opened_FAIL")
	_checks.append("a_crossed" if crossed else "a_crossed_FAIL")
	_checks.append("a_still_study_at1310" if stage_at_1310 == 1 else "a_still_study_at1310_FAIL(%d)" % stage_at_1310)
	_checks.append("a_locked_at1320" if stage_after_lock == 2 else "a_locked_at1320_FAIL(%d)" % stage_after_lock)
	_checks.append("a_blocker_enabled" if blocker_after_lock else "a_blocker_enabled_FAIL")


## 场景 B：断开门信号（模拟窗口环境 body_entered/exited 丢失）→ 兜底轮询仍开门、可出门、锁定。
func _scenario_b() -> void:
	var bound_entered: Callable = Callable(_flow, "_on_door_body_entered").bind(_door)
	var bound_exited: Callable = Callable(_flow, "_on_door_body_exited").bind(_door)
	if _door.is_connected("body_entered", bound_entered):
		_door.disconnect("body_entered", bound_entered)
	if _door.is_connected("body_exited", bound_exited):
		_door.disconnect("body_exited", bound_exited)
	_checks.append("b_signals_off" if not _door.is_connected("body_entered", bound_entered) else "b_signals_off_FAIL")
	Input.action_press("move_right")
	var opened := false
	var crossed := false
	var locked := false
	for i in range(700):
		await physics_frame
		var px: float = _player.global_position.x
		if bool(_door.get("is_open")) and px < 1290.0:
			opened = true
		if px > 1300.0:
			crossed = true
		if crossed and px >= 1320.0:
			locked = int(_flow.get("current_stage")) == 2
			break
	Input.action_release("move_right")
	_checks.append("b_poll_opened" if opened else "b_poll_opened_FAIL")
	_checks.append("b_crossed" if crossed else "b_crossed_FAIL")
	_checks.append("b_locked" if locked else "b_locked_FAIL")


func _scenario_d() -> void:
	var m1: float = float(_door.get("trigger_margin"))
	var m2: float = float(_door2.get("trigger_margin"))
	_checks.append("d_margin80" if absf(m1 - 80.0) < 0.01 and absf(m2 - 80.0) < 0.01 else "d_margin_FAIL(%.0f/%.0f)" % [m1, m2])


## 重置回书房初态（流程自身 API）：旗标/阶段/门关/玩家回位；signals_off=true 时同时断开信号。
func _reset_study_state(signals_off: bool) -> void:
	Input.action_release("move_right")
	_flow.set("_left_study", false)
	root.get_node("GameState").set_process_flag("study_gate_open", true)
	_flow.call("set_stage", 1)
	_flow.call("_apply_gate_blocker")
	_player.global_position = Vector2(320.0, 940.0)
	if bool(_door.get("is_open")):
		_door.call("_do_close")
	if not signals_off:
		return
	var bound_entered: Callable = Callable(_flow, "_on_door_body_entered").bind(_door)
	var bound_exited: Callable = Callable(_flow, "_on_door_body_exited").bind(_door)
	if _door.is_connected("body_entered", bound_entered):
		_door.disconnect("body_entered", bound_entered)
	if _door.is_connected("body_exited", bound_exited):
		_door.disconnect("body_exited", bound_exited)
	await physics_frame


## StudyGateBlocker 碰撞是否已启用（true=阻挡）。
func _blocker_active() -> bool:
	var blocker := _level.get_node_or_null("WhiteModel/Environment/StudyGateBlocker")
	if blocker == null:
		return false
	for child in blocker.get_children():
		if child is CollisionShape2D:
			return not (child as CollisionShape2D).disabled
	return false


func _finish() -> void:
	var failed := false
	for c in _checks:
		if c.contains("FAIL"):
			failed = true
		print("[study_door_selftest] CHECK " + c)
	print("[study_door_selftest] " + ("PASS" if not failed else "FAIL"))
	quit(1 if failed else 0)
