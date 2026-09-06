class_name Item
extends Area2D
## Item — 可交互物品基类
## 所有 item 子类必须继承本基类；用 Area2D 做碰撞范围检测。
## 状态机：current_state(int) 为唯一状态；set_state() 是唯一变更入口，
## apply_state() 是唯一效果出口；touched()/call_item() 最终汇入 set_state()。
## 本类与既有可交互对象体系并行、相互独立：本类不写全局状态字典、不参与其存档。
## C3 前置扩展（需求②）：gate_flag 进程门控、set_interaction_enabled 外部开关、
## force_trigger 强制触发（无视 gate/输入锁）、states 表驱动 apply_state、interaction_available/gate_blocked 信号。

## 包含范围（检测矩形）：决定 CollisionShape2D 的 RectangleShape2D size；_ready 时同步
@export var size: Vector2 = Vector2(64, 64)

## 角色站在物体正下方时的额外可达高度；不改变 X 轴范围（merge 自 Spine_to_merge）。
## 白模物体常悬在地面上方，适度余量可避免视觉位置与角色脚底的高度差阻断交互。
@export var vertical_interaction_padding: float = 96.0

## 交互门控进程旗标（GameState.get_process_flag 读取）：非空时 gate 未满足则不触发。
## 空 = 无 gate（兼容既有 TestItem 现行为）。
@export var gate_flag: String = ""

## 初始状态：_ready 置 current_state（现行为默认 0）。
@export var initial_state: int = 0

## 状态 → 配置表（键 int，值 {position?: Vector2, size?: Vector2, color?: Color, texture?: String}）。
## 基类 apply_state 默认按 states 表实现；子类仍可整段覆写（如 TestItem 的 Tween 到位置）。
@export var states: Dictionary = {}

## 强制触发节点（一个定位触发区 Node2D/Area2D）：玩家进入时无视 gate/输入锁调用 call_item(force_trigger_state)。
@export var force_trigger_node: NodePath

## 强制触发目标状态；< 0 时忽略（force_trigger 不生效）。
@export var force_trigger_state: int = -1

## 高亮总开关（godot_c3_prompt §3：玩家进入交互范围时 item 高亮，离开恢复；默认关闭）
@export var highlight_enabled: bool = false

## 高亮时的 modulate（默认 1.3 倍提亮，可在编辑器调整）
@export var highlight_modulate: Color = Color(1.3, 1.3, 1.3)

## 初始可交互开关（godot_c2_c4_prompt §3.1：false 时 touched 不响应、不高亮；
## 解锁时由流程脚本调 set_interaction_enabled(true)）
@export var interactable: bool = true

## GameState 状态键（godot_c2_c4_prompt §2：非空时状态机由 GameState 统一监控管理——
## set_state 写 GameState.set_object_state(state_id, str(state))；_ready 按存档恢复，恢复不发信号）
@export var state_id: String = ""

## 玩家是否处于交互范围内（body_entered/exited 跟踪；供高亮与子类范围判定复用）
var player_in_range: bool = false

@export_category("Interaction SFX")
## 可选的交互成功音效（merge 自 Spine_to_merge）。留空时仍会发出 interaction_sfx_requested，但不会创建播放器。
@export var interaction_sfx_stream: AudioStream
## 音效总线不存在时回退到 Master，避免白模/不同项目配置下报错。
@export var interaction_sfx_bus: StringName = &"Master"
@export_range(-80.0, 6.0, 0.1) var interaction_sfx_volume_db: float = 0.0

## 外部交互开关（流程可调用 set_interaction_enabled）。false 时 touched() 不触发。
var _interaction_enabled: bool = true

## 信号：交互可用性变化（gate 满足/不满足、set_interaction_enabled 切换时发射），供 E 提示/遮罩/特效联动。
signal interaction_available(enabled: bool)

## 信号：gate 未满足、交互被阻止时发射。
signal gate_blocked

## 信号：确定交互成功（gate 满足 且 _try_touch 消费成功）后发射，供 'ok' 占位提示/特效联动。
signal interaction_succeeded

## 信号：交互成功后的音效占位请求（merge 自 Spine_to_merge）。外部音频管理器可监听此信号；无资源时也安全发射。
signal interaction_sfx_requested

