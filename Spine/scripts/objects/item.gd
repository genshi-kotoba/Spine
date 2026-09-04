class_name Item
extends Area2D
## Item — 可交互物品基类
## 所有 item 子类必须继承本基类；用 Area2D 做碰撞范围检测。
## 状态机：current_state(int) 为唯一状态；set_state() 是唯一变更入口，
## apply_state() 是唯一效果出口；touched()/call_item() 最终汇入 set_state()。
## 本类与既有可交互对象体系并行、相互独立：本类不写全局状态、不参与存档。

## 包含范围（检测矩形）：决定 CollisionShape2D 的 RectangleShape2D size；_ready 时同步
@export var size: Vector2 = Vector2(64, 64)

## 状态机当前状态（int；状态集合由子类定义）
var current_state: int = 0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_sync_collision_shape()


## 把 size 同步到子节点 CollisionShape2D 的 RectangleShape2D（节点名沿用 player.tscn 惯例）
## 子类覆写 _ready 时必须先调用 super._ready()。
func _sync_collision_shape() -> void:
	if _collision_shape == null:
		return
	var shape: Shape2D = _collision_shape.shape
	if shape is RectangleShape2D:
		shape.size = size


## 状态变更唯一入口：记录状态 + 调 apply_state() 应用效果
func set_state(new_state: int) -> void:
	current_state = new_state
	apply_state(new_state)


## 状态效果唯一出口：默认空实现，子类覆写
func apply_state(new_state: int) -> void:
	pass


## 交互触发入口（E 键经 Player.interact_pressed 信号触发）：默认空实现，子类覆写
func touched() -> void:
	pass


## 外部程序化入口：显式指定目标状态（命名避开内建 call()）；无范围判定、无输入锁检查
func call_item(new_state: int) -> void:
	set_state(new_state)
