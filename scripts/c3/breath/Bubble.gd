class_name Bubble
extends Node2D
## Floating breath vessel: remaining liquid is the countdown, and depletion produces a short burst.

const POP_RING_TEXTURE: Texture2D = preload("res://assets/fx/bubble_pop_ring.png")

@export var radius: float = 26.0
@export var rim_color: Color = Color(0.50, 0.82, 1.0, 0.90)
@export var liquid_color: Color = Color(0.16, 0.58, 1.0, 0.62)
@export var highlight_color: Color = Color(0.88, 0.97, 1.0, 0.92)
@export var follow_offset: Vector2 = Vector2(48, -34)
@export var follow_spring: float = 20.0
@export var follow_damping: float = 6.5
@export var bob_amount: float = 5.0
@export var bob_frequency: float = 1.35
@export var pop_anim_time: float = 0.36
@export var restore_anim_time: float = 0.32
@export var restore_min_scale: float = 0.76
@export var restore_scale_overshoot: float = 0.045
@export var pop_droplet_count: int = 14
@export var pop_droplet_speed_min: float = 72.0
@export var pop_droplet_speed_max: float = 180.0
@export var pop_droplet_gravity: float = 300.0
@export var player_path: NodePath
## Optional visual anchor under the player (normally AnimatedSprite2D). Using the
## sprite anchor keeps the vessel beside the large character artwork rather than
## at the CharacterBody2D feet/origin.
@export var follow_anchor_path: NodePath

var _player: Node2D = null
var _follow_anchor: Node2D = null
var _liquid_fraction: float = 1.0
var _follow_velocity := Vector2.ZERO
var _time: float = 0.0
var _popping := false
var _pop_elapsed: float = 0.0
var _droplets: Array[Dictionary] = []
var _pop_ring: Sprite2D = null
var _restoring := false
var _restore_elapsed: float = 0.0
var _restore_from_fraction: float = 1.0
var _restore_target_fraction: float = 1.0
var _rest_scale := Vector2.ONE


func _ready() -> void:
	_rest_scale = scale
	_resolve_player()
	_build_pop_ring()
	_snap_to_follow_target()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _popping:
		_update_pop(delta)
	else:
		_update_follow(delta)
		_update_restore(delta)
	queue_redraw()


## Restores a full vessel with a liquid refill and a brief elastic return after a breath.
func restore() -> void:
	var start_fraction := _liquid_fraction if visible and not _popping else 0.0
	_popping = false
	_pop_elapsed = 0.0
	_droplets.clear()
	_follow_velocity = Vector2.ZERO
	visible = true
	_restoring = true
	_restore_elapsed = 0.0
	_restore_from_fraction = clampf(start_fraction, 0.0, 1.0)
	_restore_target_fraction = 1.0
	_liquid_fraction = _restore_from_fraction
	scale = _rest_scale * clampf(restore_min_scale, 0.05, 1.0)
	if _pop_ring != null:
		_pop_ring.visible = false
	_snap_to_follow_target()
	queue_redraw()


## Starts the bubble burst at its current inertial position. The Bubble remains visible until the effect completes.
func pop() -> void:
	if _popping:
		return
	_restoring = false
	scale = _rest_scale
	_liquid_fraction = 0.0
	_popping = true
	_pop_elapsed = 0.0
	_follow_velocity = Vector2.ZERO
	_spawn_droplets()
	if _pop_ring != null:
		_pop_ring.visible = true
		_pop_ring.scale = Vector2.ONE * 0.075
		_pop_ring.modulate = _with_alpha(highlight_color, 0.95)
	queue_redraw()


## Immediate, manual capacity write. This deliberately cancels an in-progress recovery.
func set_liquid_fraction(fraction: float) -> void:
	if _popping:
		return
	_restoring = false
	_restore_target_fraction = clampf(fraction, 0.0, 1.0)
	_liquid_fraction = clampf(fraction, 0.0, 1.0)
	scale = _rest_scale
	queue_redraw()


