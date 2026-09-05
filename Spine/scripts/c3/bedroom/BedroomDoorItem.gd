class_name BedroomDoorItem
extends "res://scripts/objects/item.gd"
## BedroomDoorItem — C3 卧室结局「回客厅」门 item（spec ⑦ BED-C）
## gate_flag=bedroom_unlocked：解锁前 base touched() 走 gate_blocked（无反应、无文本）；
## 解锁后（3 次墙交互后由 BedroomEnding 置 bedroom_unlocked=true）按 E → 发射 door_return_requested，
## 请求把玩家送回客厅卧室门前。复用前置 Item 基类（gate_flag 门控 + _try_touch 覆写）。

## 玩家按 E 请求回客厅卧室门前（由 BedroomEnding/C3Flow 处理搬运）。
signal door_return_requested


func _ready() -> void:
	super._ready()


## 实际触发（gate 已由基类 touched 检查）：告知流程把玩家送回客厅卧室门前。
func _try_touch() -> bool:
	door_return_requested.emit()
	return true
