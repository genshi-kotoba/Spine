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

# ─── LIGHT 分步子步骤（§7.2 A-E；t32 重做为分步时序：A 书房外全黑→B 出门黑屏重显+重置→C 二次靠门触发消散+震动+粒子→D 微压暗→E 解锁屏息）───
const LIGHT_NONE := 0
const LIGHT_A := 1
const LIGHT_B := 2
const LIGHT_C := 3
const LIGHT_D := 4
const LIGHT_E := 5

## LIGHT 时序常量（s）。
const LIGHT_C_DUR := 1.8
const LIGHT_D_DUR := 1.5
const LIGHT_PARTICLE_DUR := 2.5
const LIGHT_SHAKE_DUR := 5.0
const LIGHT_B_REVEAL := 1.2
## 主相机竖向取景偏移（参照 c3_floor camera_position_offset=(0,-336.5) 口径；视口 1920x1240）：
## 让角色视觉站画幅地面位置而非竖正中（t34 gap ①，不改 player.tscn）。
const CAMERA_FRAME_OFFSET := Vector2(0, -336.5)

## LIGHT 遮罩参数（白模：亮区=书房/跟随玩家，四周全黑；C 后亮区扩大；D 微压暗氛围）。
const LIGHT_A_INNER := 500.0
const LIGHT_A_OUTER := 900.0
const LIGHT_A_COLOR := Color(0.01, 0.01, 0.02, 1)
const LIGHT_BLACK := Color(0.0, 0.0, 0.0, 1.0)
const LIGHT_EXPAND_INNER := 900.0
const LIGHT_EXPAND_OUTER := 1350.0
const LIGHT_DIM_COLOR := Color(0.05, 0.05, 0.07, 0.30)
const LIGHT_DIM_INNER := 150.0
const LIGHT_DIM_OUTER := 360.0
## LIGHT-A 亮区固定中心（书房中心 x=640；t34 gap ③：A 以书房为亮区，play follow_player=false）。
const LIGHT_STUDY_CENTER := Vector2(640, 594)

## LIGHT 分步运行状态（t32）。
var _light_step: int = LIGHT_NONE
var _light_b_reset_done: bool = false
var _light_c_t: float = 0.0
var _light_d_t: float = 0.0

signal stage_changed(new_stage: int)

## ─── 场景编排引用（t16 接线）───
@export var player_path: NodePath
@export var corridor_path: NodePath
@export var bedroom_path: NodePath
@export var breath_path: NodePath
@export var darkness_mask_path: NodePath
@export var screen_shake_path: NodePath
@export var particle_burst_path: NodePath
@export var corridor_end_item_path: NodePath
@export var gate_blocker_path: NodePath
@export var room_table_path: NodePath
@export var items_root_path: NodePath
@export var bedroom_items_path: NodePath
@export var parallax_path: NodePath
@export var ok_popup_path: NodePath
@export var camera_path: NodePath
@export var door_study_living_path: NodePath
@export var door_living_dining_path: NodePath
@export var study_spawn: Vector2 = Vector2(320, 948)
@export var study_right_x: float = 1280.0
## LIGHT-C 需隐藏的门/墙（NodePath；如 书房-客厅墙、auto_door、最右侧墙）。
@export var wall_hide_paths: Array[NodePath] = []

var _player: Node2D = null
var _left_study: bool = false
var _corridor: Node = null
var _door_study_living: Node = null
var _door_living_dining: Node = null
var _bedroom: Node = null
var _breath: Node = null
var _mask: Node = null
var _screen_shake: Node = null
var _particle_burst: Node = null
var _phase_debug_loaded: bool = false


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
	_light_step = LIGHT_NONE
	_light_b_reset_done = false
	_light_c_t = 0.0
	_light_d_t = 0.0


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
	if s == STAGE_CORRIDOR_END:
		GameState.set_process_flag(FLAG_CORRIDOR_END, true)
	if s >= STAGE_BEDROOM:
		GameState.set_process_flag(FLAG_BEDROOM_UNLOCKED, true)
		GameState.set_process_flag(FLAG_BEDROOM_INTERACTIONS_DONE, true)
	if _corridor != null:
		if _corridor.has_method("set_enabled"):
			(_corridor as Node).set_enabled(s >= STAGE_CORRIDOR)
		else:
			_corridor.set("enabled", s >= STAGE_CORRIDOR)
	if s == STAGE_LIGHT:
		_start_light_a()