## Countdown writes keep the recovery animation alive while updating its destination capacity.
func set_countdown_fraction(fraction: float) -> void:
	if _popping:
		return
	_restore_target_fraction = clampf(fraction, 0.0, 1.0)
	if not _restoring:
		_liquid_fraction = _restore_target_fraction
		queue_redraw()


func get_liquid_fraction() -> float:
	return _liquid_fraction


## Compatibility with the earlier API. "Air" now means remaining vessel capacity.
func set_air_fraction(fraction: float) -> void:
	set_liquid_fraction(fraction)


func get_air_fraction() -> float:
	return get_liquid_fraction()


func is_popping() -> bool:
	return _popping


func is_recovering() -> bool:
	return _restoring


func get_follow_velocity() -> Vector2:
	return _follow_velocity


func _update_follow(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	if _player == null:
		return
	var target := _follow_target()
	_follow_velocity += (target - global_position) * follow_spring * delta
	_follow_velocity *= exp(-follow_damping * delta)
	global_position += _follow_velocity * delta


func _update_restore(delta: float) -> void:
	if not _restoring:
		return
	_restore_elapsed += delta
	var progress := clampf(_restore_elapsed / maxf(restore_anim_time, 0.001), 0.0, 1.0)
	var fill_progress := _ease_out_cubic(progress)
	_liquid_fraction = lerpf(_restore_from_fraction, _restore_target_fraction, fill_progress)
	var scale_progress := lerpf(clampf(restore_min_scale, 0.05, 1.0), 1.0, fill_progress)
	# Only a small crest at mid-animation makes the refill feel buoyant without changing the vessel's final size.
	scale = _rest_scale * (scale_progress + sin(progress * PI) * maxf(restore_scale_overshoot, 0.0))
	if progress >= 1.0:
		_restoring = false
		_liquid_fraction = _restore_target_fraction
		scale = _rest_scale


func _update_pop(delta: float) -> void:
	_pop_elapsed += delta
	for droplet in _droplets:
		var velocity: Vector2 = droplet["velocity"]
		velocity.y += pop_droplet_gravity * delta
		droplet["velocity"] = velocity
		droplet["position"] = (droplet["position"] as Vector2) + velocity * delta
		droplet["life"] = float(droplet["life"]) - delta
	var progress := clampf(_pop_elapsed / maxf(pop_anim_time, 0.001), 0.0, 1.0)
	if _pop_ring != null:
		_pop_ring.scale = Vector2.ONE * lerpf(0.075, 0.19, _ease_out_cubic(progress))
		_pop_ring.modulate = _with_alpha(highlight_color, pow(1.0 - progress, 2.0))
	if progress >= 1.0:
		_popping = false
		_droplets.clear()
		if _pop_ring != null:
			_pop_ring.visible = false
		visible = false


func _draw() -> void:
	if _popping:
		_draw_pop_droplets()
		return
	_draw_vessel()


func _draw_vessel() -> void:
	var inner_radius := maxf(radius - 2.5, 1.0)
	_draw_liquid(inner_radius)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, _with_alpha(rim_color, 0.90), 2.0, true)
	draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 48, _with_alpha(highlight_color, 0.20), 1.0, true)
	draw_arc(Vector2(-radius * 0.18, -radius * 0.16), radius * 0.62, PI * 1.05, PI * 1.63, 20, _with_alpha(highlight_color, 0.82), 2.0, true)
	draw_circle(Vector2(-radius * 0.30, -radius * 0.32), radius * 0.10, _with_alpha(highlight_color, 0.60))


func _draw_liquid(inner_radius: float) -> void:
	if _liquid_fraction <= 0.001:
		return
	var top_y := lerpf(inner_radius, -inner_radius, _liquid_fraction)
	var rows := 30
	for row in range(rows):
		var t := float(row) / float(rows - 1)
		var y := lerpf(top_y, inner_radius, t)
		var half_width := sqrt(maxf(inner_radius * inner_radius - y * y, 0.0))
		var row_alpha := 0.26 + 0.38 * _liquid_fraction
		draw_line(Vector2(-half_width, y), Vector2(half_width, y), _with_alpha(liquid_color, row_alpha), 1.8, true)
	var surface_width := sqrt(maxf(inner_radius * inner_radius - top_y * top_y, 0.0))
	if surface_width <= 0.5:
		return
	var wave := PackedVector2Array()
	for index in range(13):
		var t := float(index) / 12.0
		var x := lerpf(-surface_width, surface_width, t)
		wave.append(Vector2(x, top_y + sin(_time * 4.0 + t * TAU * 1.5) * 1.2))
	draw_polyline(wave, _with_alpha(highlight_color, 0.58), 1.25, true)


