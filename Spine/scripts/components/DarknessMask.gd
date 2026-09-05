class_name DarknessMask
extends Node2D
## DarknessMask — 可配置光影遮罩组件（C3 前置需求③，方案 B 挖孔 shader 定案）
## 一个覆盖视口的 ColorRect 挂挖孔 canvas_item shader：孔内透明（透出场景），孔外遮罩压暗。
## 参数化：center_global（挖孔中心全局坐标）、follow_player、radius_inner/radius_outer、darkness_color、softness、enabled。
## 挂到任意关卡/层根即可启用；运行时改参数即时生效（供 C3「光影切换」）。
## 与白模 Polygon2D / DepthParallax 多层解耦：零遮挡几何，一个节点一个材质。

## 挖孔中心全局坐标（follow_player=false 时用；否则跟随玩家）。
@export var center_global: Vector2 = Vector2(960, 620)

## 跟随玩家（每帧取 Player 全局位置作为挖孔中心）。
@export var follow_player: bool = true

## 可选：直接用 NodePath 指定 Player（由宿主注入；未设置则按类型扫描场景树）。
@export var player_path: NodePath

## 全亮半径（孔内）。
@export var radius_inner: float = 130.0

## 全暗半径（孔外）。
@export var radius_outer: float = 420.0

## 遮罩颜色（深色 + alpha）。
@export var darkness_color: Color = Color(0.02, 0.03, 0.09, 0.55)  ## 昏暗透光（用户定案：非全黑）

## 边缘软度（0=硬边；放大 inner/outer 之间的过渡）。
@export var softness: float = 0.5

## 总开关；false 时完全透明。
@export var enabled: bool = true

## CanvasLayer 层级。默认 1（渲染于默认画布内容之上，遮罩才能压暗场景；可在特效之前/之后按需调整）。
@export var layer: int = 1

## Player 引用（follow_player 时查找；可由宿主注入）。
var _player: Node2D = null

var _layer: CanvasLayer = null
var _rect: ColorRect = null
var _mat: ShaderMaterial = null


func _ready() -> void:
	_build_overlay()
	add_to_group("fx_darkness")


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = layer
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_rect)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://scripts/components/darkness_mask.gdshader")
	_rect.material = _mat
	_apply_params()


func _process(_delta: float) -> void:
	if _rect == null:
		return
	_resize_rect()
	if enabled and follow_player and _player == null:
		_player = _find_player()
	_apply_params()


## 让遮罩矩形覆盖整个视口。
func _resize_rect() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var rect := vp.get_visible_rect()
	_rect.position = rect.position
	_rect.size = rect.size


## 把全局中心换算为视口归一化 UV，写入 shader uniform。
func _apply_params() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("enabled", enabled)
	_mat.set_shader_parameter("darkness_color", darkness_color)
	_mat.set_shader_parameter("inner_radius", radius_inner / _viewport_span())
	_mat.set_shader_parameter("outer_radius", radius_outer / _viewport_span())
	_mat.set_shader_parameter("softness", softness)
	_mat.set_shader_parameter("center_uv", _center_uv())


func _center_uv() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(0.5, 0.5)
	var world_center := center_global
	if follow_player and _player != null:
		world_center = _player.global_position
	var screen := vp.get_canvas_transform() * world_center
	var view_size := vp.get_visible_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return Vector2(0.5, 0.5)
	return screen / view_size


## 视口短边长度用于归一化半径（保证不同分辨率下遮罩尺寸视觉一致）。
func _viewport_span() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	var view_size := vp.get_visible_rect().size
	var span: float = maxf(view_size.x, view_size.y)
	return span if span > 0.0 else 1.0


func _find_player() -> Node2D:
	if player_path != NodePath():
		var node := get_node_or_null(player_path)
		if node is Node2D:
			return node as Node2D
	# 按类型全树扫描（只跑一次并缓存；场景内通常只有一个 Player）
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		return player as Node2D
	var node_player := _scan_for_player(get_tree().current_scene)
	if node_player != null:
		return node_player
	return null


func _scan_for_player(n: Node) -> Node2D:
	if n == null:
		return null
	if n is Player:
		return n as Player
	for child in n.get_children():
		var found := _scan_for_player(child)
		if found != null:
			return found
	return null