# ─── 事件钩子（场景/t16 接线调用）───

## 玩家离开书房 → 锁书房-客厅门（无法回）+ 进入 LEAVE_STUDY（§6.2）。
func on_player_left_study() -> void:
	_left_study = true
	GameState.set_process_flag(FLAG_STUDY_GATE_OPEN, false)
	_apply_gate_blocker()
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
		if current_stage < STAGE_RETURN_STUDY:
			set_stage(STAGE_RETURN_STUDY)
	if _study_papers_collected >= 2 and not GameState.get_process_flag(FLAG_LIGHT_PHASE_DONE):
		GameState.set_process_flag(FLAG_LIGHT_PHASE_DONE, true)
		set_stage(STAGE_LIGHT)


# ─── 卧室门三态（§5.2）───

func on_bedroom_door_named() -> void:
	GameState.set_process_flag(FLAG_BEDROOM_DOOR_ACTIVE, true)


## 卧室门 E → 搬运进卧室（begin + 黑屏渐变）。供场景连接 BedroomHallDoor 的 gate_ok/touched。
func on_enter_bedroom() -> void:
	_fade_black_and_begin_bedroom()


# ─── LIGHT 序列（§7.2 A-E 分步时序；t32 重做）───
## 进入 STAGE_LIGHT 只起步 A（书房外全黑，亮区跟随玩家）；B/C/D/E 由 _process_light 依玩家事件 / 计时推进。

## A 步：遮罩全黑（除书房=跟随玩家的亮区），等待玩家出门。
func _start_light_a() -> void:
	if _light_step != LIGHT_NONE:
		return
	_light_step = LIGHT_A
	_light_b_reset_done = false
	_light_c_t = 0.0
	_light_d_t = 0.0
	_mask_config(LIGHT_A_INNER, LIGHT_A_OUTER, LIGHT_A_COLOR, false, LIGHT_STUDY_CENTER)


## B 步：玩家出门 → 黑屏渐变 → 重置书房初始位 → 重显（亮区回 A 态），随后等待二次靠门。
func _enter_light_b() -> void:
	if _light_step != LIGHT_A and _light_step != LIGHT_B:
		return
	_light_step = LIGHT_B
	_light_b_reset_done = false
	if _mask == null:
		_light_b_reset_done = true
		_reset_player_to_study()
		return
	_mask.enabled = true
	# t34 gap ③：B 保持固定书房亮区（follow_player=false），重显回 A 态（书房为亮区）
	_mask.follow_player = false
	_mask.center_global = LIGHT_STUDY_CENTER
	var tw := create_tween()
	# 黑屏渐变（A 态 → 全黑）
	tw.tween_property(_mask, "darkness_color", LIGHT_BLACK, 0.5)
	tw.tween_property(_mask, "radius_inner", 12.0, 0.5)
	tw.tween_property(_mask, "radius_outer", 24.0, 0.5)
	# 黑屏中点重置玩家 → 重显回 A 态（亮区）
	tw.tween_callback(Callable(self, "_reset_player_to_study"))
	tw.tween_property(_mask, "darkness_color", LIGHT_A_COLOR, LIGHT_B_REVEAL)
	tw.tween_property(_mask, "radius_inner", LIGHT_A_INNER, LIGHT_B_REVEAL)
	tw.tween_property(_mask, "radius_outer", LIGHT_A_OUTER, LIGHT_B_REVEAL)
	tw.tween_callback(Callable(self, "_mark_light_b_reset_done"))