## 信号：可选音频资源实际开始播放时发射。
signal interaction_sfx_played

## 状态机当前状态（int；状态集合由子类定义）
var current_state: int = 0

var _interaction_sfx_player: AudioStreamPlayer

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	current_state = initial_state
	# 按存档恢复（直接赋值不走 set_state：不发 state_changed、不连锁触发，恢复交由场景脚本重建）
	if state_id != "":
		var saved := GameState.get_object_state(state_id)
		if saved != "":
			current_state = int(saved)
	_interaction_enabled = interactable
	_sync_collision_shape()
	_setup_force_trigger()
	_setup_interaction_sfx()
	_apply_state_table(current_state)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# 初始化后广播当前交互可用性（供 ItemMarker 等门控联动；与 E 提示「靠近才显示」独立）
	interaction_available.emit(is_interaction_available())


## 高亮开关：提亮 / 恢复常态（godot_c3_prompt §3，能力下沉基类供所有子类复用）
func set_highlight(on: bool) -> void:
	modulate = highlight_modulate if on else Color.WHITE


## 玩家进入范围：更新标志并按 highlight_enabled 自动提亮（不可交互时不高亮）
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true
		if highlight_enabled and _interaction_enabled:
			set_highlight(true)


## 玩家离开范围：更新标志并立即恢复常态
func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		if highlight_enabled:
			set_highlight(false)


## 把 size 同步到子节点 CollisionShape2D 的 RectangleShape2D（节点名沿用 player.tscn 惯例）
## 子类覆写 _ready 时必须先调用 super._ready()。
func _sync_collision_shape() -> void:
	if _collision_shape == null:
		return
	var shape: Shape2D = _collision_shape.shape
	if shape is RectangleShape2D:
		shape.size = size


## 解析 force_trigger_node；若为 Area2D 则连接其 body_entered，判 body is Player → 强制触发。
## 强制触发无视 gate / 输入锁（规格②）。
func _setup_force_trigger() -> void:
	if force_trigger_node == NodePath():
		return
	if force_trigger_state < 0:
		return
	var node := get_node_or_null(force_trigger_node)
	if node is Area2D:
		node.body_entered.connect(_on_force_trigger_body_entered)


func _on_force_trigger_body_entered(body: Node2D) -> void:
	if body is Player:
		call_item(force_trigger_state)


## 状态变更唯一入口：记录状态 + 同步 GameState（state_id 非空时）+ 调 apply_state() 应用效果
func set_state(new_state: int) -> void:
	current_state = new_state
	if state_id != "":
		GameState.set_object_state(state_id, str(new_state))
	apply_state(new_state)


## 状态效果唯一出口：默认按 states 表实现（位置/尺寸/颜色/贴图）。子类可整段覆写。
func apply_state(new_state: int) -> void:
	_apply_state_table(new_state)


## 按 states 表应用目标状态配置（基类默认实现；对 set_state 边界保持不写全局状态）。
func _apply_state_table(new_state: int) -> void:
	var config: Dictionary = states.get(new_state, {}) if states.has(new_state) else {}
	if config.has("position"):
		position = config["position"]
	if config.has("size"):
		if _collision_shape != null:
			var shape: Shape2D = _collision_shape.shape
			if shape is RectangleShape2D:
				shape.size = config["size"]
	if config.has("color"):
		for child in get_children():
			if child is Polygon2D:
				child.color = config["color"]
	if config.has("texture"):
		var sprite := get_node_or_null("Sprite2D")
		if sprite is Sprite2D:
			sprite.texture = load(config["texture"])


## 交互触发入口（E 键经 Player.interact_pressed 信号触发）：默认实现，子类**应覆写 _try_touch() 而非 touched()**。
## 触发前先做 gate / 交互开关检查（规格②：gate 未满足不触发并发射 gate_blocked）。
## ⚠ 注意：若子类直接覆写 touched()（如早期 TestItem），会绕过本 gate 门控逻辑；新子类请覆写 _try_touch()。
func touched() -> void:
	if not _interaction_enabled:
		interaction_available.emit(false)
		return
	if gate_flag != "" and not GameState.get_process_flag(gate_flag):
		gate_blocked.emit()
		interaction_available.emit(false)
		return
	if not _try_touch():
		return
	interaction_available.emit(true)
	interaction_succeeded.emit()
	_request_interaction_sfx()


