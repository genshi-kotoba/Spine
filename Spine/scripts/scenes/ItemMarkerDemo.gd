class_name ItemMarkerDemo
extends Node2D
## ItemMarkerDemo — ItemMarker 高光演示驱动
## --self-check：验证 ① 门控隐藏 ② 同房远处白色描边 ③ 进入交互距离变金色 ④ 异房隐藏。

@onready var _item: Item = $Item
@onready var _marker: ItemMarker = $Item/ItemMarker
@onready var _player: Player = $Player
@onready var _room_table: RoomTable = $RoomTable

const GATE := "c3_gate_marker"


func _ready() -> void:
	# 场景配置三房 x 区间（白模三房 [0,1280]/[1280,2560]/[2560,3840]；房间数据零硬编码于此脚本）
	_room_table.set_rooms({
		"room1": {"x_min": 0.0, "x_max": 1280.0},
		"room2": {"x_min": 1280.0, "x_max": 2560.0},
		"room3": {"x_min": 2560.0, "x_max": 3840.0}
	})
	if "--self-check" in OS.get_cmdline_user_args():
		_run_self_check()
	else:
		# Normal visual runs start in the same room but outside interaction range,
		# so the white-to-gold transition can be observed by moving left.
		GameState.set_process_flag(GATE, true)
		_player.position = Vector2(2200, 948)


func _run_self_check() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var checks: Array[String] = []
	# item 位于 room2（x=1500）。

	# ① 门控未满足（即使同房）-> 隐藏
	GameState.set_process_flag(GATE, false)
	_player.position = Vector2(1500, 948)
	await get_tree().process_frame
	checks.append("hidden_unmet1" if not _marker.visible else "hidden_unmet_FAIL1")

	# ② 门控满足 + 同房远处 -> 显示白色描边
	GameState.set_process_flag(GATE, true)
	_player.position = Vector2(2200, 948)
	await get_tree().process_frame
	checks.append("shown_far1" if _marker.visible else "shown_far_FAIL1")
	checks.append("far_white1" if _marker.get_current_outline_color().is_equal_approx(_marker.far_outline_color) else "far_white_FAIL1")

	# ③ 进入 Item 的 Area2D 交互范围 -> 显示金色描边
	_player.position = Vector2(1500, 948)
	await get_tree().physics_frame
	await get_tree().process_frame
	checks.append("shown_near1" if _marker.visible else "shown_near_FAIL1")
	checks.append("near_gold1" if _marker.is_in_interaction_range() and _marker.get_current_outline_color().is_equal_approx(_marker.near_outline_color) else "near_gold_FAIL1")

	# ④ 门控满足 + 异房（room1）-> 隐藏
	_player.position = Vector2(200, 948)
	await get_tree().process_frame
	checks.append("hidden_diffroom1" if not _marker.visible else "hidden_diffroom_FAIL1")

	# ⑤ 门控满足 + 异房（room3）-> 隐藏
	_player.position = Vector2(3000, 948)
	await get_tree().process_frame
	checks.append("hidden_diffroom2" if not _marker.visible else "hidden_diffroom_FAIL1")

	# ⑥ 回同房远处 -> 白色描边再次显示
	_player.position = Vector2(2200, 948)
	await get_tree().physics_frame
	await get_tree().process_frame
	checks.append("shown_far2" if _marker.visible else "shown_far_FAIL2")
	checks.append("far_white2" if _marker.get_current_outline_color().is_equal_approx(_marker.far_outline_color) else "far_white_FAIL2")

	var failed := false
	for c in checks:
		if c.ends_with("FAIL") or c.contains("FAIL"):
			failed = true
		print("[item_marker_demo] CHECK " + c)
	print("[item_marker_demo] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	get_tree().quit()