## C 步：二次靠门 → 房间间隔门/墙全部消散 + 震动 5 秒 + 粒子震撼沿边沿衔接 + 遮罩亮区缓缓展开。
func _enter_light_c() -> void:
	if _light_step != LIGHT_B:
		return
	_light_step = LIGHT_C
	_light_c_t = 0.0
	_hide_room_structures()
	_run_light_shake()
	_run_light_particles()
	if _mask != null and _mask.enabled:
		# t34 gap ④：亮区随角色向走廊走、缓缓展开（follow_player=true + 1.5-2s Tween 扩向走廊）
		_mask.follow_player = true
		_tween_mask_to(LIGHT_A_COLOR, LIGHT_EXPAND_INNER, LIGHT_EXPAND_OUTER, LIGHT_C_DUR)


## D 步：环境微压暗（只渲染氛围，亮区四周轻微暗角）。
func _enter_light_d() -> void:
	if _light_step != LIGHT_C:
		return
	_light_step = LIGHT_D
	_light_d_t = 0.0
	if _mask != null and _mask.enabled:
		_tween_mask_to(LIGHT_DIM_COLOR, LIGHT_DIM_INNER, LIGHT_DIM_OUTER, LIGHT_D_DUR)


## E 步：解锁长按屏息 + 进入走廊阶段（启动无限走廊）。
func _finish_light_e() -> void:
	if _light_step != LIGHT_D and _light_step != LIGHT_E:
		return
	if _light_step == LIGHT_E:
		return
	_light_step = LIGHT_E
	GameState.set_process_flag(FLAG_HOLD_BREATH_UNLOCKED, true)
	GameState.set_process_flag(FLAG_LIGHT_PHASE_DONE, true)
	if current_stage < STAGE_CORRIDOR:
		set_stage(STAGE_CORRIDOR)


func _mark_light_b_reset_done() -> void:
	_light_b_reset_done = true


## 配置遮罩到指定亮区参数（即时态；供各 LIGHT 步设置及自检强制态）。
## follow=false 时以 center 为固定亮区中心（t34 gap ③：A 固定书房亮区，B 保持固定）。
func _mask_config(inner: float, outer: float, col: Color, follow: bool = true, center: Vector2 = Vector2.ZERO) -> void:
	if _mask == null:
		return
	_mask.enabled = true
	_mask.follow_player = follow
	_mask.darkness_color = col
	_mask.radius_inner = inner
	_mask.radius_outer = outer
	if not follow:
		_mask.center_global = center


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
	if _particle_burst != null and _particle_burst.has_method("start_continuous"):
		(_particle_burst as Node).start_continuous(LIGHT_PARTICLE_DUR)
	elif _particle_burst != null and _particle_burst.has_method("burst"):
		(_particle_burst as Node).burst()


# ─── 信号响应（f5）───

## CorridorEndItem end_confirmed → 黑屏 → 进入卧室 begin()。
func on_corridor_end_confirmed() -> void:
	_fade_black_and_begin_bedroom()


## BreathSystem breath_disable_requested → 关闭呼吸机制。
func on_breath_disable() -> void:
	if _breath != null and _breath.has_method("set_enabled"):
		(_breath as Node).set_enabled(false)


## BedroomEndItem white_screen_end_requested → 全屏白渐变结束。
func on_white_screen_end() -> void:
	if _mask != null:
		_mask.enabled = true
		_tween_mask_to(Color(1, 1, 1, 1), 4000.0, 4500.0, 0.8)
	GameState.set_process_flag(FLAG_END_WHITE, true)


## 黑屏渐变 + 进入卧室 begin()。
func _fade_black_and_begin_bedroom() -> void:
	if _mask != null:
		_mask.enabled = true
		_tween_mask_to(Color(0, 0, 0, 1), 4000.0, 4500.0, 0.8)
	if _bedroom != null and _bedroom.has_method("begin"):
		(_bedroom as Node).begin()
	set_stage(STAGE_BEDROOM)


