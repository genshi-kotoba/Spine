class_name PlayerMotionProfile
extends Resource
## Shared horizontal movement contract for every scene that instances player.tscn.
## All timings describe a complete velocity transition at full input, in seconds.

## Full horizontal speed in pixels per second.
@export var max_speed: float = 400.0
## Time from rest to max_speed while holding a direction.
@export_range(0.01, 2.0, 0.01, "suffix:s") var start_to_max_time: float = 0.18
## Time from max_speed in one direction to max_speed in the opposite direction.
@export_range(0.01, 2.0, 0.01, "suffix:s") var reverse_to_max_time: float = 0.14
## Time from max_speed to rest after releasing movement.
@export_range(0.01, 2.0, 0.01, "suffix:s") var stop_to_rest_time: float = 0.12
## Vertical gravity used by the current grounded C3 player.
@export var gravity: float = 980.0


func approach_horizontal_velocity(current_velocity: float, input_direction: float, delta: float, reversing: bool = false) -> float:
	var input := clampf(input_direction, -1.0, 1.0)
	var target_velocity := input * maxf(max_speed, 0.0)
	return move_toward(current_velocity, target_velocity, _rate_for(input, reversing) * maxf(delta, 0.0))


func _rate_for(input_direction: float, reversing: bool) -> float:
	var speed := maxf(max_speed, 0.0)
	if is_zero_approx(input_direction):
		return speed / maxf(stop_to_rest_time, 0.001)
	if reversing:
		return speed * 2.0 / maxf(reverse_to_max_time, 0.001)
	return speed / maxf(start_to_max_time, 0.001)
