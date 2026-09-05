class_name ItemMarker
extends Node2D
## ItemMarker — 可复用「可交互」黄色星星标记组件（C3 前置需求⑥，§15）
## 当 item「交互可用」且「玩家与 item 同房间」时显示黄色星星；不可交互或异房则隐藏。
## 同房间远程可见：不要求靠近，与 E 提示（InteractHint 靠近才显示）是两套独立逻辑。
## 驱动：连接宿主 Item 的 interaction_available 信号（set_interactable 回调），并在 _process 轮询
## 宿主 is_interaction_available() 以响应门控/进程旗标变化；经 RoomTable 做同房判定。
## 独立可复用模块：挂 item 子节点即用；无房间名/关卡字面量；默认 Polygon2D 五角星（零贴图、零外部依赖）。

## 星星颜色（默认黄）。
@export var star_color: Color = Color(1, 0.84, 0.18, 1)
## 星星外半径（px）。
@export var star_size: float = 12.0
## 星星贴图（空 → Polygon2D 星形占位；设置时用 Sprite2D）。
@export var star_texture: Texture2D
## 本 item 所属房间 id；空 → 由 item.x 经 RoomTable 派生。
@export var room_id: String = ""
## 指向 RoomTable 节点的 NodePath（同场景共享一个 RoomTable）。
@export var room_table_path: NodePath
## 指向 Player 的 NodePath（空 → 组 "player" 或场景树内查找）。
@export var player_path: NodePath
## 星星相对 item 的偏移（头顶上方，默认 (0,-40)）。
@export var offset: Vector2 = Vector2(0, -40)

var _item: Node2D = null
var _player: Node2D = null
var _room_table: RoomTable = null
var _available_flag: bool = false
var _visual: CanvasItem = null


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
	if _visual != null:
		_visual.modulate.a = 1.0 if show else 0.0


## 宿主 Item 的 interaction_available 信号回调。
func set_interactable(flag: bool) -> void:
	_available_flag = flag


## 构造星形视觉：有 star_texture 用 Sprite2D，否则 Polygon2D 五角星（白模零贴图）。
func _build_visual() -> void:
	_visual = get_node_or_null("Star") as CanvasItem
	if _visual == null:
		if star_texture != null:
			var sprite := Sprite2D.new()
			sprite.name = "Star"
			sprite.texture = star_texture
			add_child(sprite)
			_visual = sprite
		else:
			var star := Polygon2D.new()
			star.name = "Star"
			star.color = star_color
			star.polygon = _make_star_points(star_size)
			add_child(star)
			_visual = star
	if _visual is Node2D:
		(_visual as Node2D).position = offset


func _make_star_points(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var inner := r * 0.45
	for i in range(10):
		var angle := -PI * 0.5 + i * (PI / 5.0)
		var radius := r if i % 2 == 0 else inner
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
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


func _resolve_room_table() -> void:
	if room_table_path != NodePath():
		var node := get_node_or_null(room_table_path)
		if node is RoomTable:
			_room_table = node as RoomTable


## 连接宿主 Item 的 interaction_available 信号（只读，set_interactable 回调）。
func _connect_availability() -> void:
	if _item != null and _item.has_signal("interaction_available"):
		_item.connect("interaction_available", Callable(self, "set_interactable"))


## 同房间判定：玩家与 item 属于同一房间。无 RoomTable 或玩家不可得时视为同房（不误隐藏）。
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


## 手动开关（流程直接控制）。
func set_available(flag: bool) -> void:
	set_interactable(flag)
