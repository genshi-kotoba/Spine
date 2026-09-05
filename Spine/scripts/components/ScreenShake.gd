class_name ScreenShake
extends Node2D
## ScreenShake — 全屏撼动组件（C3 前置需求④）
## 驱动宿主 Camera2D 的瞬时 offset 撼动，并可叠加以相机中心为支点的随机倾斜。
## 触发：screen_shake.shake(amp, dur)。可挂到 Camera2D 子节点（默认取父为相机）或经 camera_path 指定。
## 无房间/关卡字面量，可复用。

## 振幅（px）。
@export var amplitude: float = 20.0
## 频率（次/秒；越大越抖）。
@export var frequency: float = 40.0
## 时长（秒）。
@export var duration: float = 0.4
## 衰减系数（越大回位越快）。
@export var attenuation: float = 3.0

## 可选：直接用 NodePath 指定相机（独立挂载时用；默认取父节点为相机）。
@export var camera_path: NodePath

var _camera: Camera2D = null
var _base_offset: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _shaking: bool = false
var _amp: float = 0.0
var _remaining: float = 0.0
var _active_duration: float = 0.0
var _acc: float = 0.0
var _sway_offset: Vector2 = Vector2.ZERO
var _sway_rotation: float = 0.0
## 常驻跷跷板状态：每个节拍随机力度、左右交替的目标角度，不使用镜头横向位移。
var _rocking_enabled: bool = false
var _rocking_target: float = 0.0
var _rocking_rotation: float = 0.0
var _rocking_max_rotation: float = 0.0
var _rocking_interval: float = 0.28
var _rocking_timer: float = 0.0
var _rocking_direction: int = 0


func _ready() -> void:
	_resolve_camera()


func _resolve_camera() -> void:
	if camera_path != NodePath():
		var node := get_node_or_null(camera_path)
		if node is Camera2D:
			_camera = node as Camera2D
			return
	var parent := get_parent()
	if parent is Camera2D:
		_camera = parent as Camera2D


func _process(delta: float) -> void:
	if not _shaking and not _rocking_enabled:
		return
	if _camera == null:
		_shaking = false
		_rocking_enabled = false
		return
	if _rocking_enabled:
		_update_rocking(delta)
	if not _shaking:
		_camera.offset = _base_offset + _sway_offset
		return
	_acc += delta
	_remaining -= delta
	if _remaining <= 0.0 or _active_duration <= 0.0:
		_end_shake()
		return
	# attenuation 参与衰减曲线：剩余时长比例 ^ attenuation（越大回位越快；1=线性，2=二次加速回位）
	var ratio: float = clampf(_remaining / _active_duration, 0.0, 1.0)
	var falloff: float = pow(ratio, attenuation)
	var amp_now := _amp * falloff
	# frequency 参与抖动步进：正弦主波(按 frequency) + 均匀随机分量混合（兼具规律与随机）
	var wave_x: float = sin(_acc * frequency * TAU)
	var wave_y: float = cos(_acc * frequency * TAU)
	var ox := (wave_x * 0.5 + (randf() * 2.0 - 1.0) * 0.5) * amp_now
	var oy := (wave_y * 0.5 + (randf() * 2.0 - 1.0) * 0.5) * amp_now
	_camera.offset = _base_offset + _sway_offset + Vector2(ox, oy)


## 长时轻微摇曳可与短时震动共存；震动结束后仍保留当前摇曳偏移。
func set_sway(offset: Vector2) -> void:
	if _camera == null:
		_resolve_camera()
	if _camera != null and not _shaking:
		# 首次摇曳前可能已有外部构图偏移（如 C3 的 2.35:1 纵向取景）。
		# 从实时偏移扣除上一帧摇曳，保留该基准而非回退到 Vector2.ZERO。
		_base_offset = _camera.offset - _sway_offset
	_sway_offset = offset
	if _camera != null and not _shaking:
		_camera.offset = _base_offset + _sway_offset


## 固定构图层可显式声明相机基准，持续摇曳只在该基准上叠加。
func set_base_offset(offset: Vector2) -> void:
	if _camera == null:
		_resolve_camera()
	_base_offset = offset
	if _camera != null and not _shaking:
		_camera.offset = _base_offset + _sway_offset


func get_base_offset() -> Vector2:
	return _base_offset


