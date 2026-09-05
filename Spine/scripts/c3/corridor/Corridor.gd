class_name Corridor
extends Node2D
## Corridor — C3 固定长度走廊（光影后从书房门直接接出；无限循环机制废弃）
## 职责：走廊进入检测、固定坐标特异点屏息判定（通过/失败传送至第一特异点前 1/4）、尽头检测。
## 玩家正常移动（不 pin、不移动墙）；视觉为场景固定节点（CorridorWall/CorridorFloorVisual 7680 宽）。
## 屏息视觉（用户定案）：长按 breathe ≥ hold_threshold(0.5s) → 持续昏暗脉冲 + 随机跷跷板镜头；未屏息回传 → 红色粒子震撼。

## —— 信号（供 C3Flow 接线）——
signal corridor_entered                ## 玩家进入走廊起点。
signal special_point_passed(index: int) ## 屏息通过第 index 个特异点。
signal teleport_triggered              ## 未屏息 → 传送到第一特异点前 1/4。
signal corridor_finite                 ## 走到走廊尽头判定（固定走廊=到达 end_wall_x）。
signal end_wall_reached                ## 玩家到达尽头。

## —— 节点 ——
@export var player: NodePath
## 呼吸系统引用；缺氧时关闭走廊屏息层，避免两层压暗叠加。
@export var breath_system_path: NodePath = NodePath("../Breath")
## C3 场景共享的镜头特效。屏息、缺氧和短震必须写入同一实例，避免相机旋转竞争。
@export var screen_shake_path: NodePath = NodePath("../Effects/ScreenShake")

## —— 几何/节奏参数（固定走廊）——
@export var corridor_start_x: float = 1280.0   ## 书房门后的走廊起点（世界 x）。
@export var end_wall_x: float = 4480.0         ## 走廊尽头交互判定 x（物理端墙在 4600）。
@export var special_x: Array[float] = [2080.0, 2880.0, 3680.0] ## 三特异点固定世界 x；每段 800px。
@export var first_special_x: float = 2080.0     ## 第一个特异点 x。
@export var special_span: float = 800.0         ## 特异点的统一间距。
@export var teleport_back_distance: float = 480.0 ## 失败回传距离，保持玩家仍在走廊内。

## —— 屏息 / 旗标 ——
@export var hold_breath_unlocked_flag: String = "hold_breath_unlocked"
@export var corridor_entered_flag: String = "corridor_entered"
@export var corridor_end_flag: String = "corridor_end"
@export var hold_threshold: float = 0.5     ## 屏息判定：长按 0.5s（用户定案）
@export var enabled: bool = true

## —— 屏息视觉（长按 0.5s → 持续昏暗脉冲 + 角色身边粒子震动）——
@export var breath_dim_color: Color = Color(0.02, 0.03, 0.09, 0.5)
@export var breath_fx_enabled: bool = true
@export var hold_pulse_alpha: float = 0.42
@export var hold_pulse_alpha_amplitude: float = 0.06
@export var hold_pulse_frequency: float = 0.22
@export var hold_rocking_degrees: float = 3.0
@export var hold_rocking_interval: float = 0.42
@export var special_pass_shake_amplitude: float = 22.0
@export var special_pass_shake_duration: float = 0.45

const MODE_IDLE := 0
const MODE_CORRIDOR := 1
const MODE_FINITE := 2
const MODE_DONE := 3

var _mode: int = MODE_IDLE
var _player: Node2D = null
var _breath_system: Node = null
var _next_special: int = 0
## 上一帧玩家 x；特异点只在跨越阈值的帧判定，避免同侧连续帧重复触发。
var _last_player_x: float = NAN
var _hold_time: float = 0.0
## 特异点通过后必须先松键才允许开始下一次屏息，不能因为物理键仍按住立即续上。
var _hold_release_required: bool = false
var _special_pass_shake_count: int = 0
var _breath_active: bool = false
var _hold_fx_elapsed: float = 0.0
var _breath_dim_layer: CanvasLayer = null
var _breath_dim_rect: ColorRect = null
var _breath_burst: ParticleBurst = null
var _teleport_burst: ParticleBurst = null
var _breath_shake: ScreenShake = null
var _hold_rocking_active := false


