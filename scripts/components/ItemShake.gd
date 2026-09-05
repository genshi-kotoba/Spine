class_name ItemShake
extends Node2D
## ItemShake — 部分撼动组件（C3 前置需求④）
## 仅作用于挂载节点（父 Node2D）的局部偏移/旋转，结束后归位。语义 = item 局部撼动。
## 触发：item_shake.shake(amp, dur)。无房间/关卡字面量，可挂到任意 Node2D/Area2D 复用。

## 振幅（px）。
@export var amplitude: float = 6.0
## 时长（秒）。
@export var duration: float = 0.25
## 振动轴（x / y / both）。
@export_enum("both", "x", "y") var axis: String = "both"
## 是否随机切换方向。
@export var flip_random: bool = true

var _target: Node2D = null
var _base_position: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _shaking: bool = false
var _amp: float = 0.0
var _elapsed: float = 0.0
var _last_offset: Vector2 = Vector2.ZERO
var _sign: float = 1.0


func _ready() -> void:
	var parent := get_parent()
	if parent is Node2D:
		_target = parent as Node2D


func _process(delta: float) -> void:
	if not _shaking:
		return
	if _target == null:
		_shaking = false
		return
	_elapsed += delta
	if _elapsed >= duration:
		_end_shake()
		return
	var t := _elapsed / duration
	var falloff := (1.0 - t)
	var step := sin(_elapsed * 40.0) * _amp * falloff
	var offset := _offset_for(step)
	if flip_random and _sign < 0.0:
		offset = -offset
	_target.position = _base_position + offset
	_target.rotation = _base_rotation + deg_to_rad(step * 3.0)


func _offset_for(step: float) -> Vector2:
	if axis == "x":
		return Vector2(step, 0.0)
	if axis == "y":
		return Vector2(0.0, step)
	return Vector2(step, step)


## 触发局部撼动。
func shake(amp: float = 0.0, dur: float = 0.0) -> void:
	if _target == null:
		var parent := get_parent()
		if parent is Node2D:
			_target = parent as Node2D
	if _target == null:
		return
	_base_position = _target.position
	_base_rotation = _target.rotation
	_amp = amplitude if amp <= 0.0 else amp
	duration = duration if dur <= 0.0 else dur
	_elapsed = 0.0
	_sign = -1.0 if flip_random and randf() < 0.5 else 1.0
	_shaking = true


func _end_shake() -> void:
	_shaking = false
	if _target != null:
		_target.position = _base_position
		_target.rotation = _base_rotation
