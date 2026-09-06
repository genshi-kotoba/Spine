class_name InteractHint
extends Node2D
## InteractHint — 可复用「E 提示」组件（C3 前置需求①）
## 自接线父 Area2D（item / InteractableObject）的 body_entered/body_exited：
## 角色（body is Player）进入 → show_hint()；离开 → hide_hint()。零外部配置。
## 纯视觉提示：仅显示既有 interact 键位图（键盘风「E」），不新增输入/操作。
## 无 hint_texture 时退化 Label 白模显示文本「E」（零资产）。
## 可挂到任意 Area2D（Item 或 InteractableObject），与关卡内容解耦（同 DepthParallax 先例）。

## Kenney Input Prompts「E」图标；空 = Label 白模占位（显示文本 "E"）。
@export var hint_texture: Texture2D

## 头顶上方偏移（相对 item 中心；白模可按 size 调整）。
@export var head_offset: Vector2 = Vector2(0, -70)

## 整体缩放。
@export var scale_factor: float = 1.0

## 淡入淡出时长（秒）；0 = 即时显隐。
@export var fade_duration: float = 0.15

## 父 Area2D（作为交互范围检测的 item / InteractableObject）。
var _owner_area: Area2D = null
var _player: Node2D = null

@onready var _visual: Node2D = $Visual

var _visible_target: bool = false
var _tween: Tween = null


func _ready() -> void:
	_owner_area = get_parent() as Area2D
	_apply_visual_setup()
	visible = false
	if _owner_area != null and _owner_area is Area2D:
		_owner_area.body_entered.connect(_on_body_entered)
		_owner_area.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	# Item ranges can be moved in the editor independently of the Area2D root. Poll the
	# same shared range API used by E/highlight so the hint cannot drift or lag behind
	# physics body_entered/body_exited delivery after a teleport.
	if _owner_area == null or not _owner_area.has_method("is_player_in_interaction_range"):
		return
	if _player == null or not is_instance_valid(_player):
		_player = _resolve_player()
	var in_range := _player != null and bool(_owner_area.call("is_player_in_interaction_range", _player))
	var should_show := in_range
	if should_show != _visible_target:
		_apply_visibility(should_show)


func _apply_visual_setup() -> void:
	if _visual == null:
		return
	_visual.scale = Vector2(scale_factor, scale_factor)
	if _visual is Sprite2D:
		var sprite := _visual as Sprite2D
		if hint_texture != null:
			sprite.texture = hint_texture
			sprite.visible = true
		else:
			sprite.visible = false
		_visual.position = _interaction_anchor_offset() + head_offset


func _interaction_anchor_offset() -> Vector2:
	if _owner_area == null:
		return Vector2.ZERO
	var shape_node := _owner_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return Vector2.ZERO
	return _owner_area.to_local(shape_node.global_position)


func _resolve_player() -> Node2D:
	var grouped := get_tree().get_first_node_in_group("player") as Node2D
	if grouped != null:
		return grouped
	var scene := get_tree().current_scene
	if scene != null:
		var direct := scene.get_node_or_null("Player") as Node2D
		if direct != null:
			return direct
		return _scan_for_player(scene)
	return null


func _scan_for_player(node: Node) -> Node2D:
	if node is Player:
		return node as Node2D
	for child in node.get_children():
		var found := _scan_for_player(child)
		if found != null:
			return found
	return null


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		show_hint()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		hide_hint()


## 显示提示（淡入）。
func show_hint() -> void:
	_visible_target = true
	_apply_visibility(true)


## 隐藏提示（淡出）。
func hide_hint() -> void:
	_visible_target = false
	_apply_visibility(false)


## 流程直接控制（如 gate 未满足时隐藏）。
func set_visible_forced(v: bool) -> void:
	_visible_target = v
	_apply_visibility(v)


func _apply_visibility(v: bool) -> void:
	if _visible_target == v and visible == v:
		return
	_visible_target = v
	if _tween != null:
		_tween.kill()
		_tween = null
	if _visual == null:
		visible = v
		return
	if fade_duration <= 0.0:
		visible = v
		_visual.modulate.a = 1.0 if v else 0.0
		return
	visible = true
	var target_a: float = 1.0 if v else 0.0
	_tween = create_tween()
	_tween.tween_property(_visual, "modulate:a", target_a, fade_duration)
	if not v:
		_tween.tween_callback(func() -> void: visible = false)