## 用 Tween 渐变遮罩颜色/半径（f7；DarknessMask._process 读导出属性，故 tween 属性可生效）。
func _tween_mask_to(col: Color, ri: float, ro: float, dur: float) -> void:
	if _mask == null:
		return
	var m := _mask
	var tw := create_tween()
	# 颜色/两个半径同步渐变（t32：LIGHT 展开需在 LIGHT_C_DUR 内整体过渡，避免顺序 tween 与计时错位）
	tw.set_parallel(true)
	tw.tween_property(m, "darkness_color", col, dur)
	tw.tween_property(m, "radius_inner", ri, dur)
	tw.tween_property(m, "radius_outer", ro, dur)


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


## 同步强制推进 LIGHT A→E（仅自检/校验用，跳过动画 Tween）：设终态 + 校验用状态。
func _force_light_to_e() -> void:
	_light_step = LIGHT_A
	_mask_config(LIGHT_A_INNER, LIGHT_A_OUTER, LIGHT_A_COLOR, false, LIGHT_STUDY_CENTER)
	_light_step = LIGHT_B
	_light_b_reset_done = true
	_reset_player_to_study()
	_mask_config(LIGHT_A_INNER, LIGHT_A_OUTER, LIGHT_A_COLOR, false, LIGHT_STUDY_CENTER)
	_light_step = LIGHT_C
	_hide_room_structures()
	_run_light_shake()
	_run_light_particles()
	_mask_config(LIGHT_EXPAND_INNER, LIGHT_EXPAND_OUTER, LIGHT_A_COLOR, true)
	_light_step = LIGHT_D
	_mask_config(LIGHT_DIM_INNER, LIGHT_DIM_OUTER, LIGHT_DIM_COLOR)
	_finish_light_e()


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
	checks.append("s1_study_locked" if (not GameState.get_process_flag(FLAG_STUDY_ITEMS_UNLOCKED) and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN) and current_stage == STAGE_STUDY) else "s1_study_locked_FAIL")
	on_player_left_study()
	checks.append("s2_leave_study" if (current_stage == STAGE_LEAVE_STUDY and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN)) else "s2_leave_study_FAIL")
	on_paper_collected("paper_living", 100)
	on_paper_collected("paper_kitchen", 100)
	checks.append("s4_unlock_study" if (GameState.get_process_flag(FLAG_STUDY_ITEMS_UNLOCKED) and GameState.get_process_flag(FLAG_STUDY_GATE_OPEN)) else "s4_unlock_study_FAIL")
	on_paper_collected("study_b", 99)
	checks.append("s5_study_b" if not GameState.get_process_flag(FLAG_LIGHT_PHASE_DONE) else "s5_study_b_FAIL")
	on_paper_collected("study_a", 100)
	checks.append("s6_light" if (GameState.get_process_flag(FLAG_LIGHT_PHASE_DONE) and current_stage == STAGE_LIGHT and _light_step == LIGHT_A) else "s6_light_FAIL")
	# t32：驱动 LIGHT A→E，校验 hold_breath_unlocked + 房间结构消散 + 震动 5s
	_force_light_to_e()
	checks.append("s6_breath" if GameState.get_process_flag(FLAG_HOLD_BREATH_UNLOCKED) else "s6_breath_FAIL")
	checks.append("s6_hide" if _light_structures_hidden() else "s6_hide_FAIL")
	var sd: float = float(_screen_shake.get("duration")) if _screen_shake != null else 0.0
	checks.append("s6_shake" if sd >= 4.9 else "s6_shake_FAIL(%.1f)" % sd)
	_reset_flags()
	on_bedroom_door_named()
	checks.append("s8_bedroom_named" if GameState.get_process_flag(FLAG_BEDROOM_DOOR_ACTIVE) else "s8_bedroom_named_FAIL")


