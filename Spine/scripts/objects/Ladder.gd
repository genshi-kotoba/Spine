class_name Ladder
extends Node2D
## Ladder — c2 梯子（docs/c2_refactor_constraints.md §4.1）
## 四态状态机由 GameState 统一监控管理：key "c2_ladder"，值 "0"~"3"。
## 状态推进唯一入口 advance_state()；贴图切换唯一出口 apply_state()。
## 不可交互：无 touched、无高亮、无碰撞、不响应 E。
## 读档恢复：_ready 按 GameState 已有状态重建贴图（不回写存档）。

## GameState 状态键
const STATE_KEY: String = "c2_ladder"

## 状态 → 贴图（状态 0 = 无贴图；资源已存在，可安全 preload）
const TEXTURES: Dictionary = {
	1: preload("res://assets/sprites/ladder1.png"),
	2: preload("res://assets/sprites/ladder2.png"),
	3: preload("res://assets/sprites/ladder3.png"),
}

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)
	# 读档恢复：空串按 0 处理（不回写，避免污染存档）
	var saved: String = GameState.get_object_state(STATE_KEY)
	var state: int = 0
	if saved != "":
		state = int(saved)
	apply_state(state)


## 状态推进唯一入口：当前值 +1（封顶 3，到顶直接返回），写回 GameState
func advance_state() -> void:
	var saved: String = GameState.get_object_state(STATE_KEY)
	var state: int = 0
	if saved != "":
		state = int(saved)
	state = min(state + 1, 3)
	if saved == str(state):
		return
	GameState.set_object_state(STATE_KEY, str(state))


func _on_state_changed(object_id: String, new_state: String) -> void:
	if object_id == STATE_KEY:
		apply_state(int(new_state))


## 贴图切换唯一出口：状态变 → 贴图必变，不允许绕过
func apply_state(state: int) -> void:
	if _sprite == null:
		return
	if state == 0:
		_sprite.texture = null
	elif TEXTURES.has(state):
		_sprite.texture = TEXTURES[state]
