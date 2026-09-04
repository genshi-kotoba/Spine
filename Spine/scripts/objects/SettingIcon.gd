class_name SettingIcon
extends InteractableObject
## SettingIcon — 设置图标（空占位）
## 仅展示贴图；点击响应留空，后续按剧情设计填充。


func _ready() -> void:
	states = {
		"idle": {
			"texture": "res://assets/sprites/setting_icon.png",
			"size": Vector2(128, 128),
		},
	}
	super._ready()


func interact() -> void:
	# TODO: 定义点击行为（当前为空占位，点击无行为不报错）
	pass
