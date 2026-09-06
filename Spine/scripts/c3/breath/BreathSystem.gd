class_name BreathSystem
extends Node
## BreathSystem — 呼吸机制组件（C3 gameplay §4）
## 单击 breathe(空格)：启动一次呼吸（重置计时、恢复气泡、清除缺氧）。
## breathe_timeout 内未按 → 气泡破裂 → 触发缺氧（DarknessMask 昏暗透光渐变压暗，5s 后仅角色一圈正常）。
## 长按 breathe ≥ hold_burst_delay（需 hold_breath_unlocked_flag 为真，④ 解锁）→ 屏息持续（刷新呼吸计时）；
## 缺氧只由 breathe_timeout 超时触发，屏息视觉由 Corridor 叠加。
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

## 与屏息共用的镜头摇曳组件。缺氧期间按同一接口驱动，避免重复实现相机偏移。
@export var screen_shake: NodePath = NodePath("../Effects/ScreenShake")

## 气泡未按的计时上限（s）。
@export var breathe_timeout: float = 10.0

## 缺氧渐缩时长（s）。
@export var hypoxia_shrink_duration: float = 5.0

## 缺氧遮罩渐入/渐出时长（s）。遮罩强度使用平滑正弦曲线，避免画面跳变。
@export var hypoxia_enter_duration: float = 0.7
@export var hypoxia_exit_duration: float = 0.7

## 长按屏息解锁旗标名（GameState.process_flags 键）。
@export var hold_breath_unlocked_flag: String = "hold_breath_unlocked"

## 长按屏息判定的时长阈值（s）。与 Corridor.hold_threshold 保持一致。
@export var hold_burst_delay: float = 0.5

## 气泡耗尽爆裂时的一次短促镜头震动（复用 ScreenShake；与缺氧持续跷跷板分层）。
@export var bubble_pop_shake_amplitude: float = 8.0
@export var bubble_pop_shake_duration: float = 0.18

## 缺氧遮罩颜色（非全黑，深蓝黑；用户口径「非全黑」）。
@export var hypoxia_color: Color = Color(0.01, 0.015, 0.035, 0.82) ## 深蓝黑，但保留场景细节。

## 缺氧初始半径（大）。
@export var hypoxia_radius_outer: float = 1200.0
@export var hypoxia_radius_inner: float = 300.0

## 缺氧最终半径（小；5s 后仅角色周围一圈正常）。
@export var hypoxia_radius_final_outer: float = 460.0
@export var hypoxia_radius_final_inner: float = 80.0

## 缺氧边缘软度。
@export var hypoxia_softness: float = 1.0

## 缺氧沿用屏息的阻尼跷跷板镜头；强度随遮罩渐入/渐出而缩放。
@export var hypoxia_rocking_degrees: float = 3.0
@export var hypoxia_rocking_interval: float = 0.42

## 运行时锁定（卧室结局解除呼吸机制）。
var _enabled: bool = true

var _bubble: Bubble = null
var _mask: DarknessMask = null
var _player: Node2D = null
var _screen_shake: ScreenShake = null

## 剩余计时（breathe_timeout 倒计时）。
var _countdown: float = 0.0

## 倒计时倍率与输入锁期间是否继续运行。开场演出使用 2 倍并允许锁定期间消耗。
var _countdown_rate_multiplier: float = 1.0
var _countdown_runs_when_locked: bool = false

## 缺氧进行中。
var _hypoxia_active: bool = false

## 缺氧逻辑已解除、但遮罩仍在平滑淡出。此时走廊屏息层仍须保持关闭。
var _hypoxia_exiting: bool = false
var _hypoxia_enter_t: float = 0.0
var _hypoxia_exit_t: float = 0.0
var _hypoxia_visual_strength: float = 0.0
var _hypoxia_exit_from_strength: float = 0.0

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
		if _countdown_runs_when_locked:
			_advance_countdown(delta)
		elif _hypoxia_exiting:
			_update_hypoxia_exit(delta)
		return
	_sync_breathe_input()
	if _hypoxia_active:
		_update_hypoxia(delta)
		_update_hold(delta)
		return
	if _hypoxia_exiting:
		_update_hypoxia_exit(delta)
		return
	_advance_countdown(delta)
	_update_hold(delta)


