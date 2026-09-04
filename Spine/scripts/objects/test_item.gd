class_name TestItem
extends "res://scripts/objects/item.gd"
## TestItem — item 基类的两状态测试子类
## 状态 0 = 初始位置（_ready 记录 initial_position）；状态 1 = 上移 lift_distance(200)px；
## 切换用 Tween 0.3s。touched()（E 键经 Player.interact_pressed 触发）= 范围判定 + toggle 0↔1。

## 上移距离（像素；Godot y 轴向下，上移为负 y）
@export var lift_distance: float = 200.0

## 状态切换 Tween 时长（秒）
@export var tween_duration: float = 0.3

## 初始位置（状态 0 参考点；_ready 记录）
var initial_position: Vector2 = Vector2.ZERO

## 当前执行的 Tween（用于停止上一个，避免并发切换冲突）
var _active_tween: Tween


func _ready() -> void:
	super._ready()
	initial_position = position
	print("[test_item] ready state=0 initial_position=(%s, %s)" % [initial_position.x, initial_position.y])
	_run_self_check()


## 状态效果唯一出口（覆写）：按目标状态定位并 Tween 移动
func apply_state(new_state: int) -> void:
	var target: Vector2 = _target_position(new_state)
	print("[test_item] apply_state state=%d target=(%s, %s)" % [new_state, target.x, target.y])
	_stop_active_tween()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "position", target, tween_duration)


## 交互触发（覆写）：范围判定成立 toggle 0↔1，不成立无动作
func touched() -> void:
	var player := _get_overlapping_player()
	var in_range := player != null
	print("[test_item] touched in_range=%s" % str(in_range))
	if in_range:
		var new_state: int = 1 if current_state == 0 else 0
		set_state(new_state)


## 目标位置：状态 0 = 初始位置；状态 1 = 初始位置 + Vector2(0, -lift_distance)
func _target_position(new_state: int) -> Vector2:
	if new_state == 1:
		return initial_position + Vector2(0.0, -lift_distance)
	return initial_position


## 范围判定：优先 get_overlapping_bodies()（Godot 4.7 等效）；返回范围内第一个 Player（无则 null）
func _get_overlapping_player() -> Player:
	var bodies: Array[Node2D] = get_overlapping_bodies()
	for body in bodies:
		if body is Player:
			return body as Player
	return null


## 停止上一个 tween，避免并发切换冲突
func _stop_active_tween() -> void:
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null


## 自检（--self-check）：headless 读回校验 call_item→set_state→apply_state→Tween 全链路
## 仅当命令行参数含 --self-check 时执行；常规运行/游玩不受影响。
func _run_self_check() -> void:
	if not "--self-check" in OS.get_cmdline_user_args():
		return
	call_item(1)
	await get_tree().create_timer(0.6).timeout
	_run_self_check_assert()
	get_tree().quit()


## 自检断言：状态 1 落点 y 应等于 initial_position.y - lift_distance（Tween 0.3s 已结束）
func _run_self_check_assert() -> void:
	var expected_y: float = initial_position.y - lift_distance
	var diff: float = absf(position.y - expected_y)
	if diff < 1.0:
		print("[test_item] SELF-CHECK PASS state=1 y=%s expected=%s diff=%s" % [position.y, expected_y, diff])
	else:
		print("[test_item] SELF-CHECK FAIL state=1 y=%s expected=%s diff=%s" % [position.y, expected_y, diff])
