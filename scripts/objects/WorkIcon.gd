class_name WorkIcon
extends InteractableObject
## WorkIcon — 工作图标
## 点击后切换场景到 c3_level（场景跳转非状态机变更，直接执行）。


const NEXT_SCENE := "res://scenes/c3_level.tscn"


func _ready() -> void:
	states = {
		"idle": {
			"texture": "res://assets/sprites/work_icon.png",
			"size": Vector2(64, 64),
		},
	}
	super._ready()


## 点击 → 切换到 c3_floor
func interact() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)
