class_name VanishItem
extends "res://scripts/objects/item.gd"
## VanishItem — 交互后消失的 item（godot_c2_c4_prompt §3.2：candle/star/lego 共用）
## 状态机：0 = 在场 / 1 = 已消失（隐藏节点 + 交互关闭）。
## 状态经 state_id 写入 GameState 统一管理；读档恢复时本类 apply_state 重建隐藏态。


func _ready() -> void:
	super._ready()
	# 基类 _ready 只走 _apply_state_table，本类表现（隐藏）需按恢复后的状态补应用一次
	apply_state(current_state)


## 范围内按 E → 消失（走基类 gate/交互开关链路）
func _try_touch() -> bool:
	if not player_in_range:
		return false
	set_state(1)
	return true


## 状态表现唯一出口：1 = 隐藏并关闭交互（高亮随 set_interaction_enabled(false) 一并清除）
func apply_state(new_state: int) -> void:
	if new_state == 1:
		hide()
		set_interaction_enabled(false)
	else:
		show()
