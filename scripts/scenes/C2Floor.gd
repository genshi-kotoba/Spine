class_name C2Floor
extends FloorTemplate
## C2Floor — c2 关卡：三区域解锁流程（godot_c2_c4_prompt §3）
## kitchen 初始可见；living/study_room 初始黑暗（shader 遮罩）+ 边界阻挡，lego 与 bedroom_door 初始不可交互。
## 解锁连锁统一由本脚本监听 GameState.state_changed 驱动，item 脚本内不做互相引用。
## 读档恢复：_ready 按 GameState 既有状态重建（已消失不现、已解锁不黑）。


## 区域边界（遮罩与阻挡共用）：[x0, x1, x2, x3] → kitchen[x0,x1] / living[x1,x2] / study_room[x2,x3]
@export var zone_boundaries: PackedFloat32Array = [0.0, 1280.0, 2560.0, 3840.0]

const ID_CANDLE := "c2_candle"
const ID_STAR := "c2_star"
const ID_LEGO1 := "c2_lego1"
const ID_LEGO2 := "c2_lego2"
const ID_LEGO3 := "c2_lego3"

const ZONE_TOP := 211.0
const ZONE_HEIGHT := 817.0
const BLOCKER_Y := 868.0

@onready var _mask_living: ColorRect = $DarknessMasks/MaskLiving
@onready var _mask_study: ColorRect = $DarknessMasks/MaskStudy
@onready var _blocker_living: StaticBody2D = $ZoneBlockers/BlockerLiving
@onready var _blocker_study: StaticBody2D = $ZoneBlockers/BlockerStudy
@onready var _bedroom_door: Area2D = $Doors/BedroomDoor
@onready var _lego1: Area2D = $Items/Lego1
@onready var _lego2: Area2D = $Items/Lego2
@onready var _lego3: Area2D = $Items/Lego3


func _ready() -> void:
	super._ready()
	_layout_zones()
	GameState.state_changed.connect(_on_state_changed)
	_apply_saved_progress()


## 按 zone_boundaries 摆放遮罩与阻挡（配置改动只调导出变量）
func _layout_zones() -> void:
	var x1: float = zone_boundaries[1]
	var x2: float = zone_boundaries[2]
	var x3: float = zone_boundaries[3]
	if _mask_living != null:
		_mask_living.position = Vector2(x1, ZONE_TOP)
		_mask_living.size = Vector2(x2 - x1, ZONE_HEIGHT)
	if _mask_study != null:
		_mask_study.position = Vector2(x2, ZONE_TOP)
		_mask_study.size = Vector2(x3 - x2, ZONE_HEIGHT)
	if _blocker_living != null:
		_blocker_living.position = Vector2(x1, BLOCKER_Y)
	if _blocker_study != null:
		_blocker_study.position = Vector2(x2, BLOCKER_Y)


func _on_state_changed(object_id: String, new_state: String) -> void:
	if new_state != "1":
		return
	match object_id:
		ID_CANDLE:
			_unlock_living()
		ID_STAR:
			_unlock_study()
		ID_LEGO1, ID_LEGO2, ID_LEGO3:
			_check_door_unlock()


## 读档恢复：按 GameState 既有状态重建区域与门（已解锁的区域不再黑暗/阻挡）
func _apply_saved_progress() -> void:
	if GameState.get_object_state(ID_CANDLE) == "1":
		_unlock_living()
	if GameState.get_object_state(ID_STAR) == "1":
		_unlock_study()
	_check_door_unlock()


## candle 已交互：living 黑暗遮罩移除 + 边界阻挡移除
func _unlock_living() -> void:
	if _mask_living != null:
		_mask_living.queue_free()
		_mask_living = null
	if _blocker_living != null:
		_blocker_living.queue_free()
		_blocker_living = null


## star 已交互：study_room 黑暗移除 + 阻挡移除 + 三个 lego 变为可交互
func _unlock_study() -> void:
	if _mask_study != null:
		_mask_study.queue_free()
		_mask_study = null
	if _blocker_study != null:
		_blocker_study.queue_free()
		_blocker_study = null
	for lego in [_lego1, _lego2, _lego3]:
		if lego != null:
			lego.set_interaction_enabled(true)


## 三个 lego 全部已交互 → bedroom_door 变为可交互（高亮提示随范围进出自动恢复）
func _check_door_unlock() -> void:
	if _bedroom_door == null:
		return
	if GameState.get_object_state(ID_LEGO1) == "1" \
			and GameState.get_object_state(ID_LEGO2) == "1" \
			and GameState.get_object_state(ID_LEGO3) == "1":
		_bedroom_door.set_interaction_enabled(true)