## 配置氧气倒计时速度；可选地允许在 StoryMonitor 锁定时继续消耗。
func set_countdown_rate(multiplier: float, run_when_input_locked: bool = false) -> void:
	_countdown_rate_multiplier = maxf(multiplier, 0.0)
	_countdown_runs_when_locked = run_when_input_locked


func _advance_countdown(delta: float) -> void:
	if _hypoxia_active:
		_update_hypoxia(delta)
		return
	if _hypoxia_exiting:
		_update_hypoxia_exit(delta)
		return
	_countdown -= delta * _countdown_rate_multiplier
	_sync_bubble_capacity()
	if _countdown <= 0.0:
		_countdown = 0.0
		_break_bubble()
		_start_hypoxia()


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if StoryMonitor.input_locked:
		return
	if event.is_action_pressed("breathe"):
		_begin_breath_hold()
	elif event.is_action_released("breathe"):
		_end_breath_hold()


## 每帧同步物理按键状态。这样即使某个 UI/节点先消费 InputEvent，缺氧中的长按仍会启动。
func _sync_breathe_input() -> void:
	if Input.is_action_pressed("breathe"):
		if not _hold_pressed:
			_begin_breath_hold()
	elif _hold_pressed:
		_end_breath_hold()


func _begin_breath_hold() -> void:
	if _hold_pressed:
		return
	_hold_pressed = true
	_hold_time = 0.0
	_hold_reached = false
	_hold_burst_done = false


func _end_breath_hold() -> void:
	if not _hold_pressed:
		return
	# 短按（未达长按阈值）→ 一次呼吸；长按不重复呼吸。
	# 缺氧恰在松键前发生时，松键仍可恢复呼吸。
	if not _hold_reached or _hypoxia_active:
		breathe()
	_reset_hold()


## 单击呼吸：重置计时、恢复气泡、清除缺氧。
func breathe(immediate_clear: bool = false) -> void:
	_countdown = breathe_timeout
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.restore()
	_clear_hypoxia(immediate_clear)
	breathed.emit()


## 特异点通过时由 Corridor 调用：结束本次长按，并重新给予完整缺氧倒计时。
## 不触发 breathe 信号或气泡表现，因为这不是一次用户主动呼吸。
func cancel_hold_and_reset_hypoxia_timer() -> void:
	_reset_hold()
	_countdown = breathe_timeout
	_sync_bubble_capacity()


## 开关呼吸机制（卧室结局解除：停止计时/缺氧并恢复气泡）。
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_reset_hold()
		if _hypoxia_active or _hypoxia_exiting:
			_clear_hypoxia(true)
		_countdown = breathe_timeout
		if _bubble != null and is_instance_valid(_bubble):
			_bubble.restore()


## 缺氧是否进行中。
func is_hypoxia_active() -> bool:
	return _hypoxia_active


## 遮罩尚在淡入或淡出时都视为视觉缺氧，用于避免与走廊屏息遮罩叠加。
func is_hypoxia_visual_active() -> bool:
	return _hypoxia_active or _hypoxia_exiting


## 缺氧渐缩进度 0→1。
func get_hypoxia_shrink() -> float:
	return _shrink_t


## 当前倒计时（breathe_timeout - 已流逝；读回/自检）。
func get_countdown() -> float:
	return _countdown


## 屏息的唯一真相来源。达到阈值后会先清除缺氧，再向走廊视觉层公开当前持有状态。
func is_holding_breath() -> bool:
	return _enabled and _hold_pressed and _hold_burst_done \
		and GameState.get_process_flag(hold_breath_unlocked_flag) \
		and not _hypoxia_active and not _hypoxia_exiting


func _break_bubble() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.pop()
	if _screen_shake == null or not is_instance_valid(_screen_shake):
		_screen_shake = _resolve_screen_shake()
	if _screen_shake != null:
		_screen_shake.shake(bubble_pop_shake_amplitude, bubble_pop_shake_duration)
	bubble_broken.emit()


## 以倒计时比例驱动气泡中的液体高度。恢复动画运行时只更新目标容量，不会逐帧打断回填。
func _sync_bubble_capacity() -> void:
	if _bubble == null or not is_instance_valid(_bubble):
		return
	var fraction := clampf(_countdown / maxf(breathe_timeout, 0.001), 0.0, 1.0)
	_bubble.set_countdown_fraction(fraction)


