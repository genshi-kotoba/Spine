class_name CorridorCamera
extends Camera2D
## CorridorCamera — 关卡/走廊相机跟随组件（复用官方 Camera2D limit + smoothing 机制）
##
## 契约三行为：
##  1) 居中跟随：目标横屏居中——滚轴阶段相机 x == 玩家 x（Corridor 把玩家固定在
##     stop_center_x 时，相机随玩家保持屏幕中心）。
##  2) 边缘 clamp：地图边缘触达时相机固定 = 地图边缘与屏幕边缘齐平（官方 limit_* 约束
##     可见矩形：相机 x = map_left + half_width 或 map_right - half_width），角色可继续
##     走到边缘（角色 x 脱离屏幕中心）。
##  3) 平滑参数化：position_smoothing_enabled / position_smoothing_speed / limit_smoothed
##     全部导出，官方机制落地，零手写插值。
##
## 与走廊玩家固定模式共存（不改白模/走廊脚本）：
##  - 监听走廊组（c3corridor）节点信号；默认保持地图 clamp，避免滚轴阶段越过地图边缘。
##    需要真正无限滚轴时才显式关闭 clamp_during_corridor。
##  - 可选旗标联动 auto_flag_switch（GameState process_flag）。
##  - set_mode(MANUAL) 让出相机控制权（如 C3Flow 光影序列），本组件不写位置/limit。
##  - 本组件只操作自身（Camera2D）属性与位置；C3Flow 的 offset 为独立属性，互不冲突。

## —— 模式 ——
enum Mode {
	FOLLOW_CLAMPED, ## 居中跟随 + 地图边缘 clamp（官方 limit_*）
	FOLLOW_ROLLING, ## 无限走廊滚轴：纯跟随不 clamp（Corridor 固定玩家时相机保持居中）
	FRAME_LOCKED, ## 固定在指定构图中心（独立房间展示，不随玩家移动）
	MANUAL,         ## 控制权让出：不写位置/limit（外部接管相机）
}

@export var mode: Mode = Mode.FOLLOW_CLAMPED

## 跟随目标；空 → 父节点 → player 组（关卡场景中 Camera2D 是 Player 子节点）。
@export var follow_target: NodePath = NodePath("")

## 地图世界边界（FOLLOW_CLAMPED 生效；官方 limit 口径=约束可见矩形，地图边缘与屏幕边缘齐平）。
@export var map_left: float = -10000000.0
@export var map_right: float = 10000000.0
@export var map_top: float = -10000000.0
@export var map_bottom: float = 10000000.0

## 平滑参数（官方 position_smoothing / limit_smoothed）。
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 8.0
@export var limit_smooth_enabled: bool = true

## 滚轴阶段是否仍受地图边界约束。C3 固定地图开启；无限地图才关闭。
@export var clamp_during_corridor: bool = true

## 走廊信号联动：滚轴期 ROLLING / 有限化 CLAMPED（组节点无对应信号则跳过）。
@export var corridor_group: String = "c3corridor"

## 旗标自动联动（可选，GameState process_flag）：corridor_entered && !corridor_end → ROLLING。
@export var auto_flag_switch: bool = false
@export var corridor_entered_flag: String = "corridor_entered"
@export var corridor_end_flag: String = "corridor_end"

signal mode_changed(mode: int)

var _target: Node2D = null
var _corridor: Node = null
var _applied_mode: int = -1
var _frame_center_x: float = 0.0


func _ready() -> void:
	add_to_group("corridor_camera")
	make_current()
	_resolve_target()
	_link_corridor_signals()
	apply_configuration()


func _process(_delta: float) -> void:
	if auto_flag_switch and mode != Mode.MANUAL:
		_apply_flag_mode()
	if mode == Mode.MANUAL:
		return
	if mode == Mode.FRAME_LOCKED:
		_apply_frame_center()
		return
	if _target == null or not is_instance_valid(_target):
		_resolve_target()
		if _target == null:
			return
	# f2：仅跟随 x——垂直取景由外部相机 offset（C3Flow CAMERA_FRAME_OFFSET=(0,-336.5)）负责，
	# 本组件不覆写 y（写完整 global_position 会覆盖 offset 依赖的相机基线）。
	if not is_equal_approx(global_position.x, _target.global_position.x):
		global_position.x = _target.global_position.x


## 切换模式并应用官方 limit/smoothing；切换时重置平滑缓冲，避免跨模式滑移。
func set_mode(m: Mode) -> void:
	if mode == m and _applied_mode == int(m):
		return
	mode = m
	apply_configuration()
	mode_changed.emit(m)


