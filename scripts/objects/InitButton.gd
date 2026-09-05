class_name InitButton
extends InteractableObject
## InitButton — 场景一初始化按钮
## 点击后删除已保存的存档，游戏进度从头开始（白模文字按钮，无贴图资产）。


func _ready() -> void:
	states = {
		"idle": {
			"size": Vector2(185, 48),
		},
	}
	super._ready()


## 点击 → 删除存档
func interact() -> void:
	GameState.delete_save()
