class_name C3Flow
extends Node
## C3Flow — C3 关卡流程门控（阶段状态机 + 进程旗标 + item 门控接入 + LIGHT 序列 + 场景编排）
## 对应 docs/c3_gameplay_constraints.md §3.1/§3.2/§6.2/§7.2/§10.4 的流程与门控逻辑层。
## 场景组装（c3_level.tscn）由 t16 负责接线；本品为编排/门控核心。

## 阶段常量（§3.1）。
const STAGE_STUDY := 1
const STAGE_LEAVE_STUDY := 2
const STAGE_LIVING := 3
const STAGE_KITCHEN := 4
const STAGE_RETURN_STUDY := 5
const STAGE_LIGHT := 6
const STAGE_CORRIDOR := 7
const STAGE_CORRIDOR_END := 8
const STAGE_BEDROOM := 9

## 进程旗标常量（§3.2）。
const FLAG_HOLD_BREATH_UNLOCKED := "hold_breath_unlocked"
const FLAG_BEDROOM_DOOR_ACTIVE := "bedroom_door_active"
const FLAG_PAPER_LIVING := "paper_living_collected"
const FLAG_PAPER_KITCHEN := "paper_kitchen_collected"
const FLAG_STUDY_ITEMS_UNLOCKED := "study_items_unlocked"
const FLAG_STUDY_GATE_OPEN := "study_gate_open"
const FLAG_LIGHT_PHASE_DONE := "light_phase_done"
const FLAG_CORRIDOR_ENTERED := "corridor_entered"
const FLAG_CORRIDOR_END := "corridor_end"
const FLAG_BEDROOM_UNLOCKED := "bedroom_unlocked"
const FLAG_BEDROOM_INTERACTIONS_DONE := "bedroom_interactions_done"
const FLAG_END_WHITE := "end_white"

## 当前阶段（运行时状态，不持久化）。
var current_stage: int = STAGE_STUDY
var _study_papers_collected: int = 0

# ─── 光影演出（书房右侧遮罩揭露：四试卷后等角色走到右侧靠近房门时触发）───
## 触发判定：角色 x 越过该阈值（靠近书房右侧门）即触发震撼。
const LIGHT_TRIGGER_X := 1100.0
const LIGHT_SHAKE_DUR := 5.0
const LIGHT_PARTICLE_DUR := 4.6
const LIGHT_REVEAL_DELAY := 0.18
const LIGHT_REVEAL_DUR := 4.45
const LIGHT_REVEAL_END_UV := 1.10
const LIGHT_MASK_SOFTNESS_PX := 56.0
const LIGHT_MASK_COLOR := Color(0.0, 0.0, 0.0, 0.96)
## 主相机竖向取景偏移（参照 c3_floor camera_position_offset=(0,-336.5) 口径；2.35:1 内部视口 1920x817）：
## 让角色视觉站画幅地面位置而非竖正中（t34 gap ①，不改 player.tscn）。
const CAMERA_FRAME_OFFSET := Vector2(0, -336.5)

## C3 开场：字幕结束后显示三段角色右上方提示，最后一段结束才解除冻结。
const INTRO_DIALOGUE_PATH := "res://dialogues/c3_intro.txt"
const INTRO_FIRST_TEXT := "尝试按下空格深呼吸"
const INTRO_SECOND_TEXT := "身边的气泡标识当前氧气剩余\n氧气不足时，气泡破裂，你会陷入缺氧"
const INTRO_THIRD_TEXT := "当然，对于我们\n缺氧或许也并不会怎样……"
const INTRO_TEXT_DURATION := 4.0
const INTRO_BREATH_RATE := 4.0

## 客厅（第二间 room）电视柜绑定在房间左侧，避免误落到右侧门附近。
const LIVING_TV_X := 1480.0
const FLOW_ROOM_RIGHT_X := 2460.0
const KITCHEN_PAPER_X := 3184.0

## 光影演出运行状态。走廊先组装，再由右侧遮罩随粒子向右揭露。
var _light_triggered: bool = false
var _light_show_t: float = 0.0
var _light_mask_start_uv: float = 1.0
var _light_side_mask_active: bool = false

signal stage_changed(new_stage: int)
## 第四张试卷后的异常提示音占位；后续音频资产接入只需监听此信号。
signal story_sfx_requested(cue: String)

## ─── 场景编排引用（t16 接线）───
@export var player_path: NodePath
@export var corridor_path: NodePath
@export var bedroom_path: NodePath
@export var breath_path: NodePath
@export var darkness_mask_path: NodePath
@export var black_screen_path: NodePath
@export var white_screen_path: NodePath
@export var screen_shake_path: NodePath
@export var particle_burst_path: NodePath
@export var corridor_end_item_path: NodePath
@export var gate_blocker_path: NodePath
@export var room_table_path: NodePath
@export var items_root_path: NodePath
@export var bedroom_items_path: NodePath
@export var camera_path: NodePath
@export var corridor_assembly_path: NodePath
## 独立卧室阶段需要隐藏的走廊边界视觉；碰撞保留，避免流程切回走廊时重建物理体。
@export var corridor_floor_path: NodePath
@export var corridor_end_wall_path: NodePath
## 白模三房右边界碰撞。走廊从书房门向右延伸时必须停用，回到客厅再恢复。
## 仅绑定 WallRight/CollisionShape2D，不影响白模地板或天花板碰撞。
@export var room_right_wall_collision_path: NodePath
@export var door_study_living_path: NodePath
@export var door_living_dining_path: NodePath
@export var study_spawn: Vector2 = Vector2(320, 948)
@export var study_right_x: float = 1280.0
## t14 锁门余量：玩家完全出书房（过门洞+门板，x ≥ study_lock_x）才锁门+启用 blocker（防门洞夹人）。
@export var study_lock_x: float = 1320.0
## t14 兜底轮询区间（STAGE_STUDY）：玩家 x 进入该区间且书房-客厅左门未开 → 直接 open()（每帧，幂等）。
@export var door_fallback_min_x: float = 1220.0
@export var door_fallback_max_x: float = 1292.0
## LIGHT-C 需隐藏的门/墙（NodePath；如 书房-客厅墙、auto_door、最右侧墙）。
@export var wall_hide_paths: Array[NodePath] = []
## 卧室白模环境（RoomBase 程序化地板/墙/自动门）。走廊阶段整体禁碰撞，避免卧室门
## （全局 x≈5460）挡在第一、第二特异点之间；进入卧室阶段再恢复。
@export var bedroom_left_wall_path: NodePath
## 独立卧室构图范围。主白模三房宽 3840，因此单间宽为 1280；镜头锁在中点，四周清屏为黑。
@export var bedroom_frame_left: float = 4500.0
@export var bedroom_frame_right: float = 5780.0
## 返回客厅后恢复主地图的相机范围。
@export var world_camera_left: float = 0.0
@export var world_camera_right: float = 11520.0
## 光影后超限走廊直接从书房门接出，镜头边界只覆盖该短走廊。
@export var corridor_camera_left: float = 0.0
@export var corridor_camera_right: float = 11520.0

var _player: Node2D = null
var _left_study: bool = false
var _corridor: Node = null
var _corridor_assembly: Node = null
var _door_study_living: Node = null
var _door_living_dining: Node = null
var _bedroom: Node = null
var _breath: Node = null
var _mask: Node = null
var _screen_shake: Node = null
var _particle_burst: Node = null
var _phase_debug_loaded: bool = false
var _intro_active: bool = false
var _intro_waiting_breath: bool = false
var _intro_breathed: bool = false
var _intro_text_stage: int = 0
var _intro_text_elapsed: float = 0.0
var _flow_dialogue_action: String = ""
var _tv_subtitle_shown: bool = false
var _hall_door_subtitle_shown: bool = false
var _end_item_subtitle_shown: bool = false
var _final_study_dialogue_started: bool = false
var _corridor_end_hint_shown: bool = false
var _bedroom_arrival_dialogue_shown: bool = false
var _bedroom_phone_dialogue_started: bool = false
var _bedroom_exit_dialogue_shown: bool = false
var _bedroom_return_end_dialogue_shown: bool = false


func _ready() -> void:
	add_to_group("c3flow")
	_reset_flags()
	_ready_extra()
	if "--self-check" in OS.get_cmdline_user_args():
		_run_self_check_async()
	elif "--physical" in OS.get_cmdline_user_args():
		var okp := await _physical_assertions()
		print("[c3_flow] PHYSICAL-CHECK " + ("PASS" if okp else "FAIL"))
		get_tree().quit()


## --self-check：先跑逻辑自检，再跑物理运行断言（等物理帧稳定后读回），最后统一 quit。
func _run_self_check_async() -> void:
	var ok := run_scene_self_check()
	var okp := await _physical_assertions()
	print("[c3_flow] PHYSICAL-CHECK " + ("PASS" if (okp and ok) else "FAIL"))
	get_tree().quit()


## 当前阶段。
func get_stage() -> int:
	return current_stage