## 当前实际模式。
func get_mode() -> Mode:
	return mode


## 应用平滑与 limit 配置（官方机制落地，可重复调用）。
func apply_configuration() -> void:
	if mode == Mode.MANUAL:
		# MANUAL=控制权完全让出：平滑/limit 一并不写（f3：注释口径一致化，_ready 不再写一次平滑参数）。
		_applied_mode = int(mode)
		return
	position_smoothing_enabled = smoothing_enabled
	position_smoothing_speed = smoothing_speed
	limit_smoothed = limit_smooth_enabled
	_apply_limits()
	reset_smoothing()
	_applied_mode = int(mode)


## 设置地图边界（世界坐标）并按当前模式重放 clamp。
func set_map_bounds(left: float, right: float, top: float = -10000000.0, bottom: float = 10000000.0) -> void:
	map_left = left
	map_right = right
	map_top = top
	map_bottom = bottom
	_apply_limits()


## 固定横向构图中心。用于独立房间：玩家可自由移动，但镜头保持完整房间与两侧黑边可见。
func lock_frame_center_x(center_x: float) -> void:
	_frame_center_x = center_x
	set_mode(Mode.FRAME_LOCKED)
	_apply_frame_center()


## Camera2D 是 Player 子节点。锁定时必须写相对父节点的局部偏移，
## 否则 Player 移动会把全局目标重复叠加，造成构图漂移。
func _apply_frame_center() -> void:
	if _target == null or not is_instance_valid(_target):
		_resolve_target()
	if _target != null:
		position.x = _frame_center_x - _target.global_position.x


## 官方 limit 落地：CLAMPED=地图边界；ROLLING=无限（默认极限值）；MANUAL=不触碰。
func _apply_limits() -> void:
	match mode:
		Mode.FOLLOW_CLAMPED:
			limit_left = int(map_left)
			limit_right = int(map_right)
			limit_top = int(map_top)
			limit_bottom = int(map_bottom)
		Mode.FOLLOW_ROLLING:
			limit_left = -10000000
			limit_right = 10000000
			limit_top = -10000000
			limit_bottom = 10000000
		Mode.FRAME_LOCKED:
			limit_left = -10000000
			limit_right = 10000000
			limit_top = -10000000
			limit_bottom = 10000000
		Mode.MANUAL:
			pass


## 走廊信号：切入滚轴；固定地图仍 clamp，角色在可见边缘继续移动。
func _on_corridor_entered() -> void:
	if mode == Mode.MANUAL:
		return
	set_mode(Mode.FOLLOW_CLAMPED if clamp_during_corridor else Mode.FOLLOW_ROLLING)


## 走廊信号：有限化，恢复地图边缘 clamp。
func _on_corridor_finite() -> void:
	if mode == Mode.MANUAL:
		return
	set_mode(Mode.FOLLOW_CLAMPED)


## 旗标联动（auto_flag_switch 开启时）：entered && !end → ROLLING，否则 CLAMPED。
func _apply_flag_mode() -> void:
	var entered: bool = GameState.get_process_flag(corridor_entered_flag)
	var ended: bool = GameState.get_process_flag(corridor_end_flag)
	var desired: Mode = Mode.FOLLOW_ROLLING if (entered and not ended and not clamp_during_corridor) else Mode.FOLLOW_CLAMPED
	if mode != desired:
		set_mode(desired)


## 解析跟随目标：显式路径 → 父节点 → player 组。
func _resolve_target() -> void:
	if follow_target != NodePath():
		var n := get_node_or_null(follow_target)
		if n is Node2D:
			_target = n as Node2D
			return
	var p := get_parent()
	if p is Node2D:
		_target = p as Node2D
		return
	var gp := get_tree().get_first_node_in_group("player")
	if gp is Node2D:
		_target = gp as Node2D


## 连接走廊滚轴信号（信号存在才连；重复连接防护）。
func _link_corridor_signals() -> void:
	_corridor = get_tree().get_first_node_in_group(corridor_group)
	if _corridor == null:
		return
	# f1：字符串信号访问（is_connected/connect）——点访问对 stub/动态节点会属性崩溃；字符串形式安全。
	if _corridor.has_signal("corridor_entered") and not _corridor.is_connected("corridor_entered", Callable(self, "_on_corridor_entered")):
		_corridor.connect("corridor_entered", Callable(self, "_on_corridor_entered"))
	if _corridor.has_signal("corridor_finite") and not _corridor.is_connected("corridor_finite", Callable(self, "_on_corridor_finite")):
		_corridor.connect("corridor_finite", Callable(self, "_on_corridor_finite"))