func _ready() -> void:
	add_to_group("c3corridor")
	_resolve_refs()
	_resolve_breath_system()
	_ensure_input()
	if "--corridor-breath-self-check" in OS.get_cmdline_user_args():
		_run_corridor_breath_self_check.call_deferred()


func _process(delta: float) -> void:
	if not enabled:
		_hold_time = 0.0
		_set_breath_fx(false)
		_reset_hold_visual()
		return
	if StoryMonitor.input_locked:
		_hold_time = 0.0
		_set_breath_fx(false)
		_reset_hold_visual()
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
	if not Input.is_action_pressed("breathe"):
		_hold_time = 0.0
		_hold_release_required = false
	elif not _hold_release_required:
		_hold_time += delta
	else:
		_hold_time = 0.0
	var corridor_hold := is_holding_breath() and (_mode == MODE_CORRIDOR or _mode == MODE_FINITE)
	_set_breath_fx(corridor_hold and not _is_hypoxia_visual_active())
	_update_hold_visual(corridor_hold and not _is_hypoxia_visual_active(), delta)


## 是否处于屏息态（长按 ≥ hold_threshold 且解锁）。
func is_holding_breath() -> bool:
	# BreathSystem 先处理缺氧取消，作为输入与优先级的唯一来源；本地计时仅是独立组件的兜底。
	if _breath_system == null or not is_instance_valid(_breath_system):
		_resolve_breath_system()
	if _breath_system != null and _breath_system.has_method("is_holding_breath"):
		return bool(_breath_system.call("is_holding_breath"))
	if not GameState.get_process_flag(hold_breath_unlocked_flag):
		return false
	return not _hold_release_required and not _is_hypoxia_visual_active() and _hold_time >= hold_threshold


func _enter_corridor() -> void:
	_mode = MODE_CORRIDOR
	_next_special = 0
	# 从走廊起点开始记边沿，这样首次跨越固定坐标时才触发判定。
	_last_player_x = corridor_start_x
	GameState.set_process_flag(corridor_entered_flag, true)
	corridor_entered.emit()


## 特异点判定：仅在上一帧与当前帧跨越固定 x 时判定。
## 正反方向都可重复经过；未屏息仍传送回第一特异点前 1/4。
func _check_specials() -> void:
	if _player == null or special_x.is_empty():
		return
	var current_x: float = _player.global_position.x
	if is_nan(_last_player_x):
		_last_player_x = current_x
		return
	var previous_x: float = _last_player_x
	if is_equal_approx(previous_x, current_x):
		return

	if current_x > previous_x:
		# 正向跨越时按特异点顺序处理，保留一次跨过多个点的旧行为。
		for i in range(special_x.size()):
			var sx_forward: float = special_x[i]
			if previous_x < sx_forward and current_x >= sx_forward:
				if not _handle_special_crossing(i):
					return
	else:
		# 回头跨越时反向处理，保证每个点都有独立的 crossing 边沿。
		for i in range(special_x.size() - 1, -1, -1):
			var sx_backward: float = special_x[i]
			if current_x < sx_backward and previous_x >= sx_backward:
				if not _handle_special_crossing(i):
					return
	_last_player_x = current_x


func _handle_special_crossing(index: int) -> bool:
	if is_holding_breath():
		special_point_passed.emit(index)
		_trigger_special_pass_shake()
		_cancel_hold_after_special()
		# _next_special 保留给流程/自检读回；重复经过已完成点不回退进度。
		if index >= _next_special:
			_next_special = index + 1
		return true
	_teleport_back()
	return false


## 成功穿过特异点后，Corridor 与 BreathSystem 都结束当前屏息并从完整呼吸计时重新开始。
func _cancel_hold_after_special() -> void:
	_hold_time = 0.0
	_hold_release_required = true
	_set_breath_fx(false)
	_reset_hold_visual()
	if _breath_system == null or not is_instance_valid(_breath_system):
		_resolve_breath_system()
	if _breath_system != null and _breath_system.has_method("cancel_hold_and_reset_hypoxia_timer"):
		_breath_system.call("cancel_hold_and_reset_hypoxia_timer")


func _trigger_special_pass_shake() -> void:
	_special_pass_shake_count += 1
	_trigger_shake(special_pass_shake_amplitude, special_pass_shake_duration)


