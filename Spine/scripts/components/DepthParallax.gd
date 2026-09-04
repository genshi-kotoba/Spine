class_name DepthParallax
extends Node2D
## DepthParallax — 可复用景深视差组件（规格⑧）
## 每层（子节点）通过 metadata "_depth_factor" 配置深度系数；
## 每帧按 target 相对 anchor_point 的位移 × depth_factor 平移该层（远景 |factor| 小、近景 |factor| 大）；
## 鼠标移动到视口边缘时附加微幅偏移（mouse_influence，0=完全关闭；幅度小）。
## 组件与关卡内容完全解耦（不含任何房间名称与关卡编号字面量），可挂到任意场景复用。
## 注意：不依赖相机移动（本关相机恒定居中），景深由角色位置驱动。

## 总开关
@export var enabled: bool = true
## 视差锚点（目标与之比较的基准点，建议游戏区中心 (960,620)，规格⑧）
@export var anchor_point: Vector2 = Vector2(960, 620)
## 鼠标微触发幅度（px，小幅度；0 = 完全关闭鼠标视差，规格⑧）
@export var mouse_influence: float = 8.0
## 层偏移平滑插值系数（越大越跟手）
@export var smoothing: float = 5.0
## 可选：直接用 NodePath 指定目标（独立挂载时用；由宿主注入则保持为空）
@export var target_path: NodePath

## 视差目标节点（通常为角色，由宿主注入）
var target: Node2D = null

var _base_positions: Dictionary = {}
var _current_offsets: Dictionary = {}


func _ready() -> void:
	if target_path != NodePath():
		var node := get_node_or_null(target_path)
		if node is Node2D:
			target = node
	for child in get_children():
		if child.has_meta("_depth_factor"):
			_base_positions[child] = child.position
			_current_offsets[child] = Vector2.ZERO


func _process(delta: float) -> void:
	if not enabled:
		return
	var target_global := anchor_point
	if target != null and is_instance_valid(target):
		target_global = target.global_position
	var base_delta := target_global - anchor_point

	# 鼠标微触发（规格⑧）：鼠标归一化位置 [-1,1] × mouse_influence（幅度小）
	var viewport := get_viewport()
	var view_size := viewport.get_visible_rect().size
	var view_center := view_size * 0.5
	var mouse_norm := Vector2.ZERO
	var mouse_pos := viewport.get_mouse_position()
	if view_center.x > 0.0 and view_center.y > 0.0:
		mouse_norm = (mouse_pos - view_center) / view_center
	var mouse_delta := mouse_norm * mouse_influence

	for child in get_children():
		if not _base_positions.has(child):
			continue
		var factor: float = child.get_meta("_depth_factor")
		var desired := (base_delta + mouse_delta) * factor
		var current: Vector2 = _current_offsets[child]
		# clamp() 返回 Variant：显式类型标注避免 "inferred from Variant" 警告被当作错误
		var alpha: float = clamp(smoothing * delta, 0.0, 1.0)
		current = current.lerp(desired, alpha)
		_current_offsets[child] = current
		child.position = _base_positions[child] + current