## 物理运行断言（本轮验证升级：headless EXIT=0 不足以发现坠穿等致命缺陷）——
## 等物理帧稳定后读回：①玩家站立 y≈948 不坠穿 ②卧室 begin 后玩家 x≈4820 ③LIGHT-C 后 WallRight.visible=false ④StudyGateBlocker 初始 disabled。
func _physical_assertions() -> bool:
	# 等物理帧稳定（~1s，让玩家落到地面）
	await get_tree().create_timer(1.0).timeout
	var checks: Array[String] = []
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
	# ③卧室 begin → 玩家全局 x≈4820
	if _bedroom != null and _bedroom.has_method("begin"):
		(_bedroom as Node).begin()
		await get_tree().process_frame
		if _player != null:
			var bx: float = _player.global_position.x
			checks.append("bedroom_x" if (absf(bx - 4820.0) < 5.0) else "bedroom_x_FAIL(%.1f)" % bx)
	# ④LIGHT A→E → 房间结构消散 + 震动 5s + hold_breath_unlocked + 玩家齐位
	_force_light_to_e()
	await get_tree().process_frame
	checks.append("light_hide" if _light_structures_hidden() else "light_hide_FAIL")
	if _screen_shake != null:
		var sdu: float = float(_screen_shake.get("duration"))
		checks.append("light_shake5" if sdu >= 4.9 else "light_shake5_FAIL(%.1f)" % sdu)
	checks.append("light_breath" if GameState.get_process_flag(FLAG_HOLD_BREATH_UNLOCKED) else "light_breath_FAIL")
	# ⑤走廊地板：传送玩家到走廊中心（stop_center_x=4480），物理稳定后不坠穿（y≈948 站立）
	if _player != null:
		_player.global_position = Vector2(4480.0, 940.0)
		await get_tree().create_timer(0.6).timeout
		var cy: float = _player.global_position.y
		checks.append("corridor_stand" if (cy > 900.0 and cy < 1000.0) else "corridor_stand_FAIL(%.1f)" % cy)
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
	_setup_parallax()
	_bind_doors()
	_connect_scene_signals()
	_apply_phase_arg()


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


## 玩家进入门检测区：右门常开；左门按锁定(已出书房且 study_gate_open=false)禁开+强制关。
func _on_door_body_entered(body: Node2D, door: Node) -> void:
	if body == null or body is Player == false:
		return
	if body != _player:
		return
	if door == _door_study_living:
		# 左门锁定：不 open 且强制 close（blocker 物理兜底）
		if _left_study and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN):
			if door.has_method("close"):
				door.close()
			return
	if door.has_method("open"):
		door.open()


## 玩家离开门检测区：关闭门。
func _on_door_body_exited(body: Node2D, door: Node) -> void:
	if body == null or body != _player:
		return
	if door.has_method("close"):
		door.close()


## 使主相机当前(玩家 Camera2D)——OkPopup 世界→屏幕换算需相机变换。
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
		# t34 gap ①：帧取景偏移——角色站画幅地面（视口中心上移，玩家位于下三分一带）
		cam.offset = CAMERA_FRAME_OFFSET


## 景深目标重定向：让 DepthParallax 跟随游戏主 Player（白模内置 Player 已禁用）。
func _setup_parallax() -> void:
	if parallax_path == NodePath() or _player == null:
		return
	var plx := get_node_or_null(parallax_path)
	if plx != null and plx.has_method("set") and plx.get("target") != null:
		plx.set("target", _player)


## 配置 RoomTable 房间区间（§3.4：书房[0,1280]/客厅[1280,2560]/厨房[餐厅位,2560,3840]）。
func _setup_room_table() -> void:
	if room_table_path == NodePath():
		return
	var rt := get_node_or_null(room_table_path)
	if rt != null and rt.has_method("set_rooms"):
		rt.set_rooms({
			"room1": {"x_min": 0.0, "x_max": 1280.0},
			"room2": {"x_min": 1280.0, "x_max": 2560.0},
			"room3": {"x_min": 2560.0, "x_max": 3840.0}
		})


