class_name Corridor
extends Node2D
## Corridor — C3 固定长度走廊（用户 2026-09-05 定案：无限循环机制废弃，1920*4=7680 有限走廊）
## 职责：走廊进入检测、固定坐标特异点屏息判定（通过/失败传送至第一特异点前 1/4）、尽头检测。
## 玩家正常移动（不 pin、不移动墙）；视觉为场景固定节点（CorridorWall/CorridorFloorVisual 7680 宽）。

## —— 信号（供 C3Flow 接线）——
signal corridor_entered                ## 玩家进入走廊起点。
signal special_point_passed(index: int) ## 屏息通过第 index 个特异点。
signal teleport_triggered              ## 未屏息 → 传送到第一特异点前 1/4。
signal corridor_finite                 ## 走到走廊尽头判定（固定走廊=到达 end_wall_x）。
signal end_wall_reached                ## 玩家到达尽头。

## —— 节点 ——
@export var player: NodePath

## —— 几何/节奏参数（固定走廊）——
@export var corridor_start_x: float = 3840.0   ## 走廊起点（世界 x）。
@export var end_wall_x: float = 11400.0        ## 走廊尽头判定 x（EndWall 碰撞在 11520）。
@export var special_x: Array[float] = [5280.0, 5760.0, 6240.0]  ## 三特异点固定世界 x。
@export var first_special_x: float = 5280.0     ## 第一个特异点 x（失败传送回 first_special_x - special_span）。
@export var special_span: float = 480.0         ## 特异点间距（1/4 屏）。

## —— 屏息 / 旗标 ——
@export var hold_breath_unlocked_flag: String = "hold_breath_unlocked"
@export var corridor_entered_flag: String = "corridor_entered"
@export var corridor_end_flag: String = "corridor_end"
@export var hold_threshold: float = 0.5
@export var enabled: bool = true

const MODE_IDLE := 0
const MODE_CORRIDOR := 1
const MODE_FINITE := 2
const MODE_DONE := 3

var _mode: int = MODE_IDLE
var _player: Node2D = null
var _next_special: int = 0
var _hold_time: float = 0.0


func _ready() -> void:
	add_to_group("c3corridor")
	_resolve_refs()
	_ensure_input()


func _process(delta: float) -> void:
	if not enabled:
		return
	if StoryMonitor.input_locked:
		_hold_time = 0.0
		return
	_update_hold(delta)
	var p := _get_player()
	if p == null:
		return
	if _mode == MODE_IDLE:
		if p.global_position.x >= corridor_start_x:
			_enter_corridor()
	elif _mode == MODE_CORRIDOR:
		_check_specials()
		if p.global_position.x >= end_wall_x:
			_enter_finite()
	elif _mode == MODE_FINITE:
		if p.global_position.x >= end_wall_x:
			_mode = MODE_DONE
			end_wall_reached.emit()


## 长按屏息计时（breathe 键按住累积；松开归零）。
func _update_hold(delta: float) -> void:
	if Input.is_action_pressed("breathe"):
		_hold_time += delta
	else:
		_hold_time = 0.0


## 是否处于屏息态（长按 ≥ hold_threshold 且解锁）。
func is_holding_breath() -> bool:
	if not GameState.get_process_flag(hold_breath_unlocked_flag):
		return false
	return _hold_time >= hold_threshold


func _enter_corridor() -> void:
	_mode = MODE_CORRIDOR
	_next_special = 0
	GameState.set_process_flag(corridor_entered_flag, true)
	corridor_entered.emit()


## 特异点判定：玩家到达固定 x 时屏息判定（通过推进；未屏息传送回第一特异点前 1/4）。
func _check_specials() -> void:
	while _next_special < special_x.size():
		var sx: float = special_x[_next_special]
		if _player.global_position.x < sx:
			break
		if is_holding_breath():
			special_point_passed.emit(_next_special)
			_next_special += 1
		else:
			_teleport_back()
			return


func _teleport_back() -> void:
	_player.global_position.x = first_special_x - special_span
	_next_special = 0
	teleport_triggered.emit()


func _enter_finite() -> void:
	_mode = MODE_FINITE
	GameState.set_process_flag(corridor_end_flag, true)
	corridor_finite.emit()


## 运行时兜底注册 breathe(空格)（D8；project.godot [input] 已定义则跳过）。
func _ensure_input() -> void:
	if InputMap.has_action("breathe"):
		return
	InputMap.add_action("breathe")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	InputMap.action_add_event("breathe", ev)


func _resolve_refs() -> void:
	if player != NodePath():
		var n := get_node_or_null(player)
		if n is Node2D:
			_player = n as Node2D
	if _player == null:
		var gp := get_tree().get_first_node_in_group("player")
		if gp is Node2D:
			_player = gp as Node2D


func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_resolve_refs()
	return _player


## 开关走廊判定（供 C3Flow/流程控制；false → 不检测）。
func set_enabled(enabled_value: bool) -> void:
	enabled = enabled_value


# ─── 自检（--self-check；验证进入 / 特异点屏息通过与失败传送 / 尽头）───

func run_self_check() -> bool:
	var checks: Array[String] = []
	enabled = true
	var p := _get_player()
	if p == null:
		print("[corridor] SELF-CHECK FAIL (no player)")
		return false
	# 1. 进入走廊
	p.global_position.x = corridor_start_x + 10.0
	await get_tree().physics_frame
	checks.append("enter1" if _mode == MODE_CORRIDOR and GameState.get_process_flag(corridor_entered_flag) else "enter_FAIL1")
	# 2. 未屏息过第一特异点 → 传送
	_hold_time = 0.0
	GameState.set_process_flag(hold_breath_unlocked_flag, false)
	p.global_position.x = first_special_x + 10.0
	await get_tree().physics_frame
	checks.append("teleport1" if (absf(p.global_position.x - (first_special_x - special_span)) < 0.5 and _next_special == 0) else "teleport_FAIL1")
	# 3. 屏息通过三特异点
	GameState.set_process_flag(hold_breath_unlocked_flag, true)
	_hold_time = hold_threshold + 0.1
	_next_special = 0
	p.global_position.x = first_special_x + 10.0
	await get_tree().physics_frame
	checks.append("pass1" if _next_special == 1 else "pass_FAIL1")
	_hold_time = hold_threshold + 0.1
	p.global_position.x = special_x[1] + 10.0
	await get_tree().physics_frame
	checks.append("pass2" if _next_special == 2 else "pass_FAIL2")
	_hold_time = hold_threshold + 0.1
	p.global_position.x = special_x[2] + 10.0
	await get_tree().physics_frame
	checks.append("pass3" if _next_special == 3 else "pass_FAIL3")
	# 4. 走到尽头 → finite
	p.global_position.x = end_wall_x + 10.0
	await get_tree().physics_frame
	checks.append("finite1" if (GameState.get_process_flag(corridor_end_flag) and _mode == MODE_FINITE) else "finite_FAIL1")
	GameState.set_process_flag(hold_breath_unlocked_flag, false)
	var failed := false
	for c in checks:
		if c.contains("FAIL"):
			failed = true
		print("[corridor] CHECK " + c)
	print("[corridor] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	return not failed
