class_name LadderWindow
extends "res://scripts/objects/item.gd"
## LadderWindow — c2_bedroom 中央的梯窗（godot_c2_c4_prompt §4）
## 状态机两状态：0 = closed / 1 = open，交互 toggle。
## 视觉由 states 表 color 驱动（基类 _apply_state_table 作用于 Polygon2D 子节点）。
## 交互成功后由 C2Bedroom 监听 interaction_succeeded 触发白屏转场（本类不含转场逻辑）。


func _ready() -> void:
	states = {
		0: {"color": Color(0.2, 0.25, 0.4, 1)},
		1: {"color": Color(0.85, 0.9, 1.0, 1)},
	}
	super._ready()


## 范围内按 E → toggle closed/open（走基类 gate/交互开关链路）
func _try_touch() -> bool:
	if not player_in_range:
		return false
	set_state(1 - current_state)
	return true