## 复位全部旗标与阶段（初生书房状态）。
func _reset_flags() -> void:
	GameState.set_process_flag(FLAG_HOLD_BREATH_UNLOCKED, false)
	GameState.set_process_flag(FLAG_BEDROOM_DOOR_ACTIVE, false)
	GameState.set_process_flag(FLAG_PAPER_LIVING, false)
	GameState.set_process_flag(FLAG_PAPER_KITCHEN, false)
	GameState.set_process_flag(FLAG_STUDY_ITEMS_UNLOCKED, false)
	GameState.set_process_flag(FLAG_STUDY_GATE_OPEN, false)
	GameState.set_process_flag(FLAG_LIGHT_PHASE_DONE, false)
	GameState.set_process_flag(FLAG_CORRIDOR_ENTERED, false)
	GameState.set_process_flag(FLAG_CORRIDOR_END, false)
	GameState.set_process_flag(FLAG_BEDROOM_UNLOCKED, false)
	GameState.set_process_flag(FLAG_BEDROOM_INTERACTIONS_DONE, false)
	GameState.set_process_flag(FLAG_END_WHITE, false)
	current_stage = STAGE_STUDY
	_study_papers_collected = 0
	_light_triggered = false
	_light_show_t = 0.0
	_corridor_end_hint_shown = false
	_bedroom_arrival_dialogue_shown = false
	_bedroom_phone_dialogue_started = false
	_bedroom_exit_dialogue_shown = false
	_bedroom_return_end_dialogue_shown = false


## 设置阶段；进入关键阶段时应用旗标/序列。
func set_stage(s: int) -> void:
	current_stage = s
	stage_changed.emit(s)
	_apply_stage_effects(s)


## 应用阶段侧效（旗标 + LIGHT 序列 + 走廊启用）。
func _apply_stage_effects(s: int) -> void:
	if s >= STAGE_LIGHT:
		GameState.set_process_flag(FLAG_LIGHT_PHASE_DONE, true)
	if s >= STAGE_CORRIDOR:
		GameState.set_process_flag(FLAG_CORRIDOR_ENTERED, true)
		# 屏息解锁与走廊阶段同生（与 _finish_light_show 一致；--phase 调试入口直接可用）
		GameState.set_process_flag(FLAG_HOLD_BREATH_UNLOCKED, true)
	if s == STAGE_CORRIDOR_END:
		GameState.set_process_flag(FLAG_CORRIDOR_END, true)
	# t3/t37 修复：走廊阶段禁用卧室白模环境碰撞（含运行时生成的自动门），进卧室后再启用。
	if s >= STAGE_CORRIDOR and s < STAGE_BEDROOM:
		_set_bedroom_environment_collision(false)
		_set_room_right_wall_collision(false)
	elif s >= STAGE_BEDROOM:
		_set_bedroom_environment_collision(true)
		_set_room_right_wall_collision(false)
	else:
		_set_room_right_wall_collision(true)
	_set_bedroom_active(s == STAGE_BEDROOM)
	_set_corridor_active(s >= STAGE_CORRIDOR and s < STAGE_BEDROOM)
	_set_story_item_stage(s)
	if s >= STAGE_CORRIDOR and s < STAGE_BEDROOM:
		var corridor_camera := get_node_or_null(camera_path)
		if corridor_camera is CorridorCamera:
			(corridor_camera as CorridorCamera).set_map_bounds(corridor_camera_left, corridor_camera_right)
	if s == STAGE_BEDROOM:
		_lock_bedroom_frame()


# ─── 事件钩子（场景/t16 接线调用）───

## 玩家离开书房 → 锁书房-客厅门（无法回）+ 进入 LEAVE_STUDY（§6.2）。
func on_player_left_study() -> void:
	_left_study = true
	GameState.set_process_flag(FLAG_STUDY_GATE_OPEN, false)
	_apply_gate_blocker()
	_sync_study_door_lock()
	if current_stage == STAGE_STUDY:
		set_stage(STAGE_LEAVE_STUDY)


## 试卷得分回调（由 C3PaperItem 调用）。
func on_paper_collected(paper_id: String, score: int) -> void:
	if paper_id == "paper_living":
		GameState.set_process_flag(FLAG_PAPER_LIVING, true)
	elif paper_id == "paper_kitchen":
		GameState.set_process_flag(FLAG_PAPER_KITCHEN, true)
	elif paper_id == "study_a" or paper_id == "study_b":
		_collect_study_paper()
	if paper_id == "paper_living":
		_show_flow_subtitle([
			"这里散落了一张考了100分的试卷",
			"应该是客户的考试成绩",
		], "")
	elif paper_id == "paper_kitchen":
		_show_flow_subtitle([
			"这里也有一张考了100分的试卷",
			"可是，这才两张",
			"书房没有找过，要不去书房看看？",
		], "kitchen_study_hint")
	elif paper_id == "study_a" or paper_id == "study_b":
		# 文本按玩家实际拾取顺序决定，不按场景中纸张的资源 ID 决定。
		if _study_papers_collected <= 1:
			_show_flow_subtitle([
				"一张考了100分的试卷",
				"嗯？旁边这张纸是什么",
			], "")
		else:
			_show_flow_subtitle([
				"这里也有一张试卷",
				"但是不是100分，是……99？",
			], "study_b_sound")
	_refresh_study_state()


func _collect_study_paper() -> void:
	_study_papers_collected += 1


func _refresh_study_state() -> void:
	var living_ok := GameState.get_process_flag(FLAG_PAPER_LIVING)
	var kitchen_ok := GameState.get_process_flag(FLAG_PAPER_KITCHEN)
	if living_ok and kitchen_ok:
		GameState.set_process_flag(FLAG_STUDY_GATE_OPEN, true)
		GameState.set_process_flag(FLAG_STUDY_ITEMS_UNLOCKED, true)
		_apply_gate_blocker()
		_sync_study_door_lock()
		if current_stage < STAGE_RETURN_STUDY:
			set_stage(STAGE_RETURN_STUDY)
	if _study_papers_collected >= 2 and not GameState.get_process_flag(FLAG_LIGHT_PHASE_DONE):
		GameState.set_process_flag(FLAG_LIGHT_PHASE_DONE, true)
		on_bedroom_door_named()
		set_stage(STAGE_LIGHT)


func _show_flow_subtitle(lines: Array, action: String = "") -> void:
	if lines.is_empty():
		return
	_flow_dialogue_action = action
	if not DialogueManager.dialogue_finished.is_connected(_on_flow_dialogue_finished):
		DialogueManager.dialogue_finished.connect(_on_flow_dialogue_finished)
	DialogueManager.start_lines(lines, DialogueManager.MODE_INTERACTIVE)


func _on_flow_dialogue_finished() -> void:
	var action := _flow_dialogue_action
	_flow_dialogue_action = ""
	match action:
		"hall_door":
			_show_flow_floating("厨房好像也有试卷", Vector2(FLOW_ROOM_RIGHT_X, 650.0), FLOW_ROOM_RIGHT_X)
		"study_b_sound":
			story_sfx_requested.emit("study_paper_anomaly")
			# 异响属于第一间 room 的环境文本，固定在世界右侧；玩家经过后淡出。
			_show_flow_floating("外面什么声音，怎么回事?", Vector2(1080.0, 640.0), 1200.0, false)
			_final_study_dialogue_started = true
			call_deferred("_trigger_light_show")
		"kitchen_study_hint":
			# 厨房对白结束后给出短暂方向提示，箭头跟随角色并始终朝左。
			_show_flow_floating("←", Vector2(220.0, -250.0), INF, true, 4.0)
		"bedroom_arrival":
			# Arrival text is intentionally terminal; wall interactions remain available afterwards.
			pass
		"bedroom_wall_step":
			pass
		"bedroom_wall_final":
			if not _bedroom_phone_dialogue_started:
				_bedroom_phone_dialogue_started = true
				story_sfx_requested.emit("bedroom_phone_ring")
				_show_flow_subtitle(["有电话？！", "奇怪，呼吸突然顺畅多了"], "bedroom_phone")
		"bedroom_phone":
			_show_flow_floating("卧室外面响起电话声", Vector2(5140.0, 650.0), INF, false)
		"bedroom_exit":
			pass


func _show_flow_floating(value: String, _world_anchor: Vector2, _clear_x: float = INF, _follow_player: bool = false, _duration_sec: float = INF) -> void:
	# C3 悬浮提示直接复用 main 分支 MODE_GLITCH。
	DialogueManager.start_lines([value], DialogueManager.MODE_GLITCH)


func _hide_flow_floating() -> void:
	# MODE_GLITCH 按 main 模块自身的逐句生命周期自动隐藏。
	pass


# ─── 卧室门三态（§5.2）───

func on_bedroom_door_named() -> void:
	GameState.set_process_flag(FLAG_BEDROOM_DOOR_ACTIVE, true)


## 卧室门 E → 搬运进卧室（begin + 黑屏渐变）。供场景连接 BedroomHallDoor 的 gate_ok/touched。
func on_enter_bedroom() -> void:
	_fade_black_and_begin_bedroom()


# ─── 光影演出（右侧遮罩揭露；四试卷后等角色走到书房右侧触发）───

## 触发震撼演出：先把走廊组装在书房右侧遮罩后，再消散隔墙并沿遮罩边缘发射粒子。
## 演出期间锁输入；5 秒内遮罩向右展开，露出走廊后才解锁进入走廊阶段。
func _trigger_light_show() -> void:
	if _light_triggered:
		return
	_light_triggered = true
	_light_show_t = 0.0
	StoryMonitor.lock_input()
	# 走廊真实存在、碰撞和玩家输入仍受锁；侧向遮罩先盖住书房右侧，避免墙体消失时提前穿帮。
	_set_corridor_active(true)
	_begin_light_side_mask()
	_hide_room_structures()
	_run_light_shake()
	_run_light_particles()


## 震撼演出结束（5s）：解锁输入 + 解锁屏息 + 进入走廊阶段。
func _finish_light_show() -> void:
	_clear_light_side_mask()
	GameState.set_process_flag(FLAG_HOLD_BREATH_UNLOCKED, true)
	GameState.set_process_flag(FLAG_LIGHT_PHASE_DONE, true)
	StoryMonitor.unlock_input()
	if current_stage < STAGE_CORRIDOR:
		set_stage(STAGE_CORRIDOR)


