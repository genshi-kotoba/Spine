class_name StartButton
extends InteractableObject
## StartButton — 场景一开始按钮
## 点击后切换场景到 computer_screen（场景跳转非状态机变更，直接执行）。


const NEXT_SCENE := "res://scenes/computer_screen.tscn"


func _ready() -> void:
	states = {
		"idle": {
			"texture": "res://assets/sprites/start_button.png",
			"size": Vector2(185, 48),
		},
	}
	super._ready()


## 点击 → 切换到 computer_screen
func interact() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)