## 连接子系统信号（f5：门 E→进卧室 / end_confirmed→黑屏→begin / breath_disable→set_enabled(false) / white_screen→全屏白）。
func _connect_scene_signals() -> void:
	# E 键 → 范围内 item touched()（问题三：补 Player.interact_pressed 链路）
	if _player != null and _player.has_signal("interact_pressed"):
		_player.connect("interact_pressed", Callable(self, "_on_interact_pressed"))
	# ok 占位提示：连接每个 item 的 interaction_succeeded → OkPopup.show_ok
	for it in _find_items():
		if it.has_signal("interaction_succeeded"):
			it.connect("interaction_succeeded", Callable(self, "_on_item_succeeded").bind(it))
	if _bedroom != null:
		if _bedroom.has_signal("breath_disable_requested"):
			_bedroom.connect("breath_disable_requested", Callable(self, "on_breath_disable"))
		if _bedroom.has_signal("white_screen_end_requested"):
			_bedroom.connect("white_screen_end_requested", Callable(self, "on_white_screen_end"))
	if _corridor != null:
		if _corridor.has_signal("corridor_entered"):
			_corridor.connect("corridor_entered", Callable(self, "_on_corridor_entered"))
	if corridor_end_item_path != NodePath():
		var ce := get_node_or_null(corridor_end_item_path)
		if ce != null and ce.has_signal("end_confirmed"):
			ce.connect("end_confirmed", Callable(self, "on_corridor_end_confirmed"))


func _on_corridor_entered() -> void:
	GameState.set_process_flag(FLAG_CORRIDOR_ENTERED, true)


## item 确定交互成功 → ok 占位提示（黑字，短暂显示）。
func _on_item_succeeded(it: Node) -> void:
	if ok_popup_path != NodePath():
		var pop := get_node_or_null(ok_popup_path)
		if pop != null and pop.has_method("show_ok"):
			var pos: Vector2 = it.global_position if it is Node2D else Vector2.ZERO
			pop.show_ok(pos)


## E 键按下 → 对范围内（get_overlapping_bodies 含 Player）的 item 调 touched()。
func _on_interact_pressed() -> void:
	if _player == null:
		return
	var items := _find_items()
	for it in items:
		if it is Area2D:
			var area := it as Area2D
			if area.has_method("touched") and area.get_overlapping_bodies().has(_player):
				area.touched()


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


func _resolve_scene_refs() -> void:
	if player_path != NodePath():
		var n := get_node_or_null(player_path)
		if n is Node2D:
			_player = n as Node2D
	if corridor_path != NodePath():
		_corridor = get_node_or_null(corridor_path)
	if bedroom_path != NodePath():
		_bedroom = get_node_or_null(bedroom_path)
	if breath_path != NodePath():
		_breath = get_node_or_null(breath_path)
	if darkness_mask_path != NodePath():
		_mask = get_node_or_null(darkness_mask_path)
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
				_phase_debug_loaded = true


func _process(delta: float) -> void:
	if _phase_debug_loaded:
		return
	if _player == null:
		return
	if current_stage == STAGE_STUDY:
		if _player.global_position.x >= study_right_x:
			on_player_left_study()
	elif current_stage == STAGE_LIGHT:
		_process_light(delta)


## LIGHT 分步驱动：A→B 依玩家出门；B→C 依二次靠门；C→D→E 依计时。
func _process_light(delta: float) -> void:
	match _light_step:
		LIGHT_A:
			if _player.global_position.x >= study_right_x:
				_enter_light_b()
		LIGHT_B:
			if _light_b_reset_done and _player.global_position.x >= study_right_x:
				_enter_light_c()
		LIGHT_C:
			_light_c_t += delta
			if _light_c_t >= LIGHT_C_DUR:
				_enter_light_d()
		LIGHT_D:
			_light_d_t += delta
			if _light_d_t >= LIGHT_D_DUR:
				_finish_light_e()
		_:
			pass
