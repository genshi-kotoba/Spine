class_name ItemMarker
extends Node2D
## ItemMarker — 可复用 item 高光组件。
## 同房间且交互可用时显示 item 描边；远处为白色，进入 item 的交互范围后为金色。
## 交互范围直接复用宿主 Item 的 Area2D 碰撞范围，与 E 键和 InteractHint 保持一致。

## 远处提示色：表示同房间内存在可交互 item。
@export var far_outline_color: Color = Color(1, 1, 1, 1)
## 进入交互范围后的高亮色。
@export var near_outline_color: Color = Color(1, 0.84, 0.18, 1)
## 描边宽度（px）。
@export var outline_width: float = 5.0
## 描边与 item 可见表面的间距（px）。默认 0，描边紧贴可见边界。
@export var outline_padding: float = 0.0
## 无可读碰撞范围时的回退距离（px）。
@export var interaction_distance: float = 180.0
## 本 item 所属房间 id；空 → 由 item.x 经 RoomTable 派生。
@export var room_id: String = ""
## 指向 RoomTable 节点的 NodePath（同场景共享一个 RoomTable）。
@export var room_table_path: NodePath
## 指向 Player 的 NodePath（空 → 组 "player" 或场景树内查找）。
@export var player_path: NodePath
## 描边相对 item 的偏移；默认直接包围 item。
@export var offset: Vector2 = Vector2.ZERO

var _item: Node2D = null
var _player: Node2D = null
var _room_table: RoomTable = null
var _available_flag: bool = false
var _visual: Line2D = null


func _ready() -> void:
	_item = get_parent() as Node2D
	_build_visual()
	_resolve_player()
	_resolve_room_table()
	_connect_availability()
	visible = false


func _process(_delta: float) -> void:
	if _item == null:
		return
	var available: bool = _available_flag
	if _item.has_method("is_interaction_available"):
		available = _item.is_interaction_available()
	var show := available and _same_room()
	visible = show
	if _visual == null:
		return
	_visual.modulate.a = 1.0 if show else 0.0
	if show:
		_visual.default_color = near_outline_color if _is_in_interaction_range() else far_outline_color


## 宿主 Item 的 interaction_available 信号回调。
func set_interactable(flag: bool) -> void:
	_available_flag = flag


## 返回当前玩家是否已进入宿主 Item 的真实交互范围。
func is_in_interaction_range() -> bool:
	return _is_in_interaction_range()


## 返回当前描边颜色，供演示场景和 headless 自检读取。
func get_current_outline_color() -> Color:
	return _visual.default_color if _visual != null else far_outline_color


## 构造矩形描边。优先读取 Item 的实际 Polygon2D 可见边界，避免描边与物体表面产生间隙。
func _build_visual() -> void:
	_visual = get_node_or_null("Outline") as Line2D
	if _visual == null:
		_visual = Line2D.new()
		_visual.name = "Outline"
		add_child(_visual)
	_visual.width = outline_width
	_visual.default_color = far_outline_color
	_visual.antialiased = true
	_visual.closed = true
	_visual.z_index = 10
	_visual.position = offset
	var bounds: Rect2 = _get_visual_bounds()
	if bounds.size == Vector2.ZERO:
		var item_size: Vector2 = _get_item_size()
		if item_size == Vector2.ZERO:
			item_size = Vector2(64, 64)
		bounds = Rect2(-item_size * 0.5, item_size)
	var padding: Vector2 = Vector2.ONE * outline_padding
	bounds = bounds.grow(padding.x)
	_visual.points = PackedVector2Array([
		bounds.position,
		Vector2(bounds.end.x, bounds.position.y),
		bounds.end,
		Vector2(bounds.position.x, bounds.end.y)
	])


func _get_visual_bounds() -> Rect2:
	if _item == null:
		return Rect2()
	var found := false
	var min_point := Vector2.ZERO
	var max_point := Vector2.ZERO
	for child in _item.get_children():
		if child is Polygon2D:
			var polygon: Polygon2D = child as Polygon2D
			for point in polygon.polygon:
				var local_point: Vector2 = polygon.transform * point
				if not found:
					min_point = local_point
					max_point = local_point
					found = true
				else:
					min_point = min_point.min(local_point)
					max_point = max_point.max(local_point)
		elif child is Sprite2D:
			var sprite: Sprite2D = child as Sprite2D
			if sprite.texture != null:
				var sprite_size: Vector2 = sprite.texture.get_size() * sprite.scale.abs()
				var sprite_min: Vector2 = sprite.position - sprite_size * 0.5
				var sprite_max: Vector2 = sprite.position + sprite_size * 0.5
				if not found:
					min_point = sprite_min
					max_point = sprite_max
					found = true
				else:
					min_point = min_point.min(sprite_min)
					max_point = max_point.max(sprite_max)
	return Rect2(min_point, max_point - min_point) if found else Rect2()


func _get_item_size() -> Vector2:
	if _item == null:
		return Vector2(64, 64)
	var configured_size: Variant = _item.get("size")
	if configured_size is Vector2 and configured_size.x > 0.0 and configured_size.y > 0.0:
		return configured_size
	var shape_node := _item.get_node_or_null("CollisionShape2D")
	if shape_node is CollisionShape2D and shape_node.shape is RectangleShape2D:
		return (shape_node.shape as RectangleShape2D).size
	return Vector2.ZERO


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


func _resolve_room_table() -> void:
	if room_table_path != NodePath():
		var node := get_node_or_null(room_table_path)
		if node is RoomTable:
			_room_table = node as RoomTable


## 连接宿主 Item 的 interaction_available 信号（只读，set_interactable 回调）。
func _connect_availability() -> void:
	if _item != null and _item.has_signal("interaction_available"):
		_item.connect("interaction_available", Callable(self, "set_interactable"))


## 同房间判定：玩家与 item 属于同一房间。无 RoomTable 或玩家不可得时视为同房。
func _same_room() -> bool:
	if _room_table == null or _item == null:
		return true
	var player := _player
	if player == null or not is_instance_valid(player):
		return true
	var item_room: String = room_id
	if item_room == "":
		item_room = _room_table.get_room_of(_item.global_position.x)
	var player_room: String = _room_table.get_room_of(player.global_position.x)
	return item_room != "" and item_room == player_room


## 使用 Item/Player 矩形碰撞边界，与 Player.interact_pressed 的触发条件一致。
func _is_in_interaction_range() -> bool:
	if _player == null or not is_instance_valid(_player) or _item == null:
		return false
	# Item and Player use rectangle collision shapes. Comparing their bounds keeps the
	# visual state responsive after a scripted teleport while matching body overlap.
	var item_size := _get_item_size()
	var player_half_size := _get_player_half_size()
	if item_size.x > 0.0 and item_size.y > 0.0:
		var item_half_size := item_size * 0.5
		var delta := (_player.global_position - _item.global_position).abs()
		return delta.x <= item_half_size.x + player_half_size.x and delta.y <= item_half_size.y + player_half_size.y
	if _item is Area2D:
		return (_item as Area2D).get_overlapping_bodies().has(_player)
	return _item.global_position.distance_to(_player.global_position) <= interaction_distance


func _get_player_half_size() -> Vector2:
	var shape_node := _player.get_node_or_null("CollisionShape2D")
	if shape_node is CollisionShape2D and shape_node.shape is RectangleShape2D:
		return (shape_node.shape as RectangleShape2D).size * 0.5
	return Vector2.ZERO


## 手动开关（流程直接控制）。
func set_available(flag: bool) -> void:
	set_interactable(flag)
