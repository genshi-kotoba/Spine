class_name BreathSystem
extends Node
## BreathSystem — 呼吸机制组件（C3 gameplay §4）
## 单击 breathe(空格)：启动一次呼吸（重置计时、恢复气泡、清除缺氧）。
## breathe_timeout 内未按 → 气泡破裂 → 触发缺氧（DarknessMask 昏暗透光渐变压暗，5s 后仅角色一圈正常）。
## 长按 breathe ≥ hold_burst_delay（需 hold_breath_unlocked_flag 为真，④ 解锁）→ 屏息持续（刷新呼吸计时）；
## 缺氧不再由长按触发（用户定案：长按 1s 的全屏昏暗 + 粒子震动由 Corridor 承担）。
## StoryMonitor.input_locked 时不响应任何输入；set_enabled(false) 关闭呼吸机制（卧室结局解除）。
## 输入动作 breathe：规格 D8 允许新增（唯一 project.godot [input] 变更点）；此处做运行时兜底注册
## （若 project.godot 已定义则跳过），使组件可独立、可在 headless --self-check 下工作。
## 依赖前置 DarknessMask（可配置光影遮罩）与同模块 Bubble。

signal breathed
signal bubble_broken
signal hypoxia_started
signal hypoxia_cleared

## 气泡节点（NodePath；空 → 本节点子树内查找 Bubble）。
@export var bubble: NodePath

## 缺氧遮罩（DarknessMask；NodePath；空 → 本节点子树内查找）。
@export var darkness_mask: NodePath

## 玩家节点（空 → 组 "player" 或场景树内查找）。
@export var player: NodePath

## 气泡未按的计时上限（s）。
@export var breathe_timeout: float = 10.0

## 缺氧渐缩时长（s）。
@export var hypoxia_shrink_duration: float = 5.0

## 长按屏息解锁旗标名（GameState.process_flags 键）。
@export var hold_breath_unlocked_flag: String = "hold_breath_unlocked"

## 长按屏息触发缺氧的时长阈值（s）。
@export var hold_burst_delay: float = 0.5

## 缺氧遮罩颜色（非全黑，深蓝黑；用户口径「非全黑」）。
@export var hypoxia_color: Color = Color(0.02, 0.03, 0.09, 0.55)  ## 昏暗透光（用户定案：非全黑）

## 缺氧初始半径（大）。
@export var hypoxia_radius_outer: float = 1200.0
@export var hypoxia_radius_inner: float = 1000.0

## 缺氧最终半径（小；5s 后仅角色周围一圈正常）。
@export var hypoxia_radius_final_outer: float = 190.0
@export var hypoxia_radius_final_inner: float = 130.0

## 缺氧边缘软度。
@export var hypoxia_softness: float = 0.35

## 运行时锁定（卧室结局解除呼吸机制）。
var _enabled: bool = true

var _bubble: Bubble = null
var _mask: DarknessMask = null
var _player: Node2D = null

## 剩余计时（breathe_timeout 倒计时）。
var _countdown: float = 0.0

## 缺氧进行中。
var _hypoxia_active: bool = false

## 缺氧渐缩进度 0→1。
var _shrink_t: float = 0.0

## 长按屏息状态跟踪。
var _hold_pressed: bool = false
var _hold_time: float = 0.0
var _hold_reached: bool = false
var _hold_burst_done: bool = false


func _ready() -> void:
	_resolve_refs()
	_ensure_input()
	_countdown = breathe_timeout
	# 出生时气泡可见漂浮（角色身旁；修复 t24：气泡未显示）
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.restore()