func _start_hypoxia() -> void:
	if _hypoxia_active:
		return
	_hypoxia_active = true
	_hypoxia_exiting = false
	_shrink_t = 0.0
	_hypoxia_enter_t = 0.0
	_hypoxia_exit_t = 0.0
	_hypoxia_visual_strength = 0.0
	if _mask != null:
		_apply_mask(true)
		_set_mask_strength(0.0)
	hypoxia_started.emit()


## 缺氧渐缩：由初始大半径 → 最终小半径，在 hypoxia_shrink_duration 内完成。
func _update_hypoxia(delta: float) -> void:
	_shrink_t = minf(_shrink_t + delta / hypoxia_shrink_duration, 1.0)
	_hypoxia_enter_t = minf(_hypoxia_enter_t + delta / maxf(hypoxia_enter_duration, 0.001), 1.0)
	_hypoxia_visual_strength = _ease_in_out_sine(_hypoxia_enter_t)
	_update_hypoxia_rocking(_hypoxia_visual_strength)
	if _mask == null:
		return
	var radius_t := _ease_in_out_sine(_shrink_t)
	var inner: float = lerpf(hypoxia_radius_inner, hypoxia_radius_final_inner, radius_t)
	var outer: float = lerpf(hypoxia_radius_outer, hypoxia_radius_final_outer, radius_t)
	_mask.radius_inner = inner
	_mask.radius_outer = outer
	_set_mask_strength(_hypoxia_visual_strength)
	if _player != null and is_instance_valid(_player):
		_mask.center_global = _player.global_position


func _clear_hypoxia(immediate: bool = false) -> void:
	var was_active := _hypoxia_active
	_hypoxia_active = false
	_shrink_t = 0.0
	_hypoxia_enter_t = 0.0
	if _mask != null and not immediate and _hypoxia_visual_strength > 0.0:
		_hypoxia_exiting = true
		_hypoxia_exit_t = 0.0
		_hypoxia_exit_from_strength = _hypoxia_visual_strength
	else:
		_finish_hypoxia_exit()
	if was_active:
		hypoxia_cleared.emit()


func _update_hypoxia_exit(delta: float) -> void:
	_hypoxia_exit_t = minf(_hypoxia_exit_t + delta / maxf(hypoxia_exit_duration, 0.001), 1.0)
	_hypoxia_visual_strength = _hypoxia_exit_from_strength * (1.0 - _ease_in_out_sine(_hypoxia_exit_t))
	_set_mask_strength(_hypoxia_visual_strength)
	_update_hypoxia_rocking(_hypoxia_visual_strength)
	if _hypoxia_exit_t >= 1.0:
		_finish_hypoxia_exit()


func _finish_hypoxia_exit() -> void:
	_hypoxia_exiting = false
	_hypoxia_exit_t = 0.0
	_hypoxia_exit_from_strength = 0.0
	_hypoxia_visual_strength = 0.0
	_set_hypoxia_rocking(false)
	if _mask != null:
		_set_mask_strength(0.0)
		_apply_mask(false)


