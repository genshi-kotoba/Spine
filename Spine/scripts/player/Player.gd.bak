class_name Player
extends CharacterBody2D
## Player — 关卡场景角色
## 仅支持左右移动（A/D 或方向键），带简单重力与地面碰撞。

@export var move_speed: float = 200.0

## 重力（像素/秒²）
@export var gravity: float = 980.0


func _physics_process(delta: float) -> void:
	if StoryMonitor.input_locked:
		velocity = Vector2.ZERO
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * move_speed

	move_and_slide()
