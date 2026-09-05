class_name Bubble
extends Node2D
## Bubble — 蓝色气泡视觉组件（C3 gameplay §4.3 呼吸机制）
## 白模：Polygon2D 圆近似（零贴图、零外部依赖）。每帧跟随玩家身旁。
## restore() 恢复完整；pop() 破裂（白模可仅隐藏，可选缩放消失）；
## set_air_fraction(f) 随计时 0→1 压缩/变暗（可选，供 BreathSystem 计时视觉表现）。

## 气泡半径（px）。
@export var radius: float = 22.0

## 气泡颜色（蓝色）。
@export var color: Color = Color(0.35, 0.62, 0.96, 1)

## 跟随玩家偏移（同伴身旁）。
@export var follow_offset: Vector2 = Vector2(46, -28)

## Player 节点（NodePath；空 → 组 "player" 或场景树内查找）。
@export var player_path: NodePath

## 破裂时是否缩放消失（false → 直接隐藏；白模占位可直接隐藏）。
@export var pop_scale_anim: bool = true

## 缩放/隐藏计时（破裂动画时长，s）。
@export var pop_anim_time: float = 0.18

var _player: Node2D = null
var _visual: Node2D = null
var _air_fraction: float = 1.0
var _pop_tween: Tween = null


func _ready() -> void:
	_build_visual()
	_resolve_player()
	_apply_visual()


func _process(_delta: float) -> void:
	if _player != null and is_instance_valid(_player):
		global_position = _player.global_position + follow_offset


## 恢复气泡完整（可见、满空气、归位）。
func restore() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
		_pop_tween = null
	visible = true
	scale = Vector2.ONE
	_air_fraction = 1.0
	_apply_visual()


## 破裂：空气归零；按 pop_scale_anim 选缩放消失或直接隐藏（白模占位可仅隐藏）。
func pop() -> void:
	_air_fraction = 0.0
	_apply_visual()
	if pop_scale_anim:
		if _pop_tween != null and _pop_tween.is_valid():
			_pop_tween.kill()
		_pop_tween = create_tween()
		_pop_tween.tween_property(self, "scale", Vector2(0.05, 0.05), pop_anim_time)
		_pop_tween.tween_callback(_hide_after_pop)
	else:
		visible = false
		scale = Vector2.ONE


## 设置空气占比 0→1（随计时压缩/变暗，可选）。
func set_air_fraction(f: float) -> void:
	_air_fraction = clampf(f, 0.0, 1.0)
	_apply_visual()


## 当前空气占比（读回/自检）。
func get_air_fraction() -> float:
	return _air_fraction


func _hide_after_pop() -> void:
	visible = false
	scale = Vector2.ONE


## 依空气占比更新视觉（压缩 + 变淡）。
func _apply_visual() -> void:
	if _visual == null:
		return
	var s: float = 0.6 + 0.4 * _air_fraction
	_visual.scale = Vector2(s, s)
	_visual.modulate.a = _air_fraction


## 构造圆形 Polygon2D（白模可视化）。
func _build_visual() -> void:
	_visual = get_node_or_null("BubbleShape") as Node2D
	if _visual == null:
		var poly := Polygon2D.new()
		poly.name = "BubbleShape"
		poly.color = color
		poly.polygon = _make_circle_points(radius)
		add_child(poly)
		_visual = poly


## 生成圆点数组（半径 r）。
func _make_circle_points(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segs := 24
	for i in range(segs):
		var angle: float = TAU * float(i) / float(segs)
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	return pts


func _resolve_player() -> void:
	if player_path != NodePath():
		var node := get_node_or_null(player_path)
		if node is Node2D:
			_player = node as Node2D
			return
	var group_player := get_tree().get_first_node_in_group("player")
	if group_player is Node2D:
		_player = group_player as Node2D
		return
	_player = _scan_for_player(get_tree().current_scene)


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
