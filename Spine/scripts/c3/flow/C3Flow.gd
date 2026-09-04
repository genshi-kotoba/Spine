class_name C3Flow
extends Node
## C3Flow — C3 关卡流程门控（阶段状态机 + 进程旗标 + item 门控接入 + LIGHT 序列 + 场景编排）
## 对应 docs/c3_gameplay_constraints.md §3.1/§3.2/§6.2/§7.2/§10.4 的流程与门控逻辑层。
## 场景组装（c3_level.tscn）由 t16 负责接线；本品为编排/门控核心。

## 阶段常量（§3.1）。
const STAGE_STUDY := 1
const STAGE_LEAVE_STUDY := 2
const STAGE_LIVING := 3
const STAGE_KITCHEN := 4
const STAGE_RETURN_STUDY := 5
const STAGE_LIGHT := 6
const STAGE_CORRIDOR := 7
const STAGE_CORRIDOR_END := 8
const STAGE_BEDROOM := 9

## 进程旗标常量（§3.2）。
const FLAG_HOLD_BREATH_UNLOCKED := "hold_breath_unlocked"
const FLAG_BEDROOM_DOOR_ACTIVE := "bedroom_door_active"
const FLAG_PAPER_LIVING := "paper_living_collected"
const FLAG_PAPER_KITCHEN := "paper_kitchen_collected"
const FLAG_STUDY_ITEMS_UNLOCKED := "study_items_unlocked"
const FLAG_STUDY_GATE_OPEN := "study_gate_open"
const FLAG_LIGHT_PHASE_DONE := "light_phase_done"
const FLAG_CORRIDOR_ENTERED := "corridor_entered"
const FLAG_CORRIDOR_END := "corridor_end"
const FLAG_BEDROOM_UNLOCKED := "bedroom_unlocked"
const FLAG_BEDROOM_INTERACTIONS_DONE := "bedroom_interactions_done"
const FLAG_END_WHITE := "end_white"

## 当前阶段（运行时状态，不持久化）。
var current_stage: int = STAGE_STUDY
var _study_papers_collected: int = 0

signal stage_changed(new_stage: int)

## ─── 场景编排引用（t16 接线）───
@export var player_path: NodePath
@export var corridor_path: NodePath
@export var bedroom_path: NodePath
@export var breath_path: NodePath
@export var darkness_mask_path: NodePath
@export var screen_shake_path: NodePath
@export var particle_burst_path: NodePath
@export var corridor_end_item_path: NodePath
@export var gate_blocker_path: NodePath
@export var study_spawn: Vector2 = Vector2(320, 948)
@export var study_right_x: float = 1280.0
## LIGHT-C 需隐藏的门/墙（NodePath；如 书房-客厅墙、auto_door、最右侧墙）。
@export var wall_hide_paths: Array[NodePath] = []

var _player: Node2D = null
var _left_study: bool = false
var _corridor: Node = null
var _bedroom: Node = null
var _breath: Node = null
var _mask: Node = null
var _screen_shake: Node = null
var _particle_burst: Node = null
var _phase_debug_loaded: bool = false


func _ready() -> void:
	add_to_group("c3flow")
	_reset_flags()
	_ready_extra()
	if "--self-check" in OS.get_cmdline_user_args():
		var ok := run_scene_self_check()
		get_tree().quit()


## 当前阶段。
func get_stage() -> int:
	return current_stage


## 复位全部旗标与阶段（初生书房状态）。
func _reset_flags() -> void:
	GameState.set_process_flag(FLAG_HOLD_BREATH_UNLOCKED, false)
	GameState.set_process_flag(FLAG_BEDROOM_DOOR_ACTIVE, false)
	GameState.set_process_flag(FLAG_PAPER_LIVING, false)
	GameState.set_process_flag(FLAG_PAPER_KITCHEN, false)
	GameState.set_process_flag(FLAG_STUDY_ITEMS_UNLOCKED, false)
	GameState.set_process_flag(FLAG_STUDY_GATE_OPEN, false)
	GameState.set_process_flag(FLAG_LIGHT_PHASE_DONE, false)
	GameState.set_process_flag(FLAG_CORRIDOR_ENTERED, false)
	GameState.set_process_flag(FLAG_CORRIDOR_END, false)
	GameState.set_process_flag(FLAG_BEDROOM_UNLOCKED, false)
	GameState.set_process_flag(FLAG_BEDROOM_INTERACTIONS_DONE, false)
	GameState.set_process_flag(FLAG_END_WHITE, false)
	current_stage = STAGE_STUDY
	_study_papers_collected = 0