func _teleport_back() -> void:
	_player.global_position.x = first_special_x - teleport_back_distance
	_next_special = 0
	_last_player_x = _player.global_position.x
	teleport_triggered.emit()
	_run_teleport_fx()


## 屏息视觉开关：长按达阈值 → 全屏昏暗 + 角色粒子 + 震动；松开/锁输入 → 恢复。
func _set_breath_fx(active: bool) -> void:
	if active == _breath_active:
		return
	_breath_active = active
	if not breath_fx_enabled:
		return
	if active:
		_ensure_breath_dim()
		if _breath_dim_rect != null:
			_breath_dim_rect.visible = true
		_spawn_player_burst(Color(0.7, 0.8, 1.0, 1))
		_trigger_shake(18.0, 0.5)
	elif _breath_dim_rect != null:
		_breath_dim_rect.visible = false


## 屏息进行时只在深色范围内慢速呼吸：最亮时仍有遮罩，不会恢复到正常亮度。
func _update_hold_visual(active: bool, delta: float) -> void:
	if not active:
		_reset_hold_visual()
		return
	_hold_fx_elapsed += delta
	if _breath_dim_rect != null:
		var dim_color := breath_dim_color
		var pulse := sin(_hold_fx_elapsed * hold_pulse_frequency * TAU) * hold_pulse_alpha_amplitude
		dim_color.a = clampf(hold_pulse_alpha + pulse, hold_pulse_alpha - hold_pulse_alpha_amplitude, hold_pulse_alpha + hold_pulse_alpha_amplitude)
		_breath_dim_rect.color = dim_color
	if _breath_shake != null and is_instance_valid(_breath_shake):
		if not _hold_rocking_active:
			_breath_shake.set_rocking(true, hold_rocking_degrees, hold_rocking_interval)
			_hold_rocking_active = true


func _reset_hold_visual() -> void:
	_hold_fx_elapsed = 0.0
	if _breath_dim_rect != null:
		_breath_dim_rect.color = breath_dim_color
	if _hold_rocking_active and _breath_shake != null and is_instance_valid(_breath_shake):
		_breath_shake.set_rocking(false)
	_hold_rocking_active = false


## 全屏昏暗层（半透明深蓝黑，昏暗有透光；动态创建一次复用）。
func _ensure_breath_dim() -> void:
	if _breath_dim_layer != null and is_instance_valid(_breath_dim_layer):
		return
	_breath_dim_layer = CanvasLayer.new()
	_breath_dim_layer.name = "BreathDimLayer"
	_breath_dim_layer.layer = 95
	add_child(_breath_dim_layer)
	_breath_dim_rect = ColorRect.new()
	_breath_dim_rect.name = "BreathDim"
	_breath_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breath_dim_rect.color = breath_dim_color
	_breath_dim_rect.visible = false
	_breath_dim_layer.add_child(_breath_dim_rect)
	_breath_dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 角色身边粒子爆炸（缓存复用；粒子随玩家移动）。
func _spawn_player_burst(burst_color: Color) -> void:
	var p := _get_player()
	if p == null:
		return
	if _breath_burst == null or not is_instance_valid(_breath_burst):
		_breath_burst = ParticleBurst.new()
		_breath_burst.name = "BreathBurst"
		_breath_burst.amount = 40
		_breath_burst.lifetime = 0.7
		_breath_burst.initial_velocity = 280.0
		_breath_burst.gravity = 300.0
		_breath_burst.size = 5.0
		p.add_child(_breath_burst)
	elif _breath_burst.get_parent() != p:
		_breath_burst.reparent(p, false)
	_breath_burst.set_color(burst_color)
	_breath_burst.burst()


## 回传震撼（未屏息被传送）：红色粒子爆炸 + 强震动标明「被传送回去」。
func _run_teleport_fx() -> void:
	if not breath_fx_enabled:
		return
	var p := _get_player()
	if p != null:
		if _teleport_burst == null or not is_instance_valid(_teleport_burst):
			_teleport_burst = ParticleBurst.new()
			_teleport_burst.name = "TeleportBurst"
			_teleport_burst.amount = 70
			_teleport_burst.lifetime = 1.0
			_teleport_burst.initial_velocity = 420.0
			_teleport_burst.gravity = 260.0
			_teleport_burst.size = 7.0
			p.add_child(_teleport_burst)
		elif _teleport_burst.get_parent() != p:
			_teleport_burst.reparent(p, false)
		_teleport_burst.set_color(Color(1.0, 0.35, 0.25, 1))
		_teleport_burst.burst()
	_trigger_shake(30.0, 0.8)


