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

	# 出生落地吸附：首帧向下发射线找地板表面，把角色贴到实际碰撞面上
	# （场景碰撞位置以运行时为准，出生 y 与地板不严格匹配时兜底）
	if not _spawn_snapped:
		_spawn_snapped = true
		_snap_to_floor()

	if not is_on_floor():
		velocity.y += gravity * delta

	var direction := Input.get_axis("move_left", "move_right")
	var target_speed := direction * move_speed
	var rate := acceleration if direction != 0.0 else ground_friction
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)

	move_and_slide()

	# TEMP debug（--debug-fall）：打印落体轨迹后退出
	if _debug_fall:
		_debug_t += delta
		if _debug_t >= 0.25:
			_debug_t = 0.0
			print("[player] pos=(%d,%d) vel=(%d,%d) on_floor=%s" % [int(global_position.x), int(global_position.y), int(velocity.x), int(velocity.y), str(is_on_floor())])
			_debug_n += 1
			if _debug_n >= 20:
				get_tree().quit()


var _debug_fall: bool = false
var _debug_t: float = 0.0
var _debug_n: int = 0
var _spawn_snapped: bool = false


## 从出生点上方垂直向下发射线，收集全部命中后取离出生点最近的 StaticBody2D 表面吸附
## （避免误站天花板/门楣等中间碰撞体）
func _snap_to_floor() -> void:
	var half_h: float = 32.0
	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if cs != null and cs.shape is RectangleShape2D:
		var rect: RectangleShape2D = cs.shape
		half_h = rect.size.y / 2.0
	var from: Vector2 = global_position + Vector2(0.0, -1000.0)
	var to: Vector2 = global_position + Vector2(0.0, 1000.0)
	var spawn_y: float = global_position.y
	var excluded: Array = [self]
	var best_y: float = 0.0
	var best_dist: float = 2000.0
	var found: bool = false
	for i: int in 8:
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
		query.exclude = excluded
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		if hit["collider"] is StaticBody2D:
			var hit_y: float = hit["position"].y
			var dist: float = absf(hit_y - spawn_y)
			if dist < best_dist:
				best_dist = dist
				best_y = hit_y
				found = true
		excluded.append(hit["collider"])
	if found:
		global_position.y = best_y - half_h
		velocity.y = 0.0
		if _debug_fall:
			print("[player] snapped to floor y=%d" % int(global_position.y))


func _ready() -> void:
	_debug_fall = OS.get_cmdline_user_args().has("--debug-fall")
	if _debug_fall:
		print("[player] mask=%d layer=%d" % [collision_mask, collision_layer])
		var floor_body := get_node_or_null("../Environment/Floor")
		if floor_body:
			print("[player] floor layer=%d mask=%d pos=%s" % [floor_body.collision_layer, floor_body.collision_mask, str(floor_body.position)])
			var cs := floor_body.get_node_or_null("CollisionShape2D")
			if cs:
				print("[player] floor shape=%s size=%s disabled=%s shape_pos=%s" % [cs.shape.get_class(), str(cs.shape.size), str(cs.disabled), str(cs.position)])
			else:
				print("[player] floor has NO CollisionShape2D")
		else:
			print("[player] Environment/Floor NOT FOUND")


## 按下 interact(E) 时发射 interact_pressed（先查输入锁；与 LevelScene 既有 E 键处理写法一致）
func _unhandled_input(event: InputEvent) -> void:
	if StoryMonitor.input_locked:
		return
	if event.is_action_pressed("interact"):
		interact_pressed.emit()
