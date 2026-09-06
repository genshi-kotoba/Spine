extends Node
## Player motion regression check.
## Runs the real Player with deterministic time steps so profiles stay consistent across levels.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const STEP := 0.01


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	StoryMonitor.input_locked = false
	var player := PLAYER_SCENE.instantiate() as Player
	get_tree().root.add_child(player)
	player.set_physics_process(false)
	var checks: Array[String] = []

	# Default profile: 0 -> 400 in 0.18s, 400 -> 0 in 0.12s, and 400 -> -400 in 0.14s.
	Input.action_press("move_right")
	_step_player(player, 17)
	var start_before_target := player.velocity.x < 399.0
	_step_player(player, 1)
	checks.append("start_time" if start_before_target and player.velocity.x >= 399.0 else "start_time_FAIL")

	Input.action_release("move_right")
	_step_player(player, 11)
	var stop_before_target := absf(player.velocity.x) > 1.0
	_step_player(player, 1)
	checks.append("stop_time" if stop_before_target and absf(player.velocity.x) <= 1.0 else "stop_time_FAIL")

	Input.action_press("move_right")
	_step_player(player, 18)
	Input.action_release("move_right")
	Input.action_press("move_left")
	_step_player(player, 13)
	var reverse_before_target := player.velocity.x > -399.0
	_step_player(player, 1)
	checks.append("reverse_time" if reverse_before_target and player.velocity.x <= -399.0 else "reverse_time_FAIL")
	Input.action_release("move_left")

	# A cutscene lock must reset the transition mode; the next direction starts at startup rate.
	player.velocity.x = 400.0
	Input.action_press("move_left")
	_step_player(player, 1)
	StoryMonitor.input_locked = true
	_step_player(player, 1)
	StoryMonitor.input_locked = false
	_step_player(player, 1)
	var held_direction_blocked := absf(player.velocity.x) <= 0.1
	Input.action_release("move_left")
	_step_player(player, 1)
	var released_direction_cleared := absf(player.velocity.x) <= 0.1
	Input.action_press("move_right")
	_step_player(player, 1)
	checks.append("unlock_held_direction_blocked" if held_direction_blocked else "unlock_held_direction_blocked_FAIL")
	checks.append("unlock_release_cleared" if released_direction_cleared else "unlock_release_cleared_FAIL")
	checks.append("lock_reset" if player.velocity.x > 15.0 and player.velocity.x < 35.0 else "lock_reset_FAIL")
	Input.action_release("move_right")

	var failed := false
	for check in checks:
		if check.contains("FAIL"):
			failed = true
		print("[player_motion] CHECK " + check)
	player.queue_free()
	print("[player_motion] " + ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _step_player(player: Player, count: int) -> void:
	for _index in range(count):
		player._physics_process(STEP)
