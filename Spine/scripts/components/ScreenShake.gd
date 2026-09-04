class_name ScreenShake
extends Node2D
## ScreenShake — 全屏撼动组件（C3 前置需求④）
## 驱动宿主 Camera2D 的 offset 产生随机抖动并衰减，结束后归零。
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
var _shaking: bool = false
var _amp: float = 0.0
var _remaining: float = 0.0
var _acc: float = 0.0


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
	if not _shaking:
		return
	if _camera == null:
		_shaking = false
		return
	_acc += delta
	_remaining -= delta
	if _remaining <= 0.0:
		_end_shake()
		return
	# attenuation 参与衰减曲线：剩余时长比例 ^ attenuation（越大回位越快；1=线性，2=二次加速回位）
	var ratio: float = clampf(_remaining / duration, 0.0, 1.0)
	var falloff: float = pow(ratio, attenuation)
	var amp_now := _amp * falloff
	# frequency 参与抖动步进：正弦主波(按 frequency) + 均匀随机分量混合（兼具规律与随机）
	var wave_x: float = sin(_acc * frequency * TAU)
	var wave_y: float = cos(_acc * frequency * TAU)
	var ox := (wave_x * 0.5 + (randf() * 2.0 - 1.0) * 0.5) * amp_now
	var oy := (wave_y * 0.5 + (randf() * 2.0 - 1.0) * 0.5) * amp_now
	_camera.offset = _base_offset + Vector2(ox, oy)


## 触发全屏撼动（可覆盖默认振幅/时长）。
func shake(amp: float = 0.0, dur: float = 0.0) -> void:
	if _camera == null:
		_resolve_camera()
	if _camera == null:
		return
	_base_offset = _camera.offset
	_amp = amplitude if amp <= 0.0 else amp
	duration = duration if dur <= 0.0 else dur
	_remaining = duration
	_acc = 0.0
	_shaking = true


func _end_shake() -> void:
	_shaking = false
	if _camera != null:
		_camera.offset = _base_offset
