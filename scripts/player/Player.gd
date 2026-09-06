class_name Player
extends CharacterBody2D
## Player — 关卡场景角色
## 仅支持左右移动（A/D 或方向键），带简单重力与地面碰撞。
## v2 动画（docs/player_animation_constraints.md）：朝向状态机（facing LEFT/RIGHT，
## 唯一来源 = 移动输入轴非零）+ walk/static 动画切换；flip_h 唯一出口 _apply_facing()。

const PlayerMotionProfileResource = preload("res://scripts/player/PlayerMotionProfile.gd")

## 交互信号：按下 interact(E) 时发射，供 item 等低耦合监听（不写 GameState）
signal interact_pressed

## 朝向状态机：运行态，不写 GameState、不入存档，场景载入重置 RIGHT
enum Facing { LEFT, RIGHT }

## 动画名（player.tscn SpriteFrames）
const STATIC_ANIM: StringName = &"static"
const WALK_ANIM: StringName = &"walk"
## is_moving 判定阈值（px/s，v2 §6）
const MOVE_ANIM_THRESHOLD: float = 10.0

## 当前朝向（初始 RIGHT；只随非零移动输入变化，松手/锁输入/顶墙保持不变）
var _facing: int = Facing.RIGHT

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

## 所有层默认共用 player.tscn 绑定的时间制运动配置（merge 自 Spine_to_merge）；需要例外时复制 .tres 再覆写。
@export var motion_profile: PlayerMotionProfileResource

## 以下字段仅供尚未迁移的手工 Player 实例回退使用，新关卡不要再以 px/s² 调参。
@export_category("Legacy fallback")
@export var move_speed: float = 400.0  # user: x2 speed
@export var acceleration: float = 1200.0
@export var ground_friction: float = 1600.0

## 重力（像素/秒²）
@export var gravity: float = 980.0

## 反向过程中即使速度穿过 0 也保持反向速率，直到抵达新的目标速度。
var _reversal_active := false

## A direction key pressed while a cutscene is active must not become a movement
## impulse on the first unlocked physics frame. The direction has to be released
## before normal movement can be re-armed.
var _movement_rearm_required := false

## The source PNGs share a canvas but their opaque bounds differ by a couple of
## pixels. Keep the visual foot line stable when AnimatedSprite2D changes frame.
var _sprite_base_position: Vector2 = Vector2.ZERO
var _frame_anchor_offsets: Dictionary = {}
var _last_anchor_key: String = ""


func suspend_movement_until_released() -> void:
	velocity = Vector2.ZERO
	_reversal_active = false
	_movement_rearm_required = not is_zero_approx(Input.get_axis("move_left", "move_right"))


func _physics_process(delta: float) -> void:
	if StoryMonitor.input_locked:
		velocity = Vector2.ZERO
		_reversal_active = false
		if not is_zero_approx(Input.get_axis("move_left", "move_right")):
			_movement_rearm_required = true
		# 锁输入：velocity 清零 → 动画自然回落 static，朝向不变
		_update_animation()
		return

	var direction := Input.get_axis("move_left", "move_right")
	if _movement_rearm_required:
		velocity = Vector2.ZERO
		_reversal_active = false
		_update_animation()
		if is_zero_approx(direction):
			_movement_rearm_required = false
		return

	# 出生落地吸附：首帧向下发射线找地板表面，把角色贴到实际碰撞面上
	# （场景碰撞位置以运行时为准，出生 y 与地板不严格匹配时兜底）
	if not _spawn_snapped:
		_spawn_snapped = true
		_snap_to_floor()

	if not is_on_floor():
		velocity.y += _get_gravity() * delta

	# 朝向更新唯一来源：非零移动输入；松手/顶墙/锁输入保持原朝向
	if not is_zero_approx(direction):
		var new_facing: int = Facing.RIGHT if direction > 0.0 else Facing.LEFT
		if new_facing != _facing:
			_facing = new_facing
			_apply_facing()
	velocity.x = _approach_horizontal_velocity(direction, delta)

	move_and_slide()
	_update_animation()

	# TEMP debug（--debug-fall）：打印落体轨迹后退出
	if _debug_fall:
		_debug_t += delta
		if _debug_t >= 0.25:
			_debug_t = 0.0
			print("[player] pos=(%d,%d) vel=(%d,%d) on_floor=%s" % [int(global_position.x), int(global_position.y), int(velocity.x), int(velocity.y), str(is_on_floor())])
			_debug_n += 1
			if _debug_n >= 20:
				get_tree().quit()