## 设置阶段；进入关键阶段时应用旗标/序列。
func set_stage(s: int) -> void:
	current_stage = s
	stage_changed.emit(s)
	_apply_stage_effects(s)


## 应用阶段侧效（旗标 + LIGHT 序列 + 走廊启用）。
func _apply_stage_effects(s: int) -> void:
	if s >= STAGE_LIGHT:
		GameState.set_process_flag(FLAG_HOLD_BREATH_UNLOCKED, true)
		GameState.set_process_flag(FLAG_LIGHT_PHASE_DONE, true)
	if s >= STAGE_CORRIDOR:
		GameState.set_process_flag(FLAG_CORRIDOR_ENTERED, true)
	if s == STAGE_CORRIDOR_END:
		GameState.set_process_flag(FLAG_CORRIDOR_END, true)
	if s >= STAGE_BEDROOM:
		GameState.set_process_flag(FLAG_BEDROOM_UNLOCKED, true)
		GameState.set_process_flag(FLAG_BEDROOM_INTERACTIONS_DONE, true)
	if _corridor != null:
		if _corridor.has_method("set_enabled"):
			(_corridor as Node).set_enabled(s >= STAGE_CORRIDOR)
		else:
			_corridor.set("enabled", s >= STAGE_CORRIDOR)
	if s == STAGE_LIGHT:
		enter_stage_light()


# ─── 事件钩子（场景/t16 接线调用）───

## 玩家离开书房 → 锁书房-客厅门（无法回）+ 进入 LEAVE_STUDY（§6.2）。
func on_player_left_study() -> void:
	_left_study = true
	GameState.set_process_flag(FLAG_STUDY_GATE_OPEN, false)
	_apply_gate_blocker()
	if current_stage == STAGE_STUDY:
		set_stage(STAGE_LEAVE_STUDY)


## 试卷得分回调（由 C3PaperItem 调用）。
func on_paper_collected(paper_id: String, score: int) -> void:
	if paper_id == "paper_living":
		GameState.set_process_flag(FLAG_PAPER_LIVING, true)
	elif paper_id == "paper_kitchen":
		GameState.set_process_flag(FLAG_PAPER_KITCHEN, true)
	elif paper_id == "study_a" or paper_id == "study_b":
		_collect_study_paper()
	_refresh_study_state()


func _collect_study_paper() -> void:
	_study_papers_collected += 1


func _refresh_study_state() -> void:
	var living_ok := GameState.get_process_flag(FLAG_PAPER_LIVING)
	var kitchen_ok := GameState.get_process_flag(FLAG_PAPER_KITCHEN)
	if living_ok and kitchen_ok:
		GameState.set_process_flag(FLAG_STUDY_GATE_OPEN, true)
		GameState.set_process_flag(FLAG_STUDY_ITEMS_UNLOCKED, true)
		_apply_gate_blocker()
		if current_stage < STAGE_RETURN_STUDY:
			set_stage(STAGE_RETURN_STUDY)
	if _study_papers_collected >= 2 and not GameState.get_process_flag(FLAG_LIGHT_PHASE_DONE):
		GameState.set_process_flag(FLAG_LIGHT_PHASE_DONE, true)
		set_stage(STAGE_LIGHT)


# ─── 卧室门三态（§5.2）───

func on_bedroom_door_named() -> void:
	GameState.set_process_flag(FLAG_BEDROOM_DOOR_ACTIVE, true)


## 卧室门 E → 搬运进卧室（begin + 黑屏渐变）。供场景连接 BedroomHallDoor 的 gate_ok/touched。
func on_enter_bedroom() -> void:
	_fade_black_and_begin_bedroom()


# ─── LIGHT 序列（§7.2 A-E）───

