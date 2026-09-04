class_name C3DoorEntryItem
extends "res://scripts/objects/item.gd"
## C3DoorEntryItem — 客厅卧室门入口 item（gate=bedroom_door_active）
## 门控满足后按 E → 通知 C3Flow.on_enter_bedroom()（黑屏渐变 + 搬运进卧室 begin）。

@export var flow_path: NodePath

var _flow: Node = null


func _ready() -> void:
	super._ready()
	_resolve_flow()


func _resolve_flow() -> void:
	if flow_path != NodePath():
		var n := get_node_or_null(flow_path)
		if n != null:
			_flow = n
			return
	_flow = get_tree().get_first_node_in_group("c3flow")


func _try_touch() -> bool:
	if _flow != null and _flow.has_method("on_enter_bedroom"):
		_flow.on_enter_bedroom()
	return true