func _reset_player_to_study() -> void:
	if _player != null:
		_player.global_position = study_spawn


## 隐藏并禁碰撞全部房间间隔门/墙（含 auto_door×2、locked_bedroom_door、分隔墙×3、最右墙）；递归禁用子孙 CollisionShape2D。
func _hide_room_structures() -> void:
	for wp in wall_hide_paths:
		var n := get_node_or_null(wp)
		if n == null:
			continue
		n.visible = false
		_disable_collisions_recursive(n)


## 从独立卧室回到客厅时复原主场景的门墙视觉与物理体。
## 这只恢复白模结构；试卷等可收集物仍由各自的 GameState 旗标保持已收集状态。
func _restore_room_structures() -> void:
	for wp in wall_hide_paths:
		var n := get_node_or_null(wp)
		if n == null:
			continue
		n.visible = true
		_set_collision_enabled_recursive(n, true)


func _set_bedroom_environment_collision(active: bool) -> void:
	if bedroom_left_wall_path == NodePath():
		return
	var wall := get_node_or_null(bedroom_left_wall_path)
	if wall == null:
		return
	var environment := wall.get_parent()
	if environment == null:
		return
	_set_collision_enabled_recursive(environment, active)


func _set_room_right_wall_collision(active: bool) -> void:
	if room_right_wall_collision_path == NodePath():
		return
	var collision := get_node_or_null(room_right_wall_collision_path)
	if collision is CollisionShape2D:
		(collision as CollisionShape2D).set_deferred("disabled", not active)


## 卧室是结局专用的独立场景。走廊及此前阶段必须整体隐藏，避免墙纸或门落入走廊画面。
func _set_bedroom_active(active: bool) -> void:
	if _bedroom == null:
		return
	var room := _bedroom.get_parent()
	if room is CanvasItem:
		(room as CanvasItem).visible = active
	_set_collision_enabled_recursive(room, active)


## 卧室是独立房间：进入后隐藏走廊视觉并停止其判定，避免走廊下一帧覆盖白模。
func _set_corridor_active(active: bool) -> void:
	if _corridor != null:
		if _corridor.has_method("set_enabled"):
			(_corridor as Node).set_enabled(active)
		else:
			_corridor.set("enabled", active)
		if _corridor is CanvasItem:
			(_corridor as CanvasItem).visible = active
	if _corridor_assembly != null:
		_corridor_assembly.set_process(active)
	_set_corridor_boundary_visuals(active)


## 光影演出后，主场景的卧室入口与结局点不能残留在走廊里。
## 终局点开局保留 state=0 的视觉占位，但仅在卧室完成、回到客厅后开放最终白屏交互。
func _set_story_item_stage(stage: int) -> void:
	var post_bedroom_living := stage == STAGE_LIVING \
		and GameState.get_process_flag(FLAG_BEDROOM_INTERACTIONS_DONE)
	# The hall door is a visible no-op before the corridor transition: E appears in range but
	# its gate rejects the action until the post-bedroom return route. Once LIGHT starts, it
	# must disappear with the old room geometry so it cannot leak into the corridor.
	var hall_door_visible := stage < STAGE_LIGHT or post_bedroom_living
	var hall_door := get_node_or_null("Items/BedroomHallDoor") as Item
	if hall_door != null and stage < STAGE_LIGHT:
		hall_door.gate_flag = ""
	_set_story_item_state(hall_door, hall_door_visible, hall_door_visible)
	var end_placeholder_visible := stage < STAGE_LIGHT or post_bedroom_living
	var end_item := get_node_or_null("Items/EndItem") as Item
	if end_item != null:
		end_item.gate_flag = ""
	_set_story_item_state(end_item, end_placeholder_visible, post_bedroom_living or stage >= STAGE_KITCHEN and stage < STAGE_LIGHT)
	var corridor_end_active := stage == STAGE_CORRIDOR_END
	_set_story_item_state(get_node_or_null(corridor_end_item_path), corridor_end_active, corridor_end_active)


func _set_story_item_state(node: Node, visible: bool, interaction_enabled: bool) -> void:
	if not node is Item:
		return
	var item := node as Item
	item.visible = visible
	item.set_interaction_enabled(interaction_enabled)
	_set_collision_enabled_recursive(item, interaction_enabled)


## 走廊地板是独立 StaticBody2D，未挂在 Corridor 节点下；只在走廊阶段显示。
## 进入独立卧室时隐藏它，确保房间盒子之外保持纯黑。
func _set_corridor_boundary_visuals(active: bool) -> void:
	for path in [corridor_floor_path, corridor_end_wall_path]:
		if path == NodePath():
			continue
		var boundary := get_node_or_null(path)
		if boundary is CanvasItem:
			(boundary as CanvasItem).visible = active
		# The end wall falls inside the separate bedroom's world range. Keeping its hidden
		# collider active would leave an invisible barrier roughly 100px into that room.
		# The floor deliberately remains solid while hidden because it overlaps the bedroom
		# floor and continues to provide a stable standing surface during transitions.
		if path == corridor_end_wall_path:
			_set_collision_enabled_recursive(boundary, active)


## 独立卧室：镜头锁在单间中点，1280px 房间置于 1920px 画幅中央，左右自然保留黑边。
func _lock_bedroom_frame() -> void:
	var camera := get_node_or_null(camera_path)
	if camera is CorridorCamera:
		(camera as CorridorCamera).lock_frame_center_x((bedroom_frame_left + bedroom_frame_right) * 0.5)


## 卧室门 E 回客厅：恢复客厅的运行时场景层和正常地图跟随；玩家搬运由 BedroomEnding 负责。
func _on_bedroom_return_to_living_room() -> void:
	# Do not reset progression here: collected papers stay collected, while the returned living room regains its walls.
	_restore_room_structures()
	set_stage(STAGE_LIVING)
	var camera := get_node_or_null(camera_path)
	if camera is CorridorCamera:
		(camera as CorridorCamera).set_map_bounds(world_camera_left, world_camera_right)
		(camera as CorridorCamera).set_mode(CorridorCamera.Mode.FOLLOW_CLAMPED)
	_hide_flow_floating()
	if not _bedroom_exit_dialogue_shown:
		_bedroom_exit_dialogue_shown = true
		call_deferred("_show_bedroom_exit_dialogue")


func _show_bedroom_exit_dialogue() -> void:
	_show_flow_subtitle([
		"咦……电话声音消失了",
		"谁？",
		"把盒子扔到地上，里面的望远镜都掉出来了",
	], "bedroom_exit")


func _on_bedroom_wall_updated(state: int) -> void:
	# 每次撕墙纸都复用同一个屏幕震动与粒子实例。
	if _screen_shake != null and _screen_shake.has_method("shake"):
		(_screen_shake as Node).shake(20.0, 0.5)
	if _particle_burst != null and _particle_burst.has_method("set_world_space_particles"):
		_particle_burst.call("set_world_space_particles", true)
	if _particle_burst != null and _particle_burst.has_method("burst"):
		var wall := get_node_or_null("Rooms/Bedroom/WallItem")
		if wall is Node2D:
			(_particle_burst as Node2D).global_position = (wall as Node2D).global_position
		_particle_burst.call("burst")
	if state == 2 and not DialogueManager.is_dialogue_active():
		_show_flow_subtitle(["揭开了！还有一截……"], "bedroom_wall_step")
	elif state >= 3 and not _bedroom_phone_dialogue_started and not DialogueManager.is_dialogue_active():
		_show_flow_subtitle(["呼……是一张星空的海报……？"], "bedroom_wall_final")


func _set_collision_enabled_recursive(n: Node, active: bool) -> void:
	if n == null:
		return
	for child in n.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not active)
		_set_collision_enabled_recursive(child, active)


func _disable_collisions_recursive(n: Node) -> void:
	if n == null:
		return
	for child in n.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)
		_disable_collisions_recursive(child)


## LIGHT-C 震动（5 秒；验收：ScreenShake 调用参数 5.0s）。
func _run_light_shake() -> void:
	if _screen_shake != null and _screen_shake.has_method("shake"):
		(_screen_shake as Node).shake(14.0, LIGHT_SHAKE_DUR)


## LIGHT-C 粒子震撼（沿边缘/边界衔接新场景）；t34 gap ④：持续发射震撼粒子。
func _run_light_particles() -> void:
	_move_light_particles_to_reveal_edge(_light_mask_start_uv)
	if _particle_burst != null and _particle_burst.has_method("set_world_space_particles"):
		(_particle_burst as Node).set_world_space_particles(true)
	if _particle_burst != null and _particle_burst.has_method("start_continuous"):
		(_particle_burst as Node).start_continuous(LIGHT_PARTICLE_DUR)
	elif _particle_burst != null and _particle_burst.has_method("burst"):
		(_particle_burst as Node).burst()


## 开始书房右侧遮罩。DarknessMask 保留自己的缺氧圆孔模式；这里仅暂时切换为方向遮罩。
func _begin_light_side_mask() -> void:
	_light_side_mask_active = false
	if _mask == null or not _mask.has_method("begin_right_side_mask"):
		return
	_mask.set("darkness_color", LIGHT_MASK_COLOR)
	_mask.call("begin_right_side_mask", study_right_x, LIGHT_MASK_SOFTNESS_PX)
	if _mask.has_method("get_right_side_reveal_edge_uv"):
		_light_mask_start_uv = float(_mask.call("get_right_side_reveal_edge_uv"))
	else:
		_light_mask_start_uv = 1.0
	_light_side_mask_active = true


