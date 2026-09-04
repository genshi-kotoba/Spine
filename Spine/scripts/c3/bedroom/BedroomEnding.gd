class_name BedroomEnding
extends Node2D
## BedroomEnding — C3 卧室结局流程控制器（spec ⑦，BED-A→BED-D）
## 编排：黑屏后重显卧室靠左(begin)；墙 item E×3 计数；墙面色渐变占位更新；
## 3 次后 → 呼吸解除(发 breath_disable_requested) + 卧室门解锁(bedroom_unlocked) + 置 bedroom_interactions_done；
## 门交互 → 回客厅卧室门前(return_to_living_room_requested + 可选搬运玩家)；
## 右手靠墙 item → 置 end_white + 发 white_screen_end_requested。
## 独立可复用卧室结局模块，供 C3Flow 编排接入（脚本零房间名/关卡字面量；参数经 @export 配置）。
## --self-check：headless 验证 黑屏重显靠左 / 墙 E×3 计数封顶 / 3 次后呼吸解除+门解锁 / 门回客厅位置 / 右手白屏。

## 3 次墙交互完成——请求解除呼吸机制（BreathSystem/C3Flow 处理）。
signal breath_disable_requested
## 门交互——请求把玩家送回客厅卧室门前。
signal return_to_living_room_requested
## 右手靠墙 item——请求白屏结束。
signal white_screen_end_requested
## 整段卧室结局完成（白屏结束触发）。
signal bedroom_sequence_complete
## 墙面色渐变更新（state = 新状态 1..3；供外部/HUD 观察）。
signal wall_gradient_updated(state: int)

## 玩家（begin 搬运到卧室靠左；门交互回客厅；自检定位校验）。
@export var player: NodePath
## 墙面 item（3 态）——自动连接 wall_updated 计数。
@export var wall_item: NodePath
## 卧室门（回客厅）——自动连接 door_return_requested。
@export var door_item: NodePath
## 右手靠墙 item——自动连接 end_white_requested。
@export var end_item: NodePath
## 卧室出生点（黑屏后重显卧室靠左；spec 白模 Player 出生 (320,948)）。
@export var bedroom_spawn: Vector2 = Vector2(320, 948)
## 客厅卧室门前位置（门交互回客厅落点；spec 客厅中央卧室门 x≈1920 附近）。
@export var living_room_door_pos: Vector2 = Vector2(1850, 948)
## 墙交互次数上限（spec「E×3」）。
@export var wall_interactions_max: int = 3

var _wall_interactions: int = 0
var _sequence_done: bool = false
var _breath_req_count: int = 0


func _ready() -> void:
	_wire_items()
	_run_self_check()


## 连接三个 item 的联动信号（脚本零房间字面量；未配置的 NodePath 跳过）。
func _wire_items() -> void:
	if wall_item != NodePath():
		var w := get_node_or_null(wall_item)
		if w is BedroomWallItem:
			(w as BedroomWallItem).wall_updated.connect(_on_wall_updated)
			print("[bedroom_ending] wired wall_item " + str(wall_item))
	if door_item != NodePath():
		var d := get_node_or_null(door_item)
		if d is BedroomDoorItem:
			(d as BedroomDoorItem).door_return_requested.connect(_on_door_return)
			print("[bedroom_ending] wired door_item " + str(door_item))
	if end_item != NodePath():
		var e := get_node_or_null(end_item)
		if e is BedroomEndItem:
			(e as BedroomEndItem).end_white_requested.connect(_on_end_white)
			print("[bedroom_ending] wired end_item " + str(end_item))


## 进入卧室（黑屏后重显卧室靠左）。由 C3Flow 在走廊尽头黑屏后调用。
func begin() -> void:
	_wall_interactions = 0
	_sequence_done = false
	_breath_req_count = 0
	GameState.set_process_flag("bedroom_interactions_done", false)
	GameState.set_process_flag("bedroom_unlocked", false)
	GameState.set_process_flag("end_white", false)
	_move_player(bedroom_spawn)
	print("[bedroom_ending] begin: respawn player to %s" % str(bedroom_spawn))


## 墙 item 每次交互回调：计数；达上限后一次：呼吸解除 + 门解锁 + 置 interactions_done。
func _on_wall_updated(state: int) -> void:
	_wall_interactions += 1
	wall_gradient_updated.emit(state)
	print("[bedroom_ending] wall_updated state=%d count=%d" % [state, _wall_interactions])
	if _wall_interactions >= wall_interactions_max and not _sequence_done:
		_sequence_done = true
		GameState.set_process_flag("bedroom_interactions_done", true)
		GameState.set_process_flag("bedroom_unlocked", true)
		_breath_req_count += 1
		breath_disable_requested.emit()
		print("[bedroom_ending] 3x interactions done: breath_disable_requested + bedroom_unlocked")


