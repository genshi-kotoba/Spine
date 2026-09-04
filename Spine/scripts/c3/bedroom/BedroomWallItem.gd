class_name BedroomWallItem
extends "res://scripts/objects/item.gd"
## BedroomWallItem — C3 卧室结局「面前墙」item（spec ⑦ BED-A）
## 交互显示 E 共 3 次；每交互一次墙面色渐变占位更新（state 0=原墙纸 → 1/2/3=渐变占位色，
## 真实为撕墙纸展海报，白模以颜色渐变占位）。状态封顶 3（达到上限后不再推进）。
## 复用前置 Item 基类：touched() 经 gate / 交互开关检查后进入 _try_touch()，汇入 set_state()→apply_state()。

## 每次交互后发射（state = 新状态 1..3），供流程/BedroomEnding 计数联动。
signal wall_updated(state: int)

## 原墙纸与 1/2/3 渐变占位色（白模零贴图，纯颜色占位）。
@export var wall_color_base: Color = Color(0.45, 0.40, 0.35, 1)
@export var wall_color_1: Color = Color(0.60, 0.50, 0.42, 1)
@export var wall_color_2: Color = Color(0.72, 0.58, 0.48, 1)
@export var wall_color_3: Color = Color(0.85, 0.68, 0.52, 1)
## 交互次数上限（spec「E×3」）。
@export var interactions_max: int = 3


func _ready() -> void:
	states = {
		0: {"color": wall_color_base},
		1: {"color": wall_color_1},
		2: {"color": wall_color_2},
		3: {"color": wall_color_3},
	}
	super._ready()


## 实际触发（gate/交互开关检查已由基类 touched 完成）：状态未达上限则 +1，发墙色渐变更新。
## 已达上限不再推进（占位：保持最终渐变）。
func _try_touch() -> bool:
	if current_state >= interactions_max:
		return false
	set_state(current_state + 1)
	wall_updated.emit(current_state)
	return true