## 粒子始终贴在遮罩揭露边上：墙体看起来由爆裂粒子逐段消散，而非被硬切隐藏。
func _update_light_side_reveal() -> void:
	if not _light_side_mask_active or _mask == null:
		return
	var raw_progress := clampf((_light_show_t - LIGHT_REVEAL_DELAY) / LIGHT_REVEAL_DUR, 0.0, 1.0)
	var eased_progress := raw_progress * raw_progress * (3.0 - 2.0 * raw_progress)
	var edge_uv := lerpf(_light_mask_start_uv, LIGHT_REVEAL_END_UV, eased_progress)
	if _mask.has_method("set_right_side_reveal_edge_uv"):
		_mask.call("set_right_side_reveal_edge_uv", edge_uv)
	_move_light_particles_to_reveal_edge(edge_uv)


func _clear_light_side_mask() -> void:
	_light_side_mask_active = false
	if _mask != null and _mask.has_method("clear_right_side_mask"):
		_mask.call("clear_right_side_mask")


func _move_light_particles_to_reveal_edge(edge_uv: float) -> void:
	if not (_particle_burst is Node2D):
		return
	var vp := get_viewport()
	if vp == null:
		return
	var view_size := vp.get_visible_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	var screen_point := Vector2(edge_uv * view_size.x, view_size.y * 0.66)
	(_particle_burst as Node2D).global_position = vp.get_canvas_transform().affine_inverse() * screen_point


# ─── 信号响应（f5）───

## CorridorEndItem end_confirmed → 黑屏 → 进入卧室 begin()。
## 信号 end_confirmed(state: int) 带 1 参——Godot 4 连接要求形参一致（t6 联调实测：0 参处理器在
## emit 时报 "Method expected 0 argument(s), but called with 1" 且调用被拒）。
func on_corridor_end_confirmed(_state: int) -> void:
	_fade_black_and_begin_bedroom()


## 走廊尽头第一次交互只展示剪刀/墙纸提示，第二次才进入卧室。
func on_corridor_end_interaction(state: int) -> void:
	if state == 1 and not DialogueManager.is_dialogue_active():
		_show_flow_subtitle([
			"地上有一把锈迹斑斑的剪刀",
			"墙边……墙纸裂开了一个口",
			"撕开看看吧",
		], "")


## BreathSystem breath_disable_requested → 关闭呼吸机制。
func on_breath_disable() -> void:
	if _breath != null and _breath.has_method("set_enabled"):
		(_breath as Node).set_enabled(false)


## BedroomEndItem white_screen_end_requested → 全屏白屏（ColorRect 节点，无遮罩）。
func on_white_screen_end() -> void:
	_show_screen_overlay("white")
	GameState.set_process_flag(FLAG_END_WHITE, true)


## 黑屏 + 进入卧室 begin()（全屏黑 ColorRect，无遮罩）。
func _fade_black_and_begin_bedroom() -> void:
	_show_screen_overlay("black")
	_set_corridor_active(false)
	StoryMonitor.lock_input()
	if _bedroom != null and _bedroom.has_method("begin"):
		(_bedroom as Node).begin()
	if _bedroom != null and _bedroom.has_method("prime_arrival_reveal"):
		(_bedroom as Node).prime_arrival_reveal()
	set_stage(STAGE_BEDROOM)
	if _screen_shake != null and _screen_shake.has_method("shake"):
		(_screen_shake as Node).shake(22.0, 0.7)
	# 黑屏短暂停留后隐藏（进卧室重显）
	await get_tree().create_timer(0.8).timeout
	_hide_screen_overlay()
	await get_tree().create_timer(0.2).timeout
	if not _bedroom_arrival_dialogue_shown:
		_bedroom_arrival_dialogue_shown = true
		_show_flow_subtitle([
			"怎么回事，我到哪了？",
			"我应当撕开一半墙纸才是",
			"周围环境……这是进到卧室里了？",
			"墙纸里露出半截被埋没的海报",
			"看一下要不要继续撕开吧",
		], "bedroom_arrival")


## 全屏黑/白 ColorRect 覆盖层控制（无圆形遮罩；黑屏/白屏为流程转场）。
func _show_screen_overlay(kind: String) -> void:
	var n := get_node_or_null(black_screen_path)
	if kind == "white":
		n = get_node_or_null(white_screen_path)
	if n is CanvasItem:
		(n as CanvasItem).visible = true


func _hide_screen_overlay() -> void:
	for p in [black_screen_path, white_screen_path]:
		var n := get_node_or_null(p)
		if n is CanvasItem:
			(n as CanvasItem).visible = false


# ─── 自检（场景级协调：单一 quit 出口，汇总各子系统）───

