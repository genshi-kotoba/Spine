class_name BedroomWallItem
extends "res://scripts/objects/item.gd"
## BedroomWallItem — C3 卧室结局「面前墙」item（spec ⑦ BED-A）
## 交互显示 E 共 3 次；每交互一次墙面色渐变占位更新（state 0=原墙纸 → 1/2/3=渐变占位色，
## 真实为撕墙纸展海报，白模以颜色渐变占位）。状态封顶 3（达到上限后不再推进）。
## 复用前置 Item 基类：touched() 经 gate / 交互开关检查后进入 _try_touch()，汇入 set_state()→apply_state()。

## 每次交互后发射（state = 新状态 1..3），供流程/BedroomEnding 计数联动。
signal wall_updated(state: int)

## 原墙纸与 1/2/3 渐变占位色（白模零贴图，纯颜色占位）。
## 三次分别露出红、橙、黄区域，保证每次 E 都有肉眼可见的墙面更新。
@export var wall_color_base: Color = Color(0.30, 0.29, 0.32, 1)
@export var wall_color_1: Color = Color(0.72, 0.18, 0.16, 1)
@export var wall_color_2: Color = Color(1.00, 0.34, 0.08, 1)
@export var wall_color_3: Color = Color(1.00, 0.74, 0.16, 1)
## 交互次数上限（spec「E×3」）。
@export var interactions_max: int = 3

## 可选：卧室背景墙纸 Sprite2D（docs/c3_bedroom_wallpaper_constraints.md）。
## 非空时 apply_state 按状态切换其贴图；index = state，越界/空纹理忽略。
@export var wallpaper_target: NodePath
## 各状态对应的墙纸贴图（index = state）。
@export var wallpaper_state_textures: Array[Texture2D] = []


func _ready() -> void:
	states = {
		0: {"color": wall_color_base},
		1: {"color": wall_color_1},
		2: {"color": wall_color_2},
		3: {"color": wall_color_3},
	}
	super._ready()


## 重置卧室结局进度（重复进入卧室时恢复原墙纸状态）。
func reset_progress() -> void:
	set_state(0)


## 状态对应的占位颜色，供流程自检/HUD 读取。
func color_for_state(state: int) -> Color:
	return {
		0: wall_color_base,
		1: wall_color_1,
		2: wall_color_2,
		3: wall_color_3,
	}.get(clampi(state, 0, interactions_max), wall_color_base)


## 统一应用墙体占位视觉；即使场景把 Polygon2D 包在容器内也能更新。
func apply_state(new_state: int) -> void:
	var clamped_state := clampi(new_state, 0, interactions_max)
	super.apply_state(clamped_state)
	var color := color_for_state(clamped_state)
	_apply_polygon_color_recursive(self, color)
	_apply_wallpaper(clamped_state)


## 按状态切换背景墙纸贴图（可选联动；未配置 wallpaper_target 时零副作用）。
func _apply_wallpaper(state: int) -> void:
	if wallpaper_target == NodePath():
		return
	var sp := get_node_or_null(wallpaper_target) as Sprite2D
	if sp == null:
		return
	if state < 0 or state >= wallpaper_state_textures.size():
		return
	var tex: Texture2D = wallpaper_state_textures[state]
	if tex != null:
		sp.texture = tex


func _apply_polygon_color_recursive(node: Node, color: Color) -> void:
	for child in node.get_children():
		if child is Polygon2D:
			(child as Polygon2D).color = color
		_apply_polygon_color_recursive(child, color)


## 实际触发（gate/交互开关检查已由基类 touched 完成）：状态未达上限则 +1，发墙色渐变更新。
## 已达上限不再推进（占位：保持最终渐变）。
func _try_touch() -> bool:
	if current_state >= interactions_max:
		return false
	set_state(current_state + 1)
	wall_updated.emit(current_state)
	return true
