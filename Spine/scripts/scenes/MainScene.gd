class_name MainScene
extends Node2D
## MainScene — 主场景（固定摄像机 + 纯点击交互）
## 摄像机固定在预设位置，不接受任何移动输入。
## 玩家唯一交互方式：点击场景中的 InteractableObject（对象自身处理 input_event）。

## 摄像机固定位置（预设，可在编辑器调整）
@export var camera_position: Vector2 = Vector2.ZERO

@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_camera.position = camera_position
	_camera.make_current()


## 固定摄像机：不实现任何摄像机移动逻辑。
## 场景级输入处理必须先检查全局输入锁。
func _unhandled_input(_event: InputEvent) -> void:
	if StoryMonitor.input_locked:
		return
