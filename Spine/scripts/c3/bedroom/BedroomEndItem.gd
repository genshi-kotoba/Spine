class_name BedroomEndItem
extends "res://scripts/objects/item.gd"
## BedroomEndItem — C3 卧室结局「右手靠墙」item（spec ⑦ BED-D）
## touched → 状态更新占位（set_state(1)）+ 发射 end_white_requested → BedroomEnding/C3Flow 触发白屏结束。
## 复用前置 Item 基类；白模零贴图，state 1 用占位色/尺寸变化表达「已触发」。

## 玩家按 E 请求白屏结束（由 BedroomEnding 设 end_white 旗标并转发光）。
signal end_white_requested

## state 0（未触发）/1（已触发占位，变亮）。
@export var color_idle: Color = Color(0.35, 0.33, 0.30, 1)
@export var color_triggered: Color = Color(1, 1, 1, 1)


func _ready() -> void:
	states = {
		0: {"color": color_idle},
		1: {"color": color_triggered},
	}
	super._ready()


## 实际触发（gate/交互开关检查已由基类 touched 完成）：置状态更新占位并请求白屏结束。
func _try_touch() -> bool:
	set_state(1)
	end_white_requested.emit()
	return true