## 全屏震动复用 C3 场景共享的 ScreenShake，不能为同一台相机创建第二个旋转写入者。
func _trigger_shake(amp: float, dur: float) -> void:
	if _breath_shake == null or not is_instance_valid(_breath_shake):
		_breath_shake = _resolve_screen_shake()
	if _breath_shake != null:
		_breath_shake.shake(amp, dur)


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
	_breath_shake = _resolve_screen_shake()


func _resolve_screen_shake() -> ScreenShake:
	if screen_shake_path != NodePath():
		var node := get_node_or_null(screen_shake_path)
		if node is ScreenShake:
			return node as ScreenShake
	return null


func _resolve_breath_system() -> void:
	if breath_system_path != NodePath():
		_breath_system = get_node_or_null(breath_system_path)
	if _breath_system == null:
		_breath_system = get_tree().get_first_node_in_group("breath_system")


func _is_hypoxia_visual_active() -> bool:
	if _breath_system == null or not is_instance_valid(_breath_system):
		_resolve_breath_system()
	if _breath_system == null:
		return false
	if _breath_system.has_method("is_hypoxia_visual_active"):
		return bool(_breath_system.call("is_hypoxia_visual_active"))
	return _breath_system.has_method("is_hypoxia_active") and bool(_breath_system.call("is_hypoxia_active"))


func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_resolve_refs()
	return _player


## 开关走廊判定（供 C3Flow/流程控制；false → 不检测）。
func set_enabled(enabled_value: bool) -> void:
	enabled = enabled_value
	if not enabled:
		_hold_time = 0.0
		_hold_release_required = false
		_set_breath_fx(false)
		_reset_hold_visual()


func _run_corridor_breath_self_check() -> void:
	var corridor_ok := run_self_check()
	var breath_ok := _breath_system != null and _breath_system.has_method("run_self_check") and bool(_breath_system.call("run_self_check"))
	print("[corridor_breath] SELF-CHECK " + ("PASS" if corridor_ok and breath_ok else "FAIL"))
	get_tree().quit(0 if corridor_ok and breath_ok else 1)


# ─── 自检（--self-check；验证进入 / 特异点屏息通过与失败传送 / 尽头）───

