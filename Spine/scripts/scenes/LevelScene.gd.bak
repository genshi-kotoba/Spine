class_name LevelScene
extends Node2D
## LevelScene — 关卡场景（角色移动 + 跟随摄像机 + 按键交互）
## 摄像机水平跟随角色并 clamp 在地图边界内；
## 角色进入 InteractableObject 检测范围后按 E 触发其 interact()。

## 地图边界（逐关在编辑器调整）
@export var map_min_x: float = 0.0
@export var map_max_x: float = 1920.0

## 相机位置平滑插值系数（规格⑩，新增）；0=即时（现状）；不得破坏 clamp 语义与 map_min_x/map_max_x
@export var camera_smoothing: float = 6.0

@onready var _player: Player = $Player
@onready var _camera: Camera2D = $Player/Camera2D

## 当前重叠的可交互对象（同一时间只交互最近/当前重叠的对象）
var _overlapping: Array[InteractableObject] = []


func _ready() -> void:
	_camera.make_current()
	for object in find_children("*", "InteractableObject"):
		object.body_entered.connect(_on_object_body_entered.bind(object))
		object.body_exited.connect(_on_object_body_exited.bind(object))


func _process(delta: float) -> void:
	_update_camera(delta)


## 摄像机水平跟随角色；继续跟随会导致视野超出地图边缘时停止移动。
## camera_smoothing>0 时对 clamp 后的目标位置做平滑插值（0=现立即跟随）。
func _update_camera(delta: float) -> void:
	var half_width := get_viewport_rect().size.x * 0.5 * _camera.zoom.x
	var target_x := _player.position.x
	# clamp() 返回 Variant：用显式类型标注避免 "inferred from Variant" 警告被当作错误
	var clamped_x: float = clamp(target_x, map_min_x + half_width, map_max_x - half_width)
	if camera_smoothing > 0.0:
		var alpha := 1.0 - exp(-camera_smoothing * delta)
		_camera.global_position.x = lerpf(_camera.global_position.x, clamped_x, alpha)
	else:
		_camera.global_position.x = clamped_x


func _unhandled_input(event: InputEvent) -> void:
	if StoryMonitor.input_locked:
		return
	if event.is_action_pressed("interact") and not _overlapping.is_empty():
		_overlapping.front().interact()
		# TODO: UI 提示可选


func _on_object_body_entered(body: Node2D, object: InteractableObject) -> void:
	if body == _player and not _overlapping.has(object):
		_overlapping.append(object)


func _on_object_body_exited(body: Node2D, object: InteractableObject) -> void:
	if body == _player:
		_overlapping.erase(object)
