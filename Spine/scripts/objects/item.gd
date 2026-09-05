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

## 外部交互开关（流程可调用 set_interaction_enabled）。false 时 touched() 不触发。
var _interaction_enabled: bool = true

## 信号：交互可用性变化（gate 满足/不满足、set_interaction_enabled 切换时发射），供 E 提示/遮罩/特效联动。
signal interaction_available(enabled: bool)

## 信号：gate 未满足、交互被阻止时发射。
signal gate_blocked

## 信号：确定交互成功（gate 满足 且 _try_touch 消费成功）后发射，供 'ok' 占位提示/特效联动。
signal interaction_succeeded

## 状态机当前状态（int；状态集合由子类定义）
var current_state: int = 0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	current_state = initial_state
	_sync_collision_shape()
	_setup_force_trigger()
	_apply_state_table(initial_state)
	# 初始化后广播当前交互可用性（供 ItemMarker 等门控联动；与 E 提示「靠近才显示」独立）
	interaction_available.emit(is_interaction_available())


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


## 状态变更唯一入口：记录状态 + 调 apply_state() 应用效果
func set_state(new_state: int) -> void:
	current_state = new_state
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


## 外部门控：流程可调用。enabled=false 时 touched() 不触发（优先于 gate_flag）。
func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	interaction_available.emit(is_interaction_available())