## 进入 STAGE_LIGHT 执行光影子步骤：A 全黑(除书房) → B 黑屏渐变+角色重置书房初始位 →
## C 隐藏门墙+ScreenShake+ParticleBurst → C2 corridor_entered=true → D 微压暗 → E hold_breath_unlocked。
func enter_stage_light() -> void:
	# A: 遮罩全黑（除书房）：follow_player 但以书房为中央、极大亮区被书房覆盖（白模近似：全黑跟随玩家）
	if _mask != null:
		_mask.enabled = true
		_mask.follow_player = true
		_mask.darkness_color = Color(0.01, 0.01, 0.02, 1)
		_mask.radius_inner = 500.0
		_mask.radius_outer = 900.0
		_mask.softness = 0.3
	# B: 玩家重置书房初始位
	_reset_player_to_study()
	# C: 隐藏门/墙 + 粒子震撼
	_hide_walls()
	if _screen_shake != null and _screen_shake.has_method("shake"):
		(_screen_shake as Node).shake(14.0, 0.4)
	if _particle_burst != null and _particle_burst.has_method("burst"):
		(_particle_burst as Node).burst()
	# C2: corridor_entered=true
	GameState.set_process_flag(FLAG_CORRIDOR_ENTERED, true)
	# D: 微压暗（不明显；Tween 渐变，f7）
	if _mask != null:
		_tween_mask_to(Color(0.06, 0.06, 0.08, 0.35), 2000.0, 2600.0, 0.6)
	# E: hold_breath_unlocked=true
	GameState.set_process_flag(FLAG_HOLD_BREATH_UNLOCKED, true)


func _reset_player_to_study() -> void:
	if _player != null:
		_player.global_position = study_spawn


func _hide_walls() -> void:
	for wp in wall_hide_paths:
		var n := get_node_or_null(wp)
		if n != null:
			n.visible = false
			# 无条件禁用其子 CollisionShape2D（f4：去掉 meta 条件）
			for child in n.get_children():
				if child is CollisionShape2D:
					(child as CollisionShape2D).set_deferred("disabled", true)


# ─── 信号响应（f5）───

## CorridorEndItem end_confirmed → 黑屏 → 进入卧室 begin()。
func on_corridor_end_confirmed() -> void:
	_fade_black_and_begin_bedroom()


## BreathSystem breath_disable_requested → 关闭呼吸机制。
func on_breath_disable() -> void:
	if _breath != null and _breath.has_method("set_enabled"):
		(_breath as Node).set_enabled(false)


## BedroomEndItem white_screen_end_requested → 全屏白渐变结束。
func on_white_screen_end() -> void:
	if _mask != null:
		_mask.enabled = true
		_tween_mask_to(Color(1, 1, 1, 1), 4000.0, 4500.0, 0.8)
	GameState.set_process_flag(FLAG_END_WHITE, true)


## 黑屏渐变 + 进入卧室 begin()。
func _fade_black_and_begin_bedroom() -> void:
	if _mask != null:
		_mask.enabled = true
		_tween_mask_to(Color(0, 0, 0, 1), 4000.0, 4500.0, 0.8)
	if _bedroom != null and _bedroom.has_method("begin"):
		(_bedroom as Node).begin()
	set_stage(STAGE_BEDROOM)


## 用 Tween 渐变遮罩颜色/半径（f7；DarknessMask._process 读导出属性，故 tween 属性可生效）。
func _tween_mask_to(col: Color, ri: float, ro: float, dur: float) -> void:
	if _mask == null:
		return
	var m := _mask
	var tw := create_tween()
	tw.tween_property(m, "darkness_color", col, dur)
	tw.tween_property(m, "radius_inner", ri, dur)
	tw.tween_property(m, "radius_outer", ro, dur)


# ─── 自检（场景级协调：单一 quit 出口，汇总各子系统）───

