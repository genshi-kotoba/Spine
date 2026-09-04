class_name WorkIcon
extends InteractableObject
## WorkIcon — 工作图标（空占位）
## 仅展示贴图；点击响应留空，后续按剧情设计填充。


func _ready() -> void:
	states = {
		"idle": {
			"texture": "res://assets/sprites/work_icon.png",
			"size": Vector2(64, 64),
		},
	}
	super._ready()


func interact() -> void:
	# TODO: 定义点击行为（当前为空占位，点击无行为不报错）
	pass