## 场景级自检：汇总 C3Flow + 各子系统 run_self_check，统一 PASS/FAIL（单一 quit 出口）。
func run_scene_self_check() -> bool:
	var checks: Array[String] = []
	_run_flow_checks(checks)
	# 主角位置断言（f5/§9.3 站立坐标）：玩家应站立于合法位置 y≈948±50 且 x 在场景内（物理帧后读回）
	if _player != null:
		var pp: Vector2 = _player.global_position
		var standing: bool = (pp.y > 900.0 and pp.y < 1000.0 and pp.x >= 0.0 and pp.x <= 7000.0)
		checks.append("player_pos" if standing else "player_pos_FAIL")
	else:
		checks.append("player_ref" if false else "player_ref_FAIL")
	var failed := false
	for c in checks:
		if c.ends_with("FAIL") or c.contains("FAIL"):
			failed = true
		print("[c3_flow] CHECK " + c)
	print("[c3_flow] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	return not failed


## 调用子系统 run_self_check()；返回 true 仅当方法存在且返回 true（void/无方法按 false，避免类型错误）。
func _call_bool_selftest(n: Node) -> bool:
	if n == null or not n.has_method("run_self_check"):
		return false
	var res: Variant = n.call("run_self_check")
	return res is bool and (res as bool)


## 同步强制完成光影演出（仅自检/校验用，跳过计时）：触发 + 立即结束。
func _force_light_show() -> void:
	_trigger_light_show()
	_finish_light_show()


## 全部房间间隔结构（wall_hide_paths）是否隐藏。
func _light_structures_hidden() -> bool:
	if wall_hide_paths.is_empty():
		return false
	for wp in wall_hide_paths:
		var n := get_node_or_null(wp)
		if n == null or n.visible:
			return false
	return true


func _run_flow_checks(checks: Array[String]) -> void:
	_reset_flags()
	set_stage(STAGE_STUDY)
	var camera_frame_ok := _screen_shake != null and _screen_shake.has_method("get_base_offset") \
		and (_screen_shake.call("get_base_offset") as Vector2).distance_to(CAMERA_FRAME_OFFSET) <= 0.01
	checks.append("s0_camera_frame" if camera_frame_ok else "s0_camera_frame_FAIL")
	var gameplay_camera := get_node_or_null(camera_path) as Camera2D
	checks.append("s0_camera_rotation_rendered" if gameplay_camera != null and not gameplay_camera.ignore_rotation else "s0_camera_rotation_rendered_FAIL")
	var initial_camera_bounds := gameplay_camera is CorridorCamera \
		and is_equal_approx((gameplay_camera as CorridorCamera).map_left, world_camera_left) \
		and is_equal_approx((gameplay_camera as CorridorCamera).map_right, world_camera_right)
	checks.append("s0_camera_bounds" if initial_camera_bounds else "s0_camera_bounds_FAIL")
	# The white-model floor inherits a template Player for standalone floor previews. C3 has its
	# own gameplay Player, so the inherited preview body must stay fully inert and never own a camera.
	var white_model_player := get_node_or_null("WhiteModel/Player") as Player
	var white_model_shape := get_node_or_null("WhiteModel/Player/CollisionShape2D") as CollisionShape2D
	var white_model_camera := get_node_or_null("WhiteModel/Player/Camera2D") as Camera2D
	var duplicate_player_disabled := white_model_player != null \
		and white_model_player.process_mode == Node.PROCESS_MODE_DISABLED \
		and not white_model_player.visible \
		and white_model_shape != null and white_model_shape.disabled \
		and white_model_camera != null and not white_model_camera.enabled
	checks.append("s0_white_model_player_disabled" if duplicate_player_disabled else "s0_white_model_player_disabled_FAIL")
	var aspect_keep := str(ProjectSettings.get_setting("display/window/stretch/aspect", "keep")) == "keep"
	checks.append("s0_aspect_keep" if aspect_keep else "s0_aspect_keep_FAIL")
	# The living-room bedroom door is intentionally a proximity-visible no-op before the
	# corridor; its gate stays closed so an early E press cannot enter the bedroom.
	var initial_hall_door := get_node_or_null("Items/BedroomHallDoor") as C3DoorEntryItem
	var initial_hall_door_state := initial_hall_door.current_state if initial_hall_door != null else -1
	if initial_hall_door != null:
		initial_hall_door.touched()
	var initial_hall_door_noop := initial_hall_door != null and initial_hall_door.visible \
		and initial_hall_door.current_state == initial_hall_door_state and current_stage == STAGE_STUDY
	checks.append("s0_hall_door_noop" if initial_hall_door_noop else "s0_hall_door_noop_FAIL")
	# 客厅右侧的终局点在开局就作为未触发占位存在；未完成卧室前不得触发白屏。
	var initial_end_item := get_node_or_null("Items/EndItem") as BedroomEndItem
	var initial_end_placeholder := initial_end_item != null and initial_end_item.visible \
		and initial_end_item.current_state == 0 and not initial_end_item.is_interaction_available()
	checks.append("s0_initial_end_placeholder" if initial_end_placeholder else "s0_initial_end_placeholder_FAIL")
	checks.append("s1_study_locked" if (not GameState.get_process_flag(FLAG_STUDY_ITEMS_UNLOCKED) and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN) and current_stage == STAGE_STUDY) else "s1_study_locked_FAIL")
	on_player_left_study()
	checks.append("s2_leave_study" if (current_stage == STAGE_LEAVE_STUDY and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN)) else "s2_leave_study_FAIL")
	on_paper_collected("paper_living", 100)
	on_paper_collected("paper_kitchen", 100)
	checks.append("s4_unlock_study" if (GameState.get_process_flag(FLAG_STUDY_ITEMS_UNLOCKED) and GameState.get_process_flag(FLAG_STUDY_GATE_OPEN)) else "s4_unlock_study_FAIL")
	on_paper_collected("study_b", 99)
	checks.append("s5_study_b" if not GameState.get_process_flag(FLAG_LIGHT_PHASE_DONE) else "s5_study_b_FAIL")
	on_paper_collected("study_a", 100)
	checks.append("s6_light" if (GameState.get_process_flag(FLAG_LIGHT_PHASE_DONE) and current_stage == STAGE_LIGHT) else "s6_light_FAIL")
	# LIGHT-C 回归：触发时遮罩必须从书房右侧开始连续覆盖视口右端；结束时再关闭。
	# 这避免走廊虽已组装却在门墙消失的一帧提前显露。
	if _player != null:
		_player.global_position.x = LIGHT_TRIGGER_X
	_trigger_light_show()
	var light_mask_started := _mask != null \
		and _mask.has_method("is_side_mask_active") \
		and bool(_mask.call("is_side_mask_active")) \
		and _mask.has_method("covers_right_side_from") \
		and bool(_mask.call("covers_right_side_from", study_right_x))
	checks.append("s6_mask_initial_right_cover" if light_mask_started else "s6_mask_initial_right_cover_FAIL")
	checks.append("s6_input_locked" if StoryMonitor.input_locked else "s6_input_locked_FAIL")
	_finish_light_show()
	var light_mask_finished := _mask != null \
		and _mask.has_method("is_side_mask_active") \
		and not bool(_mask.call("is_side_mask_active"))
	checks.append("s6_mask_finished_off" if light_mask_finished else "s6_mask_finished_off_FAIL")
	checks.append("s6_input_unlocked" if not StoryMonitor.input_locked else "s6_input_unlocked_FAIL")
	checks.append("s6_breath" if GameState.get_process_flag(FLAG_HOLD_BREATH_UNLOCKED) else "s6_breath_FAIL")
	checks.append("s6_hide" if _light_structures_hidden() else "s6_hide_FAIL")
	var sd: float = float(_screen_shake.get("duration")) if _screen_shake != null else 0.0
	checks.append("s6_shake" if sd >= 4.9 else "s6_shake_FAIL(%.1f)" % sd)
	# 光影后走廊必须从书房门直接接出，且三个特异点与尽头的每段距离都不超过一屏内的 1000px。
	var direct_corridor := false
	if _corridor != null:
		var start_x := float(_corridor.get("corridor_start_x"))
		var end_x := float(_corridor.get("end_wall_x"))
		var specials := _corridor.get("special_x") as Array
		if specials.size() == 3:
			var first_x := float(specials[0])
			var second_x := float(specials[1])
			var third_x := float(specials[2])
			direct_corridor = is_equal_approx(start_x, study_right_x) \
				and first_x - study_right_x >= 0.0 and first_x - study_right_x <= 1000.0 \
				and second_x - first_x > 0.0 and second_x - first_x <= 1000.0 \
				and third_x - second_x > 0.0 and third_x - second_x <= 1000.0 \
				and end_x - third_x > 0.0 and end_x - third_x <= 1000.0
	checks.append("s7_direct_corridor_short_segments" if direct_corridor else "s7_direct_corridor_short_segments_FAIL")
	# 光影进入走廊后，主场景的卧室入口与结局交互点不得残留在过场路径上。
	var hall_door := get_node_or_null("Items/BedroomHallDoor") as C3DoorEntryItem
	var living_end_item := get_node_or_null("Items/EndItem") as BedroomEndItem
	var corridor_items_hidden := hall_door != null and living_end_item != null \
		and not hall_door.visible and not hall_door.is_interaction_available() \
		and not living_end_item.visible and not living_end_item.is_interaction_available()
	checks.append("s7_corridor_story_items_hidden" if corridor_items_hidden else "s7_corridor_story_items_hidden_FAIL")
	# 走廊尽头 item 位于独立卧室左墙外侧；进入卧室后必须完全隐藏且不可交互。
	set_stage(STAGE_BEDROOM)
	var corridor_end_item := get_node_or_null(corridor_end_item_path) as Item
	var corridor_end_hidden_in_bedroom := corridor_end_item != null \
		and not corridor_end_item.visible and not corridor_end_item.is_interaction_available()
	checks.append("s8_bedroom_corridor_end_hidden" if corridor_end_hidden_in_bedroom else "s8_bedroom_corridor_end_hidden_FAIL")
	set_stage(STAGE_STUDY)
	_reset_flags()
	on_bedroom_door_named()
	checks.append("s8_bedroom_named" if GameState.get_process_flag(FLAG_BEDROOM_DOOR_ACTIVE) else "s8_bedroom_named_FAIL")


