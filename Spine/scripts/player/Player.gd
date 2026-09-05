class_name Player
extends CharacterBody2D
## Player — 关卡场景角色
## 仅支持左右移动（A/D 或方向键），带简单重力与地面碰撞。

const PlayerMotionProfileResource = preload("res://scripts/player/PlayerMotionProfile.gd")

## 交互信号：按下 interact(E) 时发射，供 item 等低耦合监听（不写 GameState）
signal interact_pressed

## 所有层默认共用 player.tscn 绑定的时间制运动配置；需要例外时复制 .tres 再覆写。
@export var motion_profile: PlayerMotionProfileResource

## 以下字段仅供尚未迁移的手工 Player 实例回退使用，新关卡不要再以 px/s² 调参。
@export_category("Legacy fallback")
@export var move_speed: float = 400.0
@export var acceleration: float = 1200.0
@export var ground_friction: float = 1600.0
@export var gravity: float = 980.0

## 反向过程中即使速度穿过 0 也保持反向速率，直到抵达新的目标速度。
var _reversal_active := false


func _physics_process(delta: float) -> void:
	if StoryMonitor.input_locked:
		velocity = Vector2.ZERO
		_reversal_active = false
		return

	if not is_on_floor():
		velocity.y += _get_gravity() * delta

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = _approach_horizontal_velocity(direction, delta)

	move_and_slide()


## 统一的横向速度逼近点。profile 使用“耗时”而非 px/s²，便于跨层共享与美术/关卡协作调参。
func _approach_horizontal_velocity(direction: float, delta: float) -> float:
	if motion_profile != null:
		if is_zero_approx(direction):
			_reversal_active = false
		elif not _reversal_active and not is_zero_approx(velocity.x) and signf(velocity.x) != signf(direction):
			_reversal_active = true
		var target_velocity := direction * motion_profile.max_speed
		var next_velocity := motion_profile.approach_horizontal_velocity(velocity.x, direction, delta, _reversal_active)
		if _reversal_active and is_equal_approx(next_velocity, target_velocity):
			_reversal_active = false
		return next_velocity
	var target_speed := direction * move_speed
	var rate := acceleration if direction != 0.0 else ground_friction
	return move_toward(velocity.x, target_speed, rate * delta)


func _get_gravity() -> float:
	return motion_profile.gravity if motion_profile != null else gravity


## 按下 interact(E) 时发射 interact_pressed（先查输入锁；与 LevelScene 既有 E 键处理写法一致）
func _unhandled_input(event: InputEvent) -> void:
	if StoryMonitor.input_locked:
		return
	if event.is_action_pressed("interact"):
		interact_pressed.emit()
