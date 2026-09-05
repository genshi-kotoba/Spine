class_name ItemMarkerDemo
extends Node2D
## ItemMarkerDemo — ItemMarker（需求⑥）演示驱动
## --self-check：验证黄色星星 ① 按「交互可用（门控满足）」显示 ② 同房远程可见（不靠近，异房即隐藏）③ 独立于 E 提示靠近逻辑。

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

	# ② 门控满足 + 同房 -> 显示（远程，不靠近）
	GameState.set_process_flag(GATE, true)
	_player.position = Vector2(1500, 948)
	await get_tree().process_frame
	checks.append("shown_samer1" if _marker.visible else "shown_samer_FAIL1")

	# ③ 门控满足 + 异房（room1）-> 隐藏
	_player.position = Vector2(200, 948)
	await get_tree().process_frame
	checks.append("hidden_diffroom1" if not _marker.visible else "hidden_diffroom_FAIL1")

	# ④ 门控满足 + 异房（room3）-> 隐藏
	_player.position = Vector2(3000, 948)
	await get_tree().process_frame
	checks.append("hidden_diffroom2" if not _marker.visible else "hidden_diffroom_FAIL1")

	# ⑤ 门控满足 + 回同房（room2）-> 显示（远程往返可见）
	_player.position = Vector2(1500, 948)
	await get_tree().process_frame
	checks.append("shown_samer2" if _marker.visible else "shown_samer_FAIL2")

	var failed := false
	for c in checks:
		if c.ends_with("FAIL") or c.contains("FAIL"):
			failed = true
		print("[item_marker_demo] CHECK " + c)
	print("[item_marker_demo] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	get_tree().quit()