## 物理运行断言（本轮验证升级：headless EXIT=0 不足以发现坠穿等致命缺陷）——
## 等物理帧稳定后读回：①玩家站立 y≈948 不坠穿 ②卧室 begin 后落在配置的左侧出生点、房间尺寸/中轴门/固定构图正确 ③LIGHT-C 后 WallRight.visible=false ④StudyGateBlocker 初始 disabled。
func _physical_assertions() -> bool:
	# 等物理帧稳定（~1s，让玩家落到地面）
	await get_tree().create_timer(1.0).timeout
	var checks: Array[String] = []
	# 卧室是末段专用的独立房间，不得在书房/客厅/走廊阶段提前渲染。
	var bedroom_room := get_node_or_null("Rooms/Bedroom") as CanvasItem
	checks.append("bedroom_hidden_before_entry" if bedroom_room != null and not bedroom_room.visible else "bedroom_hidden_before_entry_FAIL")
	# ①StudyGateBlocker 初始 disabled（出生前不阻挡；_left_study=false 时 blocked=false）
	if gate_blocker_path != NodePath():
		var blocker := get_node_or_null(gate_blocker_path)
		if blocker != null:
			for child in blocker.get_children():
				if child is CollisionShape2D:
					var cs: CollisionShape2D = child as CollisionShape2D
					checks.append("blocker_disabled" if cs.disabled else "blocker_disabled_FAIL")
	# ②玩家站立（站立面 y=988，玩家脚≈980，y≈948；坠穿则 y 大幅>1000 或 <0）
	if _player != null:
		var py: float = _player.global_position.y
		checks.append("stand_y" if (py > 900.0 and py < 1000.0) else "stand_y_FAIL(%.1f)" % py)
	# ③卧室 begin → 落在配置的单房间左侧出生点；门位于中轴、镜头锁住完整房间构图。
	set_stage(STAGE_BEDROOM)
	if _bedroom != null and _bedroom.has_method("begin"):
		(_bedroom as Node).begin()
		# Camera2D updates after the scene's ready chain; assert the stable composition, not its pre-frame value.
		await get_tree().create_timer(0.05).timeout
		var bedroom_root := (_bedroom as Node).get_parent() as Node2D
		var bedroom_spawn: Vector2 = _bedroom.get("bedroom_spawn") as Vector2
		var expected_bedroom_pos := bedroom_root.to_global(bedroom_spawn) if bedroom_root != null else bedroom_spawn
		if _player != null:
			checks.append("bedroom_spawn" if _player.global_position.distance_to(expected_bedroom_pos) < 5.0 else "bedroom_spawn_FAIL(%s)" % str(_player.global_position))
		if bedroom_root != null:
			checks.append("bedroom_width1280" if is_equal_approx(float(bedroom_root.get("room_width")), 1280.0) else "bedroom_width_FAIL(%.1f)" % float(bedroom_root.get("room_width")))
			checks.append("bedroom_player_front" if _player != null and _player.z_index > bedroom_root.z_index else "bedroom_player_front_FAIL")
			var bedroom_door := get_node_or_null("Rooms/Bedroom/DoorItem") as Node2D
			checks.append("bedroom_door_center" if bedroom_door != null and is_equal_approx(bedroom_door.position.x, float(bedroom_root.get("room_width")) * 0.5) else "bedroom_door_center_FAIL")
			var bedroom_camera := get_node_or_null(camera_path) as CorridorCamera
			var configured_frame_x := float(bedroom_camera.get("_frame_center_x")) if bedroom_camera != null else -1.0
			checks.append("bedroom_frame_locked" if bedroom_camera != null and bedroom_camera.get_mode() == CorridorCamera.Mode.FRAME_LOCKED and is_equal_approx(configured_frame_x, (bedroom_frame_left + bedroom_frame_right) * 0.5) else "bedroom_frame_locked_FAIL")
			var displayed_center := bedroom_camera.get_screen_center_position().x if bedroom_camera != null else -1.0
			checks.append("bedroom_frame_visible" if absf(displayed_center - (bedroom_frame_left + bedroom_frame_right) * 0.5) <= 20.0 else "bedroom_frame_visible_FAIL(%.1f)" % displayed_center)
		var corridor_end_wall := get_node_or_null(corridor_end_wall_path)
		var corridor_end_wall_collision := corridor_end_wall.get_node_or_null("CollisionShape2D") as CollisionShape2D if corridor_end_wall != null else null
		checks.append("bedroom_corridor_wall_disabled" if corridor_end_wall_collision != null and corridor_end_wall_collision.disabled else "bedroom_corridor_wall_disabled_FAIL")
	var wall := get_node_or_null("Rooms/Bedroom/WallItem") as BedroomWallItem
	var hall_door := get_node_or_null("Items/BedroomHallDoor") as C3DoorEntryItem
	var living_paper := get_node_or_null("Items/PaperLiving") as C3PaperItem
	var kitchen_paper := get_node_or_null("Items/PaperKitchen") as C3PaperItem
	if wall != null:
		for i in range(3):
			wall.touched()
			await get_tree().process_frame
			var state := i + 1
			var visual := wall.get_node_or_null("Visual") as Polygon2D
			checks.append("bedroom_wall_step%d" % state if wall.current_state == state and visual != null and visual.color == wall.color_for_state(state) else "bedroom_wall_step%d_FAIL" % state)
		checks.append("bedroom_wall_unlock" if GameState.get_process_flag(FLAG_BEDROOM_UNLOCKED) and GameState.get_process_flag(FLAG_BEDROOM_INTERACTIONS_DONE) else "bedroom_wall_unlock_FAIL")
		checks.append("bedroom_breath_disabled" if _breath != null and not bool(_breath.get("_enabled")) else "bedroom_breath_disabled_FAIL")
	if living_paper != null:
		living_paper.touched()
	if kitchen_paper != null:
		kitchen_paper.touched()
	var papers_collected := GameState.get_process_flag(FLAG_PAPER_LIVING) and GameState.get_process_flag(FLAG_PAPER_KITCHEN)
	# Returning from the isolated bedroom restores the living-room walls, while paper collection stays persistent.
	_force_light_show()
	var bedroom_door := get_node_or_null("Rooms/Bedroom/DoorItem") as BedroomDoorItem
	if bedroom_door != null:
		bedroom_door.touched()
		await get_tree().process_frame
		checks.append("bedroom_door_return" if _player != null and _player.global_position.distance_to(Vector2(1850, 948)) < 5.0 else "bedroom_door_return_FAIL(%s)" % str(_player.global_position))
		var returned_camera := get_node_or_null(camera_path) as CorridorCamera
		checks.append("bedroom_camera_restore" if returned_camera != null and returned_camera.get_mode() == CorridorCamera.Mode.FOLLOW_CLAMPED else "bedroom_camera_restore_FAIL")
	checks.append("bedroom_return_stage_living" if current_stage == STAGE_LIVING else "bedroom_return_stage_living_FAIL")
	checks.append("bedroom_return_room_hidden" if bedroom_room != null and not bedroom_room.visible else "bedroom_return_room_hidden_FAIL")
	checks.append("bedroom_return_hall_door_visible" if hall_door != null and hall_door.visible else "bedroom_return_hall_door_visible_FAIL")
	checks.append("bedroom_return_hall_door_usable" if hall_door != null and hall_door.is_interaction_available() else "bedroom_return_hall_door_usable_FAIL")
	checks.append("bedroom_return_papers_retained" if papers_collected and GameState.get_process_flag(FLAG_PAPER_LIVING) and GameState.get_process_flag(FLAG_PAPER_KITCHEN) else "bedroom_return_papers_retained_FAIL")
	checks.append("bedroom_return_structures_restored" if not _light_structures_hidden() else "bedroom_return_structures_restored_FAIL")
	if _corridor is CanvasItem:
		checks.append("bedroom_return_corridor_hidden" if not (_corridor as CanvasItem).visible else "bedroom_return_corridor_hidden_FAIL")
	if corridor_floor_path != NodePath():
		var corridor_floor := get_node_or_null(corridor_floor_path)
		checks.append("bedroom_return_floor_hidden" if corridor_floor is CanvasItem and not (corridor_floor as CanvasItem).visible else "bedroom_return_floor_hidden_FAIL")
	# A completed bedroom must support repeated living-room door round trips without resetting collected state.
	if hall_door != null:
		hall_door.touched()
		await get_tree().process_frame
	checks.append("bedroom_reentry_stage" if current_stage == STAGE_BEDROOM else "bedroom_reentry_stage_FAIL")
	var resumed_door := get_node_or_null("Rooms/Bedroom/DoorItem") as BedroomDoorItem
	checks.append("bedroom_return_door_retained" if resumed_door != null and resumed_door.is_interaction_available() else "bedroom_return_door_retained_FAIL")
	checks.append("bedroom_living_papers_retained" if papers_collected and GameState.get_process_flag(FLAG_PAPER_LIVING) and GameState.get_process_flag(FLAG_PAPER_KITCHEN) else "bedroom_living_papers_retained_FAIL")
	if resumed_door != null:
		resumed_door.touched()
		await get_tree().process_frame
	checks.append("bedroom_second_return" if _player != null and _player.global_position.distance_to(Vector2(1850, 948)) < 5.0 else "bedroom_second_return_FAIL")
	checks.append("bedroom_second_return_living" if current_stage == STAGE_LIVING else "bedroom_second_return_living_FAIL")
	checks.append("bedroom_second_return_room_hidden" if bedroom_room != null and not bedroom_room.visible else "bedroom_second_return_room_hidden_FAIL")
	checks.append("bedroom_second_return_structures_restored" if not _light_structures_hidden() else "bedroom_second_return_structures_restored_FAIL")
	if room_right_wall_collision_path != NodePath():
		var restored_right_wall := get_node_or_null(room_right_wall_collision_path)
		checks.append("bedroom_return_right_wall_enabled" if restored_right_wall is CollisionShape2D and not (restored_right_wall as CollisionShape2D).disabled else "bedroom_return_right_wall_enabled_FAIL")
	# ④重新验证光影隐藏本身：上面已验证从卧室返回会恢复墙体，因此这里直接重放结构隐藏。
	# _trigger_light_show() 只允许正常流程触发一次，不能用于这次自检重放。
	_hide_room_structures()
	await get_tree().process_frame
	checks.append("light_hide" if _light_structures_hidden() else "light_hide_FAIL")
	if _screen_shake != null:
		var sdu: float = float(_screen_shake.get("duration"))
		checks.append("light_shake5" if sdu >= 4.9 else "light_shake5_FAIL(%.1f)" % sdu)
	checks.append("light_breath" if GameState.get_process_flag(FLAG_HOLD_BREATH_UNLOCKED) else "light_breath_FAIL")
	# ⑥走廊地板：传送玩家到走廊中心（stop_center_x=4480），物理稳定 ≥2s 后不坠穿（y≈948 站立）+ 地板左边界覆盖玩家 x（t36）
	# 前面的回程断言会把阶段恢复到客厅；切回走廊后再验证右墙已解除碰撞。
	set_stage(STAGE_CORRIDOR)
	if _player != null:
		_player.global_position = Vector2(4480.0, 940.0)
		await get_tree().create_timer(2.0).timeout
		var cy: float = _player.global_position.y
		checks.append("corridor_stand" if (cy > 900.0 and cy < 1000.0) else "corridor_stand_FAIL(%.1f)" % cy)
		if room_right_wall_collision_path != NodePath():
			var right_wall_collision := get_node_or_null(room_right_wall_collision_path)
			checks.append("corridor_right_wall_disabled" if right_wall_collision is CollisionShape2D and (right_wall_collision as CollisionShape2D).disabled else "corridor_right_wall_disabled_FAIL")
		# 地板左边界须 ≤ 玩家 x；从实际碰撞形状读取宽度，避免白模尺寸改版后误报。
		var cf_node: Node = get_node_or_null("CorridorFloor")
		if cf_node != null:
			var floor_left: float = cf_node.global_position.x
			var floor_shape := cf_node.get_node_or_null("CollisionShape2D")
			if floor_shape is CollisionShape2D and floor_shape.shape is RectangleShape2D:
				floor_left -= (floor_shape.shape as RectangleShape2D).size.x * 0.5
			checks.append("floor_covers_x" if floor_left <= _player.global_position.x else "floor_covers_x_FAIL(%.1f)" % floor_left)
	var failed := false
	for c in checks:
		if c.ends_with("FAIL") or c.contains("FAIL"):
			failed = true
		print("[c3_flow] PHYS " + c)
	print("[c3_flow] PHYSICAL " + ("PASS" if not failed else "FAIL"))
	return not failed


# ─── 场景编排 ───

func _ready_extra() -> void:
	_resolve_scene_refs()
	_activate_camera()
	_setup_room_table()
	_bind_doors()
	_sync_study_door_lock()
	_refresh_entry_door_flow_refs()
	_connect_scene_signals()
	set_stage(current_stage)
	_apply_phase_arg()
	if not _phase_debug_loaded \
		and "--self-check" not in OS.get_cmdline_user_args() \
		and "--physical" not in OS.get_cmdline_user_args():
		call_deferred("_begin_intro_sequence")