func _process(delta: float) -> void:
	if not _enabled:
		return
	if StoryMonitor.input_locked:
		_reset_hold()
		return
	if _hypoxia_active:
		_update_hypoxia(delta)
		_update_hold(delta)
		return
	_countdown -= delta
	if _countdown <= 0.0:
		_break_bubble()
		_start_hypoxia()
	_update_hold(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if StoryMonitor.input_locked:
		return
	if event.is_action_pressed("breathe"):
		_hold_pressed = true
		_hold_time = 0.0
		_hold_reached = false
		_hold_burst_done = false
	elif event.is_action_released("breathe") and _hold_pressed:
		# 短按（未达长按阈值）→ 一次呼吸；长按（已达阈值）不重复呼吸（封闭期也算无效果）。
		if not _hold_reached:
			breathe()
		_reset_hold()


## 单击呼吸：重置计时、恢复气泡、清除缺氧。
func breathe() -> void:
	_countdown = breathe_timeout
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.restore()
	_clear_hypoxia()
	breathed.emit()


## 开关呼吸机制（卧室结局解除：停止计时/缺氧并恢复气泡）。
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_reset_hold()
		if _hypoxia_active:
			_clear_hypoxia()
		_countdown = breathe_timeout
		if _bubble != null and is_instance_valid(_bubble):
			_bubble.restore()


## 缺氧是否进行中。
func is_hypoxia_active() -> bool:
	return _hypoxia_active


## 缺氧渐缩进度 0→1。
func get_hypoxia_shrink() -> float:
	return _shrink_t


## 当前倒计时（breathe_timeout - 已流逝；读回/自检）。
func get_countdown() -> float:
	return _countdown


func _break_bubble() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.pop()
	bubble_broken.emit()


func _start_hypoxia() -> void:
	if _mask != null:
		_apply_mask(true)
	_hypoxia_active = true
	_shrink_t = 0.0
	hypoxia_started.emit()


## 缺氧渐缩：由初始大半径 → 最终小半径，在 hypoxia_shrink_duration 内完成。
func _update_hypoxia(delta: float) -> void:
	_shrink_t = minf(_shrink_t + delta / hypoxia_shrink_duration, 1.0)
	if _mask == null:
		return
	var inner: float = lerpf(hypoxia_radius_inner, hypoxia_radius_final_inner, _shrink_t)
	var outer: float = lerpf(hypoxia_radius_outer, hypoxia_radius_final_outer, _shrink_t)
	_mask.radius_inner = inner
	_mask.radius_outer = outer
	if _player != null and is_instance_valid(_player):
		_mask.center_global = _player.global_position


func _clear_hypoxia() -> void:
	if _hypoxia_active:
		_hypoxia_active = false
		_shrink_t = 0.0
	if _mask != null:
		_apply_mask(false)
	hypoxia_cleared.emit()


## 依激活态配置遮罩（follow_player / 非全黑颜色 / 软度 / 半径）。
func _apply_mask(active: bool) -> void:
	if _mask == null:
		return
	_mask.enabled = active
	_mask.follow_player = true
	_mask.darkness_color = hypoxia_color
	_mask.softness = hypoxia_softness
	if active:
		_mask.radius_inner = hypoxia_radius_inner
		_mask.radius_outer = hypoxia_radius_outer
		if _player != null and is_instance_valid(_player):
			_mask.center_global = _player.global_position


## 长按屏息：达阈值且解锁 → 气泡直接破裂触发缺氧。
func _update_hold(delta: float) -> void:
	if not _hold_pressed:
		return
	if _hypoxia_active:
		return
	_hold_time += delta
	if _hold_time >= hold_burst_delay:
		_hold_reached = true
	var unlocked: bool = GameState.get_process_flag(hold_breath_unlocked_flag)
	if unlocked and _hold_reached and not _hold_burst_done:
		_hold_burst_done = true
		_countdown = breathe_timeout


func _reset_hold() -> void:
	_hold_pressed = false
	_hold_time = 0.0
	_hold_reached = false
	_hold_burst_done = false


## 运行时兜底注册 breathe(空格) 输入动作（D8）。若 project.godot [input] 已定义则跳过。
func _ensure_input() -> void:
	if InputMap.has_action("breathe"):
		return
	InputMap.add_action("breathe")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	InputMap.action_add_event("breathe", ev)


func _resolve_refs() -> void:
	_bubble = _resolve_bubble()
	_mask = _resolve_mask()
	_player = _resolve_player()


func _resolve_bubble() -> Bubble:
	if bubble != NodePath():
		var n := get_node_or_null(bubble)
		if n is Bubble:
			return n as Bubble
	return _find_bubble(self)


func _resolve_mask() -> DarknessMask:
	if darkness_mask != NodePath():
		var n := get_node_or_null(darkness_mask)
		if n is DarknessMask:
			return n as DarknessMask
	return _find_mask(self)


func _resolve_player() -> Node2D:
	if player != NodePath():
		var n := get_node_or_null(player)
		if n is Player:
			return n as Player
	var group_player := get_tree().get_first_node_in_group("player")
	if group_player is Node2D:
		return group_player as Node2D
	return _find_player(self)


func _find_bubble(n: Node) -> Bubble:
	for child in n.get_children():
		if child is Bubble:
			return child as Bubble
		var found := _find_bubble(child)
		if found != null:
			return found
	return null


func _find_mask(n: Node) -> DarknessMask:
	for child in n.get_children():
		if child is DarknessMask:
			return child as DarknessMask
		var found := _find_mask(child)
		if found != null:
			return found
	return null


func _find_player(n: Node) -> Node2D:
	if n == null:
		return null
	if n is Player:
		return n as Player
	for child in n.get_children():
		var found := _find_player(child)
		if found != null:
			return found
	return null


## --self-check：headless 读回计时/缺氧/清除/长按屏息，打印 PASS/FAIL（由宿主场景在 "--self-check" 时调用）。
func run_self_check() -> void:
	var checks: Array[String] = []
	# 1. 初始呼吸状态
	_reset_hold()
	_enabled = true
	breathe()
	checks.append("breath1" if (not _hypoxia_active and _countdown == breathe_timeout) else "breath_FAIL1")
	# 2. 强制缺氧（气泡破裂 + 遮罩激活）
	_break_bubble()
	_start_hypoxia()
	checks.append("hypoxia1" if (_hypoxia_active and _mask != null and _mask.enabled) else "hypoxia_FAIL1")
	# 3. 呼吸解除缺氧
	breathe()
	checks.append("clear1" if (not _hypoxia_active and _countdown == breathe_timeout) else "clear_FAIL1")
	# 4. 长按屏息（解锁后）→ 屏息持续（刷新计时；不再触发缺氧）
	GameState.set_process_flag(hold_breath_unlocked_flag, true)
	_reset_hold()
	_hold_pressed = true
	_countdown = breathe_timeout - 1.0
	_update_hold(hold_burst_delay + 0.1)
	checks.append("hold1" if (_hold_burst_done and not _hypoxia_active and _countdown == breathe_timeout) else "hold_FAIL1")
	# 5. 再呼吸清除
	breathe()
	checks.append("clear2" if (not _hypoxia_active) else "clear_FAIL1")
	GameState.set_process_flag(hold_breath_unlocked_flag, false)

	var failed := false
	for c in checks:
		if c.contains("FAIL"):
			failed = true
		print("[breath] CHECK " + c)
	print("[breath] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