func run_self_check() -> bool:
	var checks: Array[String] = []
	enabled = true
	var p := _get_player()
	if p == null:
		print("[corridor] SELF-CHECK FAIL (no player)")
		return false
	# 1. 进入走廊（直接调用判定，避免自检依赖真实键盘和帧序）。
	_mode = MODE_IDLE
	p.global_position.x = corridor_start_x + 10.0
	_enter_corridor()
	checks.append("enter1" if _mode == MODE_CORRIDOR and GameState.get_process_flag(corridor_entered_flag) else "enter_FAIL1")
	# 2. 未屏息过第一特异点 → 传送
	_hold_time = 0.0
	GameState.set_process_flag(hold_breath_unlocked_flag, false)
	p.global_position.x = first_special_x + 10.0
	_check_specials()
	checks.append("teleport1" if (absf(p.global_position.x - (first_special_x - teleport_back_distance)) < 0.5 and _next_special == 0) else "teleport_FAIL1")
	# 3. 屏息通过三特异点
	GameState.set_process_flag(hold_breath_unlocked_flag, true)
	_hold_release_required = false
	_hold_time = hold_threshold + 0.1
	_prime_breath_hold_for_self_check()
	_next_special = 0
	var shakes_before_pass := _special_pass_shake_count
	p.global_position.x = first_special_x + 10.0
	_check_specials()
	var breath_timer_reset := _breath_system != null and _breath_system.has_method("get_countdown") and is_equal_approx(float(_breath_system.call("get_countdown")), float(_breath_system.get("breathe_timeout")))
	checks.append("pass1" if (_next_special == 1 and _hold_release_required and is_zero_approx(_hold_time) and breath_timer_reset and _special_pass_shake_count == shakes_before_pass + 1) else "pass_FAIL1")
	# 模拟松键，第二次屏息必须重新累计完整 1 秒阈值。
	_hold_release_required = false
	_hold_time = hold_threshold + 0.1
	_prime_breath_hold_for_self_check()
	p.global_position.x = special_x[1] + 10.0
	_check_specials()
	checks.append("pass2" if _next_special == 2 else "pass_FAIL2")
	_hold_release_required = false
	_hold_time = hold_threshold + 0.1
	_prime_breath_hold_for_self_check()
	p.global_position.x = special_x[2] + 10.0
	_check_specials()
	checks.append("pass3" if _next_special == 3 else "pass_FAIL3")
	var spacing_ok := special_x.size() == 3 and is_equal_approx(special_x[1] - special_x[0], special_span) and is_equal_approx(special_x[2] - special_x[1], special_span)
	var entry_ok := special_x.size() == 3 and first_special_x - corridor_start_x >= 0.0 and first_special_x - corridor_start_x <= 1000.0
	var endpoint_ok := special_x.size() == 3 and end_wall_x - special_x[2] >= 0.0 and end_wall_x - special_x[2] <= 800.0
	checks.append("spacing1" if spacing_ok else "spacing_FAIL1")
	checks.append("entry1" if entry_ok else "entry_FAIL1")
	checks.append("endpoint1" if endpoint_ok else "endpoint_FAIL1")
	checks.append("threshold1" if is_equal_approx(hold_threshold, 0.5) else "threshold_FAIL1")
	# 持续屏息必须进入随机跷跷板状态，且透明度始终保留压暗而不回到正常亮度。
	_hold_release_required = false
	_hold_time = hold_threshold + 0.1
	_prime_breath_hold_for_self_check()
	_set_breath_fx(true)
	_update_hold_visual(true, 0.25)
	var rocking_forwarded := _breath_shake != null and _breath_shake.has_method("is_rocking") \
		and _breath_shake.is_rocking() and not is_zero_approx(_breath_shake.get_rocking_target())
	var pulse_ok := _breath_dim_rect != null and _breath_dim_rect.visible and _breath_dim_rect.color.a > 0.0 and _breath_dim_rect.color.a < 1.0 and rocking_forwarded
	checks.append("hold_visual1" if pulse_ok else "hold_visual_FAIL1")
	_set_breath_fx(false)
	_reset_hold_visual()
	# 缺氧遮罩可见时，Corridor 的屏息态和全屏 dim 都必须关闭，避免两层压暗叠加。
	var no_stack_ok := false
	if _breath_system != null and _breath_system.has_method("_start_hypoxia") and _breath_system.has_method("_clear_hypoxia"):
		_breath_system.call("_start_hypoxia")
		if _breath_system.has_method("_update_hypoxia"):
			_breath_system.call("_update_hypoxia", float(_breath_system.get("hypoxia_enter_duration")))
		_hold_release_required = false
		_hold_time = hold_threshold + 0.1
		_set_breath_fx(is_holding_breath() and (_mode == MODE_CORRIDOR or _mode == MODE_FINITE))
		no_stack_ok = not is_holding_breath() and not _breath_active
		_breath_system.call("_clear_hypoxia", true)
	checks.append("no_stack1" if no_stack_ok else "no_stack_FAIL1")
	# 4. 走到尽头 → finite
	p.global_position.x = end_wall_x + 10.0
	_enter_finite()
	checks.append("finite1" if (GameState.get_process_flag(corridor_end_flag) and _mode == MODE_FINITE) else "finite_FAIL1")
	GameState.set_process_flag(hold_breath_unlocked_flag, false)
	var failed := false
	for c in checks:
		if c.contains("FAIL"):
			failed = true
		print("[corridor] CHECK " + c)
	print("[corridor] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	return not failed


## 自检直接驱动 BreathSystem 的公开判定链，避免旧的 Corridor 局部计时误报“屏息已激活”。
func _prime_breath_hold_for_self_check() -> void:
	if _breath_system == null or not _breath_system.has_method("_update_hold"):
		return
	_breath_system.set("_hold_pressed", true)
	_breath_system.set("_hold_time", hold_threshold + 0.1)
	_breath_system.call("_update_hold", 0.0)