func _begin_intro_sequence() -> void:
	if _intro_active or _phase_debug_loaded:
		return
	_intro_active = true
	_intro_waiting_breath = false
	_intro_breathed = false
	_intro_text_stage = 0
	_intro_text_elapsed = 0.0
	StoryMonitor.lock_input()
	if _breath != null and _breath.has_method("set_countdown_rate"):
		_breath.call("set_countdown_rate", INTRO_BREATH_RATE, true)
	if not DialogueManager.dialogue_finished.is_connected(_on_intro_dialogue_finished):
		DialogueManager.dialogue_finished.connect(_on_intro_dialogue_finished)
	DialogueManager.start_dialogue(INTRO_DIALOGUE_PATH, DialogueManager.MODE_INTERACTIVE)


func _on_intro_dialogue_finished() -> void:
	if not _intro_active or _intro_text_stage != 0:
		return
	# DialogueBox unlocks on completion; retain the intro freeze until its final hint ends.
	StoryMonitor.lock_input()
	_intro_waiting_breath = true
	_intro_text_stage = 1
	_intro_text_elapsed = 0.0
	_set_intro_text(INTRO_FIRST_TEXT)


func _set_intro_text(value: String) -> void:
	# 开场悬浮提示直接使用 main 分支 MODE_GLITCH 组件。
	DialogueManager.start_lines([value], DialogueManager.MODE_GLITCH)


func _hide_intro_text() -> void:
	# MODE_GLITCH 按自身生命周期自动清理。
	pass


func _unhandled_input(event: InputEvent) -> void:
	if not _intro_active or not _intro_waiting_breath or _intro_breathed:
		return
	if event is InputEventKey and event.pressed and not event.echo \
		and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		_intro_breathed = true
		_intro_waiting_breath = false
		_intro_text_stage = 2
		_intro_text_elapsed = 0.0
		if _breath != null and _breath.has_method("is_breathe_input_unlocked") \
			and _breath.call("is_breathe_input_unlocked") and _breath.has_method("breathe"):
			_breath.call("breathe", true)
		_set_intro_text(INTRO_SECOND_TEXT)


func _update_intro(delta: float) -> void:
	if not _intro_active:
		return
	if _intro_text_stage < 2:
		return
	_intro_text_elapsed += delta
	if _intro_text_stage == 2 and _intro_text_elapsed >= INTRO_TEXT_DURATION:
		_intro_text_stage = 3
		_intro_text_elapsed = 0.0
		_set_intro_text(INTRO_THIRD_TEXT)
		_show_flow_floating("总之，先进里面看看吧\n得时刻注意呼吸", Vector2(1080.0, 640.0), 1200.0)
		# The third hint marks the end of the mandatory opening freeze.
		_intro_waiting_breath = false
		StoryMonitor.unlock_input()
	elif _intro_text_stage == 3 and _intro_text_elapsed >= INTRO_TEXT_DURATION:
		_hide_intro_text()
		_intro_text_stage = 4
		_intro_active = false


## 绑定主 Player 到两个自动门（左门按流程锁定/解锁，右门常开）。
## 不改 c3_floor.tscn/FloorTemplate.gd/player.tscn：仅在此连接，与 FloorTemplate 既有连接并存无害(body 不匹配不触发)。
func _bind_doors() -> void:
	if door_study_living_path != NodePath():
		var d := get_node_or_null(door_study_living_path)
		if d is Area2D:
			_door_study_living = d
			(d as Area2D).body_entered.connect(_on_door_body_entered.bind(d))
			(d as Area2D).body_exited.connect(_on_door_body_exited.bind(d))
	if door_living_dining_path != NodePath():
		var d2 := get_node_or_null(door_living_dining_path)
		if d2 is Area2D:
			_door_living_dining = d2
			(d2 as Area2D).body_entered.connect(_on_door_body_entered.bind(d2))
			(d2 as Area2D).body_exited.connect(_on_door_body_exited.bind(d2))


## Child items become ready before this root enters the c3flow group. Re-resolve the hall entry after
## registration so a completed-bedroom return can use its existing door without recreating the scene.
func _refresh_entry_door_flow_refs() -> void:
	for item in _find_items():
		if item is C3DoorEntryItem and item.has_method("_resolve_flow"):
			item.call("_resolve_flow")


## 玩家进入门检测区：右门常开；左门按锁定(已出书房且 study_gate_open=false)禁开+强制关。
func _on_door_body_entered(body: Node2D, door: Node) -> void:
	if body == null or body is Player == false:
		return
	if body != _player:
		return
	if door == _door_study_living:
		# 左门锁定：不 open 且强制 close（blocker 物理兜底）
		if _left_study and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN):
			_sync_study_door_lock()
			return
	if door.has_method("open"):
		door.open()


## 玩家离开门检测区：关闭门。
func _on_door_body_exited(body: Node2D, door: Node) -> void:
	if body == null or body != _player:
		return
	if door.has_method("close"):
		door.close()


## 使主相机当前(玩家 Camera2D)——交互提示使用世界→屏幕换算需相机变换。
func _activate_camera() -> void:
	var cam: Camera2D = null
	if camera_path != NodePath():
		var c := get_node_or_null(camera_path)
		if c is Camera2D:
			cam = c as Camera2D
	elif _player != null:
		for child in _player.get_children():
			if child is Camera2D:
				cam = child as Camera2D
				break
	if cam != null:
		cam.make_current()
		# ScreenShake 的跷跷板靠 Camera2D.rotation 渲染；默认 ignore_rotation 会让成品静止。
		cam.ignore_rotation = false
		# t34 gap ①：帧取景偏移——角色站画幅地面（视口中心上移，玩家位于下三分一带）
		cam.offset = CAMERA_FRAME_OFFSET
		# 将固定构图作为 ScreenShake 的明确基准，持续特效不能再从瞬时 offset 猜测它。
		if _screen_shake != null and _screen_shake.has_method("set_base_offset"):
			(_screen_shake as Node).call("set_base_offset", CAMERA_FRAME_OFFSET)


## 配置 RoomTable 房间区间（§3.4：书房[0,1280]/客厅[1280,2560]/厨房[餐厅位,2560,3840]）。
func _setup_room_table() -> void:
	if room_table_path == NodePath():
		return
	var rt := get_node_or_null(room_table_path)
	if rt != null and rt.has_method("set_rooms"):
		rt.set_rooms({
			"room1": {"x_min": 0.0, "x_max": 1280.0},
			"room2": {"x_min": 1280.0, "x_max": 2560.0},
			"room3": {"x_min": 2560.0, "x_max": 3840.0},
			"corridor": {"x_min": 3840.0, "x_max": 12000.0}
		})


## 连接子系统信号（f5：门 E→进卧室 / end_confirmed→黑屏→begin / breath_disable→set_enabled(false) / white_screen→全屏白）。
func _connect_scene_signals() -> void:
	# E 键 → 范围内 item touched()（问题三：补 Player.interact_pressed 链路）
	if _player != null and _player.has_signal("interact_pressed"):
		_player.connect("interact_pressed", Callable(self, "_on_interact_pressed"))
	# 交互成功保留轻微 ItemShake 占位，不再显示“OK”提示。
	for it in _find_items():
		if it.has_signal("interaction_succeeded"):
			it.connect("interaction_succeeded", Callable(self, "_on_item_succeeded").bind(it))
	if _bedroom != null:
		if _bedroom.has_signal("breath_disable_requested"):
			_bedroom.connect("breath_disable_requested", Callable(self, "on_breath_disable"))
		if _bedroom.has_signal("white_screen_end_requested"):
			_bedroom.connect("white_screen_end_requested", Callable(self, "on_white_screen_end"))
		if _bedroom.has_signal("return_to_living_room_requested"):
			_bedroom.connect("return_to_living_room_requested", Callable(self, "_on_bedroom_return_to_living_room"))
	var bedroom_wall := get_node_or_null("Rooms/Bedroom/WallItem")
	if bedroom_wall != null and bedroom_wall.has_signal("wall_updated"):
		bedroom_wall.connect("wall_updated", Callable(self, "_on_bedroom_wall_updated"))
	if _corridor != null:
		if _corridor.has_signal("corridor_entered"):
			_corridor.connect("corridor_entered", Callable(self, "_on_corridor_entered"))
		if _corridor.has_signal("corridor_finite"):
			_corridor.connect("corridor_finite", Callable(self, "_on_corridor_finite"))
		if _corridor.has_signal("special_point_passed"):
			_corridor.connect("special_point_passed", Callable(self, "_on_corridor_special_point_passed"))
		if _corridor.has_signal("breath_hint_requested"):
			_corridor.connect("breath_hint_requested", Callable(self, "_on_special_breath_hint_requested"))
		if _corridor.has_signal("special_breath_hint_cleared"):
			_corridor.connect("special_breath_hint_cleared", Callable(self, "_on_special_breath_hint_cleared"))
		if _corridor.has_signal("corridor_input_freeze_changed"):
			_corridor.connect("corridor_input_freeze_changed", Callable(self, "_on_corridor_input_freeze_changed"))
	if corridor_end_item_path != NodePath():
		var ce := get_node_or_null(corridor_end_item_path)
		if ce != null and ce.has_signal("end_confirmed"):
			ce.connect("end_confirmed", Callable(self, "on_corridor_end_confirmed"))
		if ce != null and ce.has_signal("interaction_succeeded"):
			ce.connect("interaction_succeeded", Callable(self, "_on_corridor_end_interaction_signal"))


func _on_corridor_entered() -> void:
	GameState.set_process_flag(FLAG_CORRIDOR_ENTERED, true)


func _on_corridor_finite() -> void:
	if current_stage == STAGE_CORRIDOR:
		set_stage(STAGE_CORRIDOR_END)


