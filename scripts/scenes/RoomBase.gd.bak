class_name RoomBase
extends Node2D
## RoomBase — 通用房间白模基类（C3 前置需求⑤）
## 程序化搭建单间房间：地板/天花/侧墙 StaticBody2D + CollisionShape2D + Polygon2D 色块（白模零贴图）。
## 参数化：room_width / wall_height / stand_surface_y / floor_color / wall_color / door_pos / door_enabled。
## 房间作为独立可复用场景单元（room_bedroom_whitemodel.tscn），可在任意层实例化。

## 房间宽度（px）。
@export var room_width: float = 1920.0
## 侧墙高度（px）。
@export var wall_height: float = 780.0
## 站立面 y（地面碰撞顶面；默认 988，碰底留 8px，F5 教训）。
@export var stand_surface_y: float = 988.0
## 地板颜色。
@export var floor_color: Color = Color(0.5, 0.5, 0.5, 1)
## 墙体颜色。
@export var wall_color: Color = Color(0.35, 0.33, 0.3, 1)
## 自动门位置（Vector2，房间坐标系）；door_enabled=false 时忽略门。
@export var door_pos: Vector2 = Vector2.ZERO
## 是否生成自动门（AutoDoor 实例）。
@export var door_enabled: bool = true
## 出生点（实例化层可覆盖）：_ready 应用到场景内 Player 实例的位置。
@export var spawn_pos: Vector2 = Vector2(320, 948)

## floor/ceiling 厚度（px）。
const THICKNESS := 40.0

var _environment: Node2D = null


func _ready() -> void:
	_resolve_environment()
	_build_room()


func _resolve_environment() -> void:
	var env := get_node_or_null("Environment")
	if env is Node2D:
		_environment = env as Node2D
		return
	_environment = Node2D.new()
	_environment.name = "Environment"
	add_child(_environment)


func _build_room() -> void:
	# 清理旧子节点（防重复构建）
	for child in _environment.get_children():
		_environment.remove_child(child)
		child.queue_free()
	var cx := room_width * 0.5
	var ceiling_y := stand_surface_y - THICKNESS * 0.5 - wall_height
	_collider_box("Floor", Vector2(cx, stand_surface_y + THICKNESS * 0.5), Vector2(room_width + THICKNESS, THICKNESS), floor_color)
	_collider_box("Ceiling", Vector2(cx, ceiling_y), Vector2(room_width + THICKNESS, THICKNESS), wall_color)
	# 侧墙几何延伸至地面以封闭房间（无洞口泄漏）：墙顶=天花平面，墙底=地面碰撞底(stand_surface_y+THICKNESS)
	var wall_bottom_y: float = stand_surface_y + THICKNESS
	var wall_center_y: float = (ceiling_y + wall_bottom_y) * 0.5
	var wall_span: float = wall_bottom_y - ceiling_y
	_collider_box("WallLeft", Vector2(0, wall_center_y), Vector2(THICKNESS, wall_span), wall_color)
	_collider_box("WallRight", Vector2(room_width, wall_center_y), Vector2(THICKNESS, wall_span), wall_color)
	_apply_spawn()
	if door_enabled and door_pos != Vector2.ZERO:
		var door_scene: PackedScene = load("res://scenes/auto_door.tscn") as PackedScene
		var door: Node = door_scene.instantiate()
		door.name = "Door"
		door.position = door_pos
		_environment.add_child(door)


## 把 spawn_pos 应用到场景内 Player 实例（实例化层可覆盖；无 Player 子节点则忽略）。
func _apply_spawn() -> void:
	var player := get_node_or_null("Player") as Node2D
	if player != null:
		player.position = spawn_pos


func _collider_box(node_name: String, pos: Vector2, box_size: Vector2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = pos
	_environment.add_child(body)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = box_size
	col.shape = shape
	body.add_child(col)
	var visual := Polygon2D.new()
	visual.name = "Visual"
	visual.color = color
	visual.polygon = PackedVector2Array([
		Vector2(-box_size.x * 0.5, -box_size.y * 0.5),
		Vector2(box_size.x * 0.5, -box_size.y * 0.5),
		Vector2(box_size.x * 0.5, box_size.y * 0.5),
		Vector2(-box_size.x * 0.5, box_size.y * 0.5)
	])
	body.add_child(visual)