## 统一的横向速度逼近点（merge 自 Spine_to_merge）。profile 使用“耗时”而非 px/s²，便于跨层共享与美术/关卡协作调参。
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


## flip_h 唯一出口（v2 §4）：素材原始朝左，RIGHT=反转、LEFT=原样；对全部动画帧统一生效
func _apply_facing() -> void:
	if _sprite != null:
		_sprite.flip_h = (_facing == Facing.RIGHT)


## walk/static 动画切换（v2 §6）：is_moving = |velocity.x| > 阈值；同动画不重复 play 防帧序号归零
func _update_animation() -> void:
	if _sprite == null:
		return
	var target: StringName = WALK_ANIM if absf(velocity.x) > MOVE_ANIM_THRESHOLD else STATIC_ANIM
	if _sprite.animation != target or not _sprite.is_playing():
		_sprite.play(target)


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
	_sprite_base_position = _sprite.position
	_build_frame_anchor_offsets()
	# 初始朝向 RIGHT：素材朝左 → 反转显示（flip_h 唯一出口）
	_apply_facing()
	_sync_sprite_frame_anchor()
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


func _process(_delta: float) -> void:
	_sync_sprite_frame_anchor()


func _build_frame_anchor_offsets() -> void:
	_frame_anchor_offsets.clear()
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var baseline_texture: Texture2D = _sprite.sprite_frames.get_frame_texture(STATIC_ANIM, 0)
	var baseline_rect := _texture_used_rect(baseline_texture)
	if baseline_rect.size == Vector2i.ZERO:
		return
	var baseline_bottom: float = float(baseline_rect.position.y + baseline_rect.size.y)
	var baseline_center_x: float = float(baseline_rect.position.x) + float(baseline_rect.size.x) * 0.5
	var scale_x: float = absf(_sprite.scale.x)
	var scale_y: float = absf(_sprite.scale.y)
	for animation_name: StringName in [STATIC_ANIM, WALK_ANIM]:
		var frame_count: int = _sprite.sprite_frames.get_frame_count(animation_name)
		for frame_index: int in frame_count:
			var texture: Texture2D = _sprite.sprite_frames.get_frame_texture(animation_name, frame_index)
			var used_rect := _texture_used_rect(texture)
			if used_rect.size == Vector2i.ZERO:
				continue
			var bottom: float = float(used_rect.position.y + used_rect.size.y)
			var center_x: float = float(used_rect.position.x) + float(used_rect.size.x) * 0.5
			var source_offset := Vector2(baseline_center_x - center_x, baseline_bottom - bottom)
			_frame_anchor_offsets[_frame_anchor_key(animation_name, frame_index)] = Vector2(
				source_offset.x * scale_x,
				source_offset.y * scale_y
			)


func _texture_used_rect(texture: Texture2D) -> Rect2i:
	if texture == null:
		return Rect2i()
	var image: Image = texture.get_image()
	return image.get_used_rect() if image != null else Rect2i()


func _frame_anchor_key(animation_name: StringName, frame_index: int) -> String:
	return "%s:%d" % [String(animation_name), frame_index]


func _sync_sprite_frame_anchor() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var frame_key := _frame_anchor_key(_sprite.animation, _sprite.frame)
	var key := "%s:%s" % [frame_key, "flip" if _sprite.flip_h else "normal"]
	if key == _last_anchor_key:
		return
	_last_anchor_key = key
	var offset: Vector2 = _frame_anchor_offsets.get(frame_key, Vector2.ZERO)
	if _sprite.flip_h:
		offset.x = -offset.x
	_sprite.position = _sprite_base_position + offset


## 按下 interact(E) 时发射 interact_pressed（先查输入锁；与 LevelScene 既有 E 键处理写法一致）
func _unhandled_input(event: InputEvent) -> void:
	if StoryMonitor.input_locked:
		return
	if event.is_action_pressed("interact"):
		interact_pressed.emit()