## 初始化可选音效播放器（merge 自 Spine_to_merge）。没有 stream 时不创建节点，保留纯白模零音频行为。
func _setup_interaction_sfx() -> void:
	var existing_player := get_node_or_null("InteractionSfxPlayer") as AudioStreamPlayer
	if existing_player != null:
		_interaction_sfx_player = existing_player
	elif interaction_sfx_stream != null:
		_interaction_sfx_player = AudioStreamPlayer.new()
		_interaction_sfx_player.name = "InteractionSfxPlayer"
		add_child(_interaction_sfx_player)
	else:
		return
	if interaction_sfx_stream != null:
		_interaction_sfx_player.stream = interaction_sfx_stream
	_interaction_sfx_player.volume_db = interaction_sfx_volume_db
	if AudioServer.get_bus_index(interaction_sfx_bus) >= 0:
		_interaction_sfx_player.bus = interaction_sfx_bus
	else:
		_interaction_sfx_player.bus = &"Master"


## 发出统一音效占位请求，并在配置资源时播放音效；默认空资源无副作用。
func _request_interaction_sfx() -> void:
	interaction_sfx_requested.emit()
	if _interaction_sfx_player == null or _interaction_sfx_player.stream == null:
		return
	_interaction_sfx_player.play()
	interaction_sfx_played.emit()


## 子类覆写的实际触发逻辑（touched 通过 gate/交互开关检查后调用）。默认空。
## 返回 true 表示本次触发已消费（用于 interaction_available(true) 联动）。
## **新子类应覆写本方法而非 touched()**，以便完整走 gate 门控链路。
func _try_touch() -> bool:
	return false


## 外部程序化入口：显式指定目标状态（命名避开内建 call()）；无范围判定、无输入锁检查
func call_item(new_state: int) -> void:
	set_state(new_state)


## 当前交互是否可用（交互开关开启 且 gate 满足）。供 ItemMarker 等门控联动读取。
func is_interaction_available() -> bool:
	var gate_ok := true
	if gate_flag != "":
		gate_ok = GameState.get_process_flag(gate_flag)
	return _interaction_enabled and gate_ok


## 统一的玩家范围判定（merge 自 Spine_to_merge，c3 子类使用）。
##
## Item 的根节点通常只是场景锚点；白模编辑时 CollisionShape2D 会被单独移动到
## 实际可交互位置。因此所有交互消费者都必须使用碰撞形状的 global_position，不能
## 退回到 Item 根节点。矩形边界与 Godot Area2D/CharacterBody2D 的重叠语义一致，
## 同时保留 Y 轴范围约束，避免玩家只在 X 方向接近时误触发。
func is_player_in_interaction_range(player: Node2D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not _interaction_enabled or (gate_flag != "" and not GameState.get_process_flag(gate_flag)):
		return false
	if _collision_shape == null or _collision_shape.disabled:
		return false
	if _collision_shape.shape is RectangleShape2D:
		var item_shape := _collision_shape.shape as RectangleShape2D
		var item_half := item_shape.size * _collision_shape.global_scale.abs() * 0.5
		var player_shape := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var player_half := Vector2.ZERO
		if player_shape != null and not player_shape.disabled and player_shape.shape is RectangleShape2D:
			player_half = (player_shape.shape as RectangleShape2D).size * player_shape.global_scale.abs() * 0.5
		var delta := (player.global_position - _collision_shape.global_position).abs()
		var vertical_reach := item_half.y + player_half.y + maxf(vertical_interaction_padding, 0.0)
		return delta.x <= item_half.x + player_half.x and delta.y <= vertical_reach
	if self is Area2D:
		return (self as Area2D).get_overlapping_bodies().has(player)
	return global_position.distance_to(player.global_position) <= 180.0


## 外部门控：流程可调用。enabled=false 时 touched() 不触发（优先于 gate_flag）。
## 同步高亮：关闭立即恢复常态；开启时若玩家在范围内且允许高亮则补亮。
func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if not enabled:
		set_highlight(false)
	elif highlight_enabled and player_in_range:
		set_highlight(true)
	interaction_available.emit(is_interaction_available())