func _draw_pop_droplets() -> void:
	for droplet in _droplets:
		var life := maxf(float(droplet["life"]), 0.0)
		var size := float(droplet["size"])
		draw_circle(droplet["position"], size * life / maxf(pop_anim_time, 0.001), _with_alpha(liquid_color, minf(life / maxf(pop_anim_time, 0.001), 1.0)))


func _spawn_droplets() -> void:
	_droplets.clear()
	for index in range(maxi(pop_droplet_count, 1)):
		var angle := TAU * float(index) / float(maxi(pop_droplet_count, 1)) + randf_range(-0.18, 0.18)
		var speed := randf_range(pop_droplet_speed_min, pop_droplet_speed_max)
		_droplets.append({
			"position": Vector2.from_angle(angle) * randf_range(radius * 0.15, radius * 0.55),
			"velocity": Vector2.from_angle(angle) * speed + Vector2(0.0, -35.0),
			"size": randf_range(1.8, 4.6),
			"life": pop_anim_time * randf_range(0.55, 1.0)
		})


func _build_pop_ring() -> void:
	_pop_ring = get_node_or_null("PopRing") as Sprite2D
	if _pop_ring == null:
		_pop_ring = Sprite2D.new()
		_pop_ring.name = "PopRing"
		add_child(_pop_ring)
	_pop_ring.texture = POP_RING_TEXTURE
	_pop_ring.visible = false
	_pop_ring.z_index = 2


func _follow_target() -> Vector2:
	var anchor_position := _player.global_position
	if _follow_anchor != null and is_instance_valid(_follow_anchor):
		anchor_position = _follow_anchor.global_position
	return anchor_position + follow_offset + Vector2(
		sin(_time * bob_frequency * TAU) * bob_amount * 0.45,
		cos(_time * bob_frequency * TAU) * bob_amount
	)


func _snap_to_follow_target() -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	if _player != null:
		global_position = _follow_target()


func _ease_out_cubic(value: float) -> float:
	var inverse := 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - inverse * inverse * inverse


func _with_alpha(source: Color, alpha: float) -> Color:
	return Color(source.r, source.g, source.b, clampf(alpha, 0.0, 1.0))


func _resolve_player() -> void:
	if player_path != NodePath():
		var node := get_node_or_null(player_path)
		if node is Node2D:
			_player = node as Node2D
			_resolve_follow_anchor()
			return
	var group_player := get_tree().get_first_node_in_group("player")
	if group_player is Node2D:
		_player = group_player as Node2D
		_resolve_follow_anchor()
		return
	_player = _scan_for_player(get_tree().current_scene)
	_resolve_follow_anchor()


## BreathSystem uses this explicit handoff so a stale scene path cannot leave the
## vessel following a preview/legacy Player instance.
func set_player(target: Node2D) -> void:
	_player = target
	_resolve_follow_anchor()
	_snap_to_follow_target()


func _resolve_follow_anchor() -> void:
	_follow_anchor = null
	if _player == null or not is_instance_valid(_player):
		return
	if follow_anchor_path != NodePath():
		var explicit_anchor := get_node_or_null(follow_anchor_path)
		if explicit_anchor is Node2D:
			_follow_anchor = explicit_anchor as Node2D
			return
	var sprite := _player.get_node_or_null("AnimatedSprite2D")
	if sprite is Node2D:
		_follow_anchor = sprite as Node2D


func _scan_for_player(node: Node) -> Node2D:
	if node == null:
		return null
	if node is Player:
		return node as Player
	for child in node.get_children():
		var found := _scan_for_player(child)
		if found != null:
			return found
	return null