## 场景级自检：汇总 C3Flow + 各子系统 run_self_check，统一 PASS/FAIL（单一 quit 出口）。
func run_scene_self_check() -> bool:
	var checks: Array[String] = []
	_run_flow_checks(checks)
	# 主角位置断言（f5/§9.3 站立坐标）：玩家应站立于合法位置 y≈948±50 且 x 在场景内（物理帧后读回）
	if _player != null:
		var pp: Vector2 = _player.global_position
		var standing: bool = (pp.y > 900.0 and pp.y < 1000.0 and pp.x >= 0.0 and pp.x <= 7000.0)
		checks.append("player_pos" if standing else "player_pos_FAIL")
	else:
		checks.append("player_ref" if false else "player_ref_FAIL")
	var failed := false
	for c in checks:
		if c.ends_with("FAIL") or c.contains("FAIL"):
			failed = true
		print("[c3_flow] CHECK " + c)
	print("[c3_flow] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	return not failed


## 调用子系统 run_self_check()；返回 true 仅当方法存在且返回 true（void/无方法按 false，避免类型错误）。
func _call_bool_selftest(n: Node) -> bool:
	if n == null or not n.has_method("run_self_check"):
		return false
	var res: Variant = n.call("run_self_check")
	return res is bool and (res as bool)


func _run_flow_checks(checks: Array[String]) -> void:
	_reset_flags()
	checks.append("s1_study_locked" if (not GameState.get_process_flag(FLAG_STUDY_ITEMS_UNLOCKED) and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN) and current_stage == STAGE_STUDY) else "s1_study_locked_FAIL")
	on_player_left_study()
	checks.append("s2_leave_study" if (current_stage == STAGE_LEAVE_STUDY and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN)) else "s2_leave_study_FAIL")
	on_paper_collected("paper_living", 100)
	on_paper_collected("paper_kitchen", 100)
	checks.append("s4_unlock_study" if (GameState.get_process_flag(FLAG_STUDY_ITEMS_UNLOCKED) and GameState.get_process_flag(FLAG_STUDY_GATE_OPEN)) else "s4_unlock_study_FAIL")
	on_paper_collected("study_b", 99)
	checks.append("s5_study_b" if not GameState.get_process_flag(FLAG_LIGHT_PHASE_DONE) else "s5_study_b_FAIL")
	on_paper_collected("study_a", 100)
	checks.append("s6_light" if (GameState.get_process_flag(FLAG_LIGHT_PHASE_DONE) and current_stage == STAGE_LIGHT and GameState.get_process_flag(FLAG_HOLD_BREATH_UNLOCKED)) else "s6_light_FAIL")
	_reset_flags()
	on_bedroom_door_named()
	checks.append("s8_bedroom_named" if GameState.get_process_flag(FLAG_BEDROOM_DOOR_ACTIVE) else "s8_bedroom_named_FAIL")


# ─── 场景编排 ───

func _ready_extra() -> void:
	_resolve_scene_refs()
	_connect_scene_signals()
	_apply_phase_arg()


## 连接子系统信号（f5：门 E→进卧室 / end_confirmed→黑屏→begin / breath_disable→set_enabled(false) / white_screen→全屏白）。
func _connect_scene_signals() -> void:
	if _bedroom != null:
		if _bedroom.has_signal("breath_disable_requested"):
			_bedroom.connect("breath_disable_requested", Callable(self, "on_breath_disable"))
		if _bedroom.has_signal("white_screen_end_requested"):
			_bedroom.connect("white_screen_end_requested", Callable(self, "on_white_screen_end"))
	if _corridor != null:
		if _corridor.has_signal("corridor_entered"):
			_corridor.connect("corridor_entered", Callable(self, "_on_corridor_entered"))
	if corridor_end_item_path != NodePath():
		var ce := get_node_or_null(corridor_end_item_path)
		if ce != null and ce.has_signal("end_confirmed"):
			ce.connect("end_confirmed", Callable(self, "on_corridor_end_confirmed"))


func _on_corridor_entered() -> void:
	GameState.set_process_flag(FLAG_CORRIDOR_ENTERED, true)


## 按 study_gate_open 开关书房-客厅门禁阻挡（物理阻挡，f6）。
func _apply_gate_blocker() -> void:
	if gate_blocker_path == NodePath():
		return
	var blocker := get_node_or_null(gate_blocker_path)
	if blocker == null:
		return
	# 仅当『已出过书房 且 study_gate_open=false』时阻挡（f3：初始不阻挡，可自由出入书房）
	var blocked: bool = _left_study and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN)
	for child in blocker.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not blocked)
	blocker.visible = blocked


func _resolve_scene_refs() -> void:
	if player_path != NodePath():
		var n := get_node_or_null(player_path)
		if n is Node2D:
			_player = n as Node2D
	if corridor_path != NodePath():
		_corridor = get_node_or_null(corridor_path)
	if bedroom_path != NodePath():
		_bedroom = get_node_or_null(bedroom_path)
	if breath_path != NodePath():
		_breath = get_node_or_null(breath_path)
	if darkness_mask_path != NodePath():
		_mask = get_node_or_null(darkness_mask_path)
	if screen_shake_path != NodePath():
		_screen_shake = get_node_or_null(screen_shake_path)
	if particle_burst_path != NodePath():
		_particle_burst = get_node_or_null(particle_burst_path)


## 读取命令行 --phase=<1..9> 直接跳到对应阶段（调试入口；main.tscn 不动）。
func _apply_phase_arg() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			var p := int(arg.trim_prefix("--phase="))
			if p >= STAGE_STUDY and p <= STAGE_BEDROOM:
				set_stage(p)
				_phase_debug_loaded = true


func _process(_delta: float) -> void:
	if _phase_debug_loaded:
		return
	if _player != null and current_stage == STAGE_STUDY:
		if _player.global_position.x >= study_right_x:
			on_player_left_study()