## 兼容旧调用的显式旋转层。新的屏息/缺氧请使用 set_rocking()，让方向与力度自然变化。
func set_sway_rotation(angle: float) -> void:
	if _camera == null:
		_resolve_camera()
	if _camera != null:
		_base_rotation = _camera.rotation - _sway_rotation - _rocking_rotation
	_sway_rotation = angle
	_apply_camera_rotation()


func get_sway_rotation() -> float:
	return _sway_rotation + _rocking_rotation


func get_sway_offset() -> Vector2:
	return _sway_offset


## 开关持续的跷跷板镜头。角度围绕 Camera2D 中心旋转，目标侧每一拍交替、力度随机。
## 这是状态接口：可逐帧更新 max_degrees，而不会每帧重置当前摆动。
func set_rocking(active: bool, max_degrees: float = 1.8, interval: float = 0.28) -> void:
	if _camera == null:
		_resolve_camera()
	if _camera == null:
		return
	# Camera2D 默认 ignore_rotation=true，只会存储 rotation 而不会转动画面。
	# 跷跷板需要实际渲染该旋转，故在首次使用时强制关闭忽略。
	_camera.ignore_rotation = false
	_rocking_max_rotation = deg_to_rad(maxf(absf(max_degrees), 0.0))
	_rocking_interval = maxf(interval, 0.05)
	if active and not _rocking_enabled:
		_base_rotation = _camera.rotation - _sway_rotation - _rocking_rotation
		_rocking_enabled = true
		_rocking_timer = 0.0
		_rocking_direction = 0
		_choose_rocking_target()
	elif not active and _rocking_enabled:
		_rocking_enabled = false
		_rocking_target = 0.0
		_rocking_rotation = 0.0
		_apply_camera_rotation()
	elif active and absf(_rocking_target) > _rocking_max_rotation:
		_rocking_target = signf(_rocking_target) * _rocking_max_rotation


## 当前跷跷板将要靠向的目标弧度；用于调试与回归断言。
func get_rocking_target() -> float:
	return _rocking_target


func is_rocking() -> bool:
	return _rocking_enabled


func _update_rocking(delta: float) -> void:
	_rocking_timer -= delta
	while _rocking_timer <= 0.0:
		_choose_rocking_target()
		_rocking_timer += _rocking_interval
	# 稍快于目标节拍地靠向目标，确保每次换向都经过中线，而非突跳。
	var max_speed := maxf(_rocking_max_rotation * 5.5, deg_to_rad(0.25))
	_rocking_rotation = move_toward(_rocking_rotation, _rocking_target, max_speed * delta)
	_apply_camera_rotation()


func _choose_rocking_target() -> void:
	if _rocking_max_rotation <= 0.0:
		_rocking_target = 0.0
		return
	if _rocking_direction == 0:
		_rocking_direction = 1 if randf() >= 0.5 else -1
	else:
		_rocking_direction *= -1
	# 每一侧至少保留可感知的倾斜，强度随机，避免退化成周期性正弦。
	var force := lerpf(0.35, 1.0, randf())
	_rocking_target = float(_rocking_direction) * _rocking_max_rotation * force


func _apply_camera_rotation() -> void:
	if _camera != null:
		_camera.rotation = _base_rotation + _sway_rotation + _rocking_rotation


## 触发全屏撼动（可覆盖默认振幅/时长）。
func shake(amp: float = 0.0, dur: float = 0.0) -> void:
	if _camera == null:
		_resolve_camera()
	if _camera == null:
		return
	# 连续触发时沿用最初基准，避免把上一帧的随机偏移当成新的静止位置。
	if not _shaking:
		_base_offset = _camera.offset - _sway_offset
	_amp = amplitude if amp <= 0.0 else amp
	var requested_duration: float = duration if dur <= 0.0 else dur
	if requested_duration <= 0.0:
		_end_shake()
		return
	# 保留导出字段的读回语义（流程自检会读取显式传入的时长），
	# 但衰减比率使用本次触发的独立活动时长。
	duration = requested_duration
	_active_duration = requested_duration
	_remaining = requested_duration
	_acc = 0.0
	_shaking = true


func _end_shake() -> void:
	_shaking = false
	_remaining = 0.0
	_active_duration = 0.0
	if _camera != null:
		_camera.offset = _base_offset + _sway_offset