func _ease_in_out_sine(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return 0.5 - cos(t * PI) * 0.5


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


func _set_mask_strength(strength: float) -> void:
	if _mask != null:
		_mask.intensity = clampf(strength, 0.0, 1.0)


## 缺氧镜头只围绕相机中心倾斜，不施加横向位移；目标侧左右交替、力度随机。
func _update_hypoxia_rocking(strength: float) -> void:
	_set_hypoxia_rocking(strength > 0.001, hypoxia_rocking_degrees * clampf(strength, 0.0, 1.0))


func _set_hypoxia_rocking(active: bool, degrees: float = 0.0) -> void:
	if _screen_shake == null or not is_instance_valid(_screen_shake):
		_screen_shake = _resolve_screen_shake()
	if _screen_shake != null:
		_screen_shake.set_rocking(active, degrees, hypoxia_rocking_interval)


## 长按屏息：达阈值且解锁 → 刷新呼吸计时；屏息视觉由 Corridor 负责。
func _update_hold(delta: float) -> void:
	if not _hold_pressed:
		return
	_hold_time += delta
	if _hold_time >= hold_burst_delay:
		_hold_reached = true
	var unlocked: bool = GameState.get_process_flag(hold_breath_unlocked_flag)
	if unlocked and _hold_reached:
		# 屏息在缺氧中同样有效：立即移除缺氧层，长按不必等松键才恢复控制。
		if _hypoxia_active or _hypoxia_exiting:
			breathe(true)
		# 屏息持续期间保持气泡计时刷新，长按不会因超过 breathe_timeout 再次触发缺氧。
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
	_screen_shake = _resolve_screen_shake()


func _resolve_screen_shake() -> ScreenShake:
	if screen_shake != NodePath():
		var n := get_node_or_null(screen_shake)
		if n is ScreenShake:
			return n as ScreenShake
	return null


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
func run_self_check() -> bool:
	var checks: Array[String] = []
	# 1. 初始呼吸状态
	_reset_hold()
	_enabled = true
	breathe()
	checks.append("breath1" if (not _hypoxia_active and _countdown == breathe_timeout) else "breath_FAIL1")
	# 气泡液体必须直接反映可用呼吸时间；恢复后应再次满载。
	var liquid_capacity_ok := false
	var bubble_inertia_ok := false
	var bubble_recovery_ok := false
	if _bubble != null:
		_bubble.set_liquid_fraction(0.42)
		liquid_capacity_ok = is_equal_approx(_bubble.get_liquid_fraction(), 0.42)
		if _player != null:
			var expected_follow_x := _player.global_position.x + _bubble.follow_offset.x
			_bubble.global_position = Vector2(expected_follow_x - 48.0, _player.global_position.y + _bubble.follow_offset.y)
			_bubble._process(0.05)
			bubble_inertia_ok = _bubble.get_follow_velocity().x > 0.0 and _bubble.global_position.x < expected_follow_x
		_bubble.restore()
		_bubble.set_countdown_fraction(1.0)
		_bubble._process(_bubble.restore_anim_time * 0.5)
		var mid_recovery := _bubble.is_recovering() and _bubble.get_liquid_fraction() > 0.42 and _bubble.get_liquid_fraction() < 1.0
		_bubble._process(_bubble.restore_anim_time)
		bubble_recovery_ok = mid_recovery and not _bubble.is_recovering() and is_equal_approx(_bubble.get_liquid_fraction(), 1.0) and _bubble.scale.distance_to(Vector2.ONE) <= 0.01
	checks.append("bubble_liquid1" if liquid_capacity_ok else "bubble_liquid_FAIL1")
	checks.append("bubble_inertia1" if bubble_inertia_ok else "bubble_inertia_FAIL1")
	checks.append("bubble_recovery1" if bubble_recovery_ok else "bubble_recovery_FAIL1")
	# 2. 强制缺氧（气泡破裂 + 遮罩激活）
	_break_bubble()
	var bubble_pop_ok := _bubble != null and _bubble.is_popping()
	var bubble_pop_shake_ok := _screen_shake != null and is_equal_approx(_screen_shake.duration, bubble_pop_shake_duration)
	checks.append("bubble_pop1" if bubble_pop_ok else "bubble_pop_FAIL1")
	checks.append("bubble_pop_shake1" if bubble_pop_shake_ok else "bubble_pop_shake_FAIL1")
	_start_hypoxia()
	checks.append("hypoxia1" if (_hypoxia_active and _mask != null and _mask.enabled) else "hypoxia_FAIL1")
	_update_hypoxia(hypoxia_enter_duration * 0.5)
	var entered_strength := _hypoxia_visual_strength
	checks.append("fade_in1" if (entered_strength > 0.0 and entered_strength < 1.0) else "fade_in_FAIL1")
	var hypoxia_shake := get_node_or_null("../Effects/ScreenShake") as ScreenShake
	checks.append("hypoxia_rocking1" if hypoxia_shake != null and hypoxia_shake.is_rocking() and not is_zero_approx(hypoxia_shake.get_rocking_target()) else "hypoxia_rocking_FAIL1")
	# 独立实例覆盖“首次 set_sway()”的初始基准，避免先前的走廊自检污染组件状态。
	var framing_camera := Camera2D.new()
	var framing_base := Vector2(0.0, -336.5)
	framing_camera.offset = framing_base
	var first_sway_shake := ScreenShake.new()
	first_sway_shake._camera = framing_camera
	var first_sway := Vector2(1.0, -1.0)
	first_sway_shake.set_sway(first_sway)
	var framing_preserved := framing_camera.offset.distance_to(framing_base + first_sway) <= 0.01
	checks.append("hypoxia_frame1" if framing_preserved else "hypoxia_frame_FAIL1")
	var supports_rocking := first_sway_shake.has_method("set_rocking") and first_sway_shake.has_method("get_sway_rotation") and first_sway_shake.has_method("get_rocking_target")
	if supports_rocking:
		first_sway_shake.call("set_rocking", true, 1.1, 0.01)
		first_sway_shake._process(0.2)
	var rocking_applied := supports_rocking and not is_zero_approx(float(first_sway_shake.call("get_rocking_target"))) and not is_zero_approx(framing_camera.rotation) and not is_zero_approx(float(first_sway_shake.call("get_rocking_angular_velocity")))
	checks.append("hypoxia_rocking1" if rocking_applied else "hypoxia_rocking_FAIL1")
	first_sway_shake.free()
	framing_camera.free()
	# 3. 呼吸解除缺氧，遮罩应平滑淡出而非直接消失。
	breathe()
	checks.append("clear1" if (not _hypoxia_active and _hypoxia_exiting and _countdown == breathe_timeout) else "clear_FAIL1")
	_update_hypoxia_exit(hypoxia_exit_duration * 0.5)
	checks.append("fade_out1" if (_hypoxia_visual_strength > 0.0 and _hypoxia_visual_strength < entered_strength) else "fade_out_FAIL1")
	_update_hypoxia_exit(hypoxia_exit_duration)
	checks.append("fade_out2" if (not _hypoxia_exiting and _mask != null and not _mask.enabled) else "fade_out_FAIL2")
	# 4. 已经缺氧时长按仍必须立即进入屏息，并清除缺氧视觉。
	GameState.set_process_flag(hold_breath_unlocked_flag, true)
	_reset_hold()
	_start_hypoxia()
	_hold_pressed = true
	_update_hold(hold_burst_delay + 0.1)
	checks.append("hypoxia_hold1" if (_hold_burst_done and _hold_reached and not _hypoxia_active and not _hypoxia_exiting and _countdown == breathe_timeout) else "hypoxia_hold_FAIL1")
	var hold_priority_visible := has_method("is_holding_breath") and bool(call("is_holding_breath"))
	checks.append("hypoxia_hold_priority" if hold_priority_visible else "hypoxia_hold_priority_FAIL")
	# 4b. 真实 Input 状态路径：即使 _unhandled_input 被别的节点消费，每帧同步也必须在缺氧中完成屏息切换。
	_reset_hold()
	_start_hypoxia()
	Input.action_press("breathe")
	_process(hold_burst_delay + 0.1)
	var physical_hold_priority := not _hypoxia_active and not _hypoxia_exiting and is_holding_breath()
	Input.action_release("breathe")
	_process(0.0)
	checks.append("hypoxia_hold_input" if physical_hold_priority else "hypoxia_hold_input_FAIL")
	# 5. 正常长按屏息持续期间也应刷新计时且不触发缺氧。
	_reset_hold()
	_hold_pressed = true
	_countdown = breathe_timeout - 1.0
	_update_hold(hold_burst_delay + 0.1)
	checks.append("hold1" if (_hold_burst_done and not _hypoxia_active and _countdown == breathe_timeout) else "hold_FAIL1")
	checks.append("threshold1" if is_equal_approx(hold_burst_delay, 0.5) else "threshold_FAIL1")
	# 6. 特异点成功后的重置 API 必须同时终止 BreathSystem 的持有状态与计时。
	cancel_hold_and_reset_hypoxia_timer()
	checks.append("special_reset1" if (not _hold_pressed and is_zero_approx(_hold_time) and _countdown == breathe_timeout) else "special_reset_FAIL1")
	GameState.set_process_flag(hold_breath_unlocked_flag, false)

	var failed := false
	for c in checks:
		if c.contains("FAIL"):
			failed = true
		print("[breath] CHECK " + c)
	print("[breath] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	return not failed
