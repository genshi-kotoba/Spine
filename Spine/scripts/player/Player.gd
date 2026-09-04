class_name Player
extends CharacterBody2D
## Player — 关卡场景角色
## 仅支持左右移动（A/D 或方向键），带简单重力与地面碰撞。

## 交互信号：按下 interact(E) 时发射，供 item 等低耦合监听（不写 GameState）
signal interact_pressed

@export var move_speed: float = 400.0  # user: x2 speed

## 水平加速度（像素/秒²，规格⑩，新增）：有输入时逼近 move_speed
@export var acceleration: float = 1200.0

## 地面减速（像素/秒²，规格⑩，新增）：无输入时减速至 0
@export var ground_friction: float = 1600.0

## 重力（像素/秒²）
@export var gravity: float = 980.0


func _physics_process(delta: float) -> void:
	if StoryMonitor.input_locked:
		velocity = Vector2.ZERO
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	var direction := Input.get_axis("move_left", "move_right")
	var target_speed := direction * move_speed
	var rate := acceleration if direction != 0.0 else ground_friction
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)

	move_and_slide()


## 按下 interact(E) 时发射 interact_pressed（先查输入锁；与 LevelScene 既有 E 键处理写法一致）
func _unhandled_input(event: InputEvent) -> void:
	if StoryMonitor.input_locked:
		return
	if event.is_action_pressed("interact"):
		interact_pressed.emit()
