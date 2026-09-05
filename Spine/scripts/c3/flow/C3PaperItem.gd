class_name C3PaperItem
extends "res://scripts/objects/item.gd"
## C3PaperItem — C3 考卷 item（门控/顺序无关/白纸占位）
## 复用前置 Item 基类；touched() 经基类 gate/交互开关检查后进入 _try_touch()：
## 置已得状态(state=1) + 通知 C3Flow.on_paper_collected(paper_id, score) 用于计分/阶段推进。
## 门控（gate_flag，如 study_items_unlocked）与 states 表(白纸占位)由场景配置。

@export var paper_id: String = ""
@export var score: int = 100

## 可选：显式指定 C3Flow 节点路径（空 → 组 "c3flow" 查找）。
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


## 实际触发（gate 检查已由基类完成）：标记得卷 + 物品系消失 + 通知流程。
func _try_touch() -> bool:
	set_state(1)
	_disappear()
	_notify_flow()
	return true


## 物品系：拿到（state 置 1）后 item 消失（白模：hidden + 禁碰撞），不再可交互。
## 场景系(非 C3PaperItem)不消失、多段 E 封顶逻辑各自保留不重叠。
func _disappear() -> void:
	visible = false
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)


func _notify_flow() -> void:
	# 惰性重解析流程引用（_ready 时 C3Flow 可能尚未入组/入树；通知时重查）
	if _flow == null or not is_instance_valid(_flow):
		_resolve_flow()
	if _flow != null and _flow.has_method("on_paper_collected"):
		_flow.on_paper_collected(paper_id, score)