func _on_corridor_special_point_passed(index: int) -> void:
	# 第三个特异点通过的瞬间就告知尽头位置，不再等角色走到尽头附近。
	if index != 2 or _corridor_end_hint_shown or _corridor == null:
		return
	_corridor_end_hint_shown = true
	var end_x := float(_corridor.get("end_wall_x"))
	_show_flow_floating("尽头似乎有什么东西", Vector2(end_x - 120.0, 650.0), end_x, false)


func _on_special_breath_hint_requested(message: String = "长按空格屏住呼吸，这样或许好受一点") -> void:
	_show_flow_floating(message, Vector2(260.0, -300.0), INF, true)


func _on_special_breath_hint_cleared() -> void:
	_hide_flow_floating()


func _on_corridor_input_freeze_changed(frozen: bool) -> void:
	if not frozen:
		_hide_flow_floating()


func _on_corridor_end_interaction_signal() -> void:
	var ce := get_node_or_null(corridor_end_item_path)
	if ce != null and int(ce.get("current_state")) == 1:
		on_corridor_end_interaction(1)


## item 确定交互成功 → 轻微反馈占位，不显示“OK”。
func _on_item_succeeded(it: Node) -> void:
	if it is Node2D:
		var shaker := it.get_node_or_null("ItemShake") as ItemShake
		if shaker == null:
			shaker = ItemShake.new()
			shaker.name = "ItemShake"
			(it as Node2D).add_child(shaker)
		shaker.shake(4.0, 0.18)


## E 键按下 → 对统一范围判定命中的 item 调 touched()。
func _on_interact_pressed() -> void:
	if _player == null or DialogueManager.is_dialogue_active():
		return
	var items := _find_items()
	for it in items:
		if it is Area2D:
			var area := it as Area2D
			var in_range := false
			if area.has_method("is_player_in_interaction_range"):
				in_range = bool(area.call("is_player_in_interaction_range", _player))
			else:
				in_range = area.get_overlapping_bodies().has(_player)
			if area.has_method("touched") and in_range:
				if area.name == "BedroomHallDoor" and current_stage < STAGE_LIGHT:
					if not _hall_door_subtitle_shown:
						_hall_door_subtitle_shown = true
						_show_flow_subtitle([
							"门紧锁着，进不去里面的房间",
							"门锁旁边挂着三个相框",
							"大小像是正好能塞进一张试卷",
						], "hall_door")
					return
				if area.name == "EndItem" and current_stage < STAGE_LIGHT \
					and not GameState.get_process_flag(FLAG_BEDROOM_INTERACTIONS_DONE):
					if not _end_item_subtitle_shown:
						_end_item_subtitle_shown = true
						_show_flow_subtitle([
							"盒子里面躺着数架望远镜",
							"或许许久无人打理，沾满灰尘",
						], "")
					return
				if area.name == "EndItem" and current_stage == STAGE_LIVING \
					and GameState.get_process_flag(FLAG_BEDROOM_INTERACTIONS_DONE):
					if not _bedroom_return_end_dialogue_shown:
						_bedroom_return_end_dialogue_shown = true
						_show_flow_subtitle([
							"可惜了，多好的东西白白摔到地上",
							"捡起来擦擦看还能不能用",
						], "bedroom_return_end")
					return
				area.touched()
				return


## 收集 items_root_path + bedroom_items_path 下的 Item（Area2D）子节点（f1：卧室 E 链需覆盖 Rooms/Bedroom 的 WallItem/DoorItem/EndItem）。
func _find_items() -> Array[Node]:
	var res: Array[Node] = []
	if items_root_path != NodePath():
		var root := get_node_or_null(items_root_path)
		if root != null:
			for child in root.get_children():
				if child is Area2D:
					res.append(child)
	if bedroom_items_path != NodePath():
		var broot := get_node_or_null(bedroom_items_path)
		if broot != null:
			for child in broot.get_children():
				if child is Area2D:
					res.append(child)
	return res


## 按 study_gate_open 开关书房-客厅门禁阻挡（物理阻挡，f6）。
func _apply_gate_blocker() -> void:
	if gate_blocker_path == NodePath():
		return
	var blocker := get_node_or_null(gate_blocker_path)
	if blocker == null:
		return
	# 仅当『已出过书房 且 study_gate_open=false』时阻挡（f3：初始不阻挡，可自由出入书房）
	var blocked: bool = _left_study and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN)
	for child in blocker.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not blocked)
	blocker.visible = blocked


## 书房门锁定时停用检测区并立即关门：防止已开始的开门动画跨越锁定阈值，也不让后续靠近重触发。
## 收集完客厅、厨房试卷后 study_gate_open=true，会重新启用原有自动门行为。
func _sync_study_door_lock() -> void:
	if _door_study_living == null:
		return
	var locked: bool = _left_study and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN)
	if _door_study_living.has_method("set_auto_open_enabled"):
		_door_study_living.call("set_auto_open_enabled", not locked)
	if _door_study_living is Area2D:
		(_door_study_living as Area2D).monitoring = not locked
	if locked and not _door_study_living.has_method("set_auto_open_enabled") and _door_study_living.has_method("_do_close"):
		_door_study_living.call("_do_close")


func _resolve_scene_refs() -> void:
	if player_path != NodePath():
		var n := get_node_or_null(player_path)
		if n is Node2D:
			_player = n as Node2D
	if corridor_path != NodePath():
		_corridor = get_node_or_null(corridor_path)
	if corridor_assembly_path != NodePath():
		_corridor_assembly = get_node_or_null(corridor_assembly_path)
	if bedroom_path != NodePath():
		_bedroom = get_node_or_null(bedroom_path)
	if breath_path != NodePath():
		_breath = get_node_or_null(breath_path)
	if darkness_mask_path != NodePath():
		_mask = get_node_or_null(darkness_mask_path)  # 保留解析（呼吸缺氧遮罩独立使用场景 DarknessMask；本类演出不再使用）
	if screen_shake_path != NodePath():
		_screen_shake = get_node_or_null(screen_shake_path)
	if particle_burst_path != NodePath():
		_particle_burst = get_node_or_null(particle_burst_path)


## 读取命令行 --phase=<1..9> 直接跳到对应阶段（调试入口；main.tscn 不动）。
func _apply_phase_arg() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="):
			var p := int(arg.trim_prefix("--phase="))
			if p >= STAGE_STUDY and p <= STAGE_BEDROOM:
				set_stage(p)
				if p >= STAGE_BEDROOM and _bedroom != null and _bedroom.has_method("begin"):
					(_bedroom as Node).begin()
				_phase_debug_loaded = true


func _process(delta: float) -> void:
	if _intro_active:
		_update_intro(delta)
	if _phase_debug_loaded:
		return
	if _player == null:
		return
	if not _tv_subtitle_shown and _player.global_position.x >= LIVING_TV_X \
		and current_stage >= STAGE_LEAVE_STUDY and current_stage < STAGE_LIGHT \
		and not DialogueManager.is_dialogue_active():
		_tv_subtitle_shown = true
		_show_flow_subtitle(["这间房子相当整洁，电视柜上一丝灰尘都没有留下"], "")
	if (current_stage == STAGE_CORRIDOR or current_stage == STAGE_CORRIDOR_END) \
		and not _corridor_end_hint_shown and _corridor != null \
		and _player.global_position.x >= float(_corridor.get("end_wall_x")) - 240.0:
		_corridor_end_hint_shown = true
		_show_flow_floating("尽头似乎有什么东西", Vector2(float(_corridor.get("end_wall_x")) - 120.0, 650.0), float(_corridor.get("end_wall_x")), false)
	if current_stage == STAGE_LIVING and GameState.get_process_flag(FLAG_BEDROOM_INTERACTIONS_DONE) \
		and not _bedroom_return_end_dialogue_shown and not DialogueManager.is_dialogue_active():
		var returned_end := get_node_or_null("Items/EndItem") as Node2D
		if returned_end != null and _player.global_position.x >= returned_end.global_position.x - 180.0:
			_bedroom_return_end_dialogue_shown = true
			_show_flow_subtitle([
				"可惜了，多好的东西白白摔到地上",
				"捡起来擦擦看还能不能用",
			], "bedroom_return_end")
	if current_stage == STAGE_STUDY:
		_poll_study_door_fallback()
		# t14 锁门余量：x ≥ study_lock_x（完全出书房）才触发 on_player_left_study（锁门+blocker）。
		if _player.global_position.x >= study_lock_x:
			on_player_left_study()
	elif current_stage == STAGE_LIGHT:
		_process_light_show(delta)


## t14 兜底轮询：窗口环境 body_entered 信号偶发丢失时，STAGE_STUDY 玩家接近书房-客厅左门
## （x ∈ [door_fallback_min_x, door_fallback_max_x]）且门未开 → 直接 open()（每帧检查，open 幂等）。
func _poll_study_door_fallback() -> void:
	if _door_study_living == null:
		return
	var is_open: bool = bool(_door_study_living.get("is_open"))
	if is_open:
		return
	var px: float = _player.global_position.x
	if px >= door_fallback_min_x and px <= door_fallback_max_x:
		if _door_study_living.has_method("open"):
			_door_study_living.open()


## 光影演出驱动：未触发时检测角色走到书房右侧；触发后遮罩跟随粒子向右揭露已组装走廊。
func _process_light_show(delta: float) -> void:
	if not _light_triggered:
		if _player != null and _player.global_position.x >= LIGHT_TRIGGER_X:
			_trigger_light_show()
		return
	_light_show_t += delta
	_update_light_side_reveal()
	if _light_show_t >= LIGHT_SHAKE_DUR:
		_finish_light_show()