## 门（回客厅）交互回调：请求回客厅卧室门前 + 搬运玩家。
func _on_door_return() -> void:
	if not _sequence_done:
		return
	return_to_living_room_requested.emit()
	_move_player(living_room_door_pos)
	print("[bedroom_ending] door return: player to %s" % str(living_room_door_pos))


## 右手靠墙 item 交互回调：置 end_white + 白屏结束。
func _on_end_white() -> void:
	GameState.set_process_flag("end_white", true)
	white_screen_end_requested.emit()
	bedroom_sequence_complete.emit()
	print("[bedroom_ending] end white requested")


## 搬运玩家到指定位置（无玩家配置则忽略）。
func _move_player(to: Vector2) -> void:
	if player == NodePath():
		return
	var p := get_node_or_null(player)
	if p is Node2D:
		(p as Node2D).position = to


## 当前玩家位置（自检用；无玩家返回 bedroom_spawn 便于比对）。
func _player_pos() -> Vector2:
	if player == NodePath():
		return bedroom_spawn
	var p := get_node_or_null(player)
	if p is Node2D:
		return (p as Node2D).position
	return bedroom_spawn


## 取节点下首个 Polygon2D 子节点（白模占位视觉；无可返回 null）。
func _first_polygon_child(node: Node) -> Polygon2D:
	for i in range(node.get_child_count()):
		var child: Node = node.get_child(i)
		if child is Polygon2D:
			return child as Polygon2D
	return null


func _run_self_check() -> void:
	if not "--self-check" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	var checks: Array[String] = []

	# 准备：把玩家固定住，防物理漂移干扰自检；读取三 item
	var p := get_node_or_null(player)
	if p is Node2D:
		(p as Node2D).process_mode = Node.PROCESS_MODE_DISABLED
	var w := get_node_or_null(wall_item) as BedroomWallItem
	var d := get_node_or_null(door_item) as BedroomDoorItem
	var e := get_node_or_null(end_item) as BedroomEndItem

	# —— A. 黑屏后重显卧室靠左 ——
	begin()
	checks.append("spawn_left1" if _player_pos() == bedroom_spawn else "spawn_left_FAIL1")

	# —— B. 卧室门默认 gate 未满足：touched 不触发（gate_blocked），墙交互前门不可用 ——
	if d != null and d.gate_flag != "":
		var before_door_state: int = d.current_state
		d.touched()
		await get_tree().process_frame
		checks.append("door_gated1" if d.current_state == before_door_state else "door_gated_FAIL1")

	# —— C. 墙 item E×3：每次计数 + 墙色渐变更新；达上限封顶 ——
	for i in range(wall_interactions_max):
		if w != null:
			w.touched()
			await get_tree().process_frame
	checks.append("wall_state_capped1" if w != null and w.current_state == wall_interactions_max else "wall_state_capped_FAIL1")
	checks.append("wall_unlock1" if GameState.get_process_flag("bedroom_unlocked") and GameState.get_process_flag("bedroom_interactions_done") else "wall_unlock_FAIL1")
	checks.append("breath_req1" if _breath_req_count == 1 else "breath_req_FAIL1")
	# 墙面色渐变占位更新：state 3 需应用对应颜色（首个 Polygon2D 子节点，白模惯例）
	if w != null:
		var wall_visual: Polygon2D = _first_polygon_child(w)
		checks.append("wall_gradient1" if wall_visual != null and wall_visual.color == w.wall_color_3 else "wall_gradient_FAIL1")
	# 已封顶：再交互不推进
	if w != null:
		w.touched()
		await get_tree().process_frame
	checks.append("wall_cap_no_extra1" if w != null and w.current_state == wall_interactions_max else "wall_cap_no_extra_FAIL1")

	# —— D. 门（解锁后）交互：回客厅卧室门前 ——
	if d != null:
		d.touched()
		await get_tree().process_frame
	checks.append("door_return_pos1" if _player_pos() == living_room_door_pos else "door_return_pos_FAIL1")

	# —— E. 右手靠墙 item：白屏结束 ——
	if e != null:
		e.touched()
		await get_tree().process_frame
	checks.append("end_white1" if GameState.get_process_flag("end_white") else "end_white_FAIL1")

	var failed := false
	for c in checks:
		if c.ends_with("FAIL") or c.contains("FAIL"):
			failed = true
		print("[bedroom_ending] CHECK " + c)
	print("[bedroom_ending] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	get_tree().quit()
