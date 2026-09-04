class_name C3Flow
extends Node
## C3Flow — C3 关卡流程门控（阶段状态机 + 进程旗标 + item 门控接入）
## 对应 docs/c3_gameplay_constraints.md §3.1/§3.2/§6.2/§7.3/§10.4 的流程与门控逻辑层。
## 本品为脚本层：定义 9 阶段状态机 + 12 进程旗标 + 供场景/ item 调用的门控钩子；
## 场景组装（c3_level.tscn）由 t6e 负责接线。无房间/关卡字面量于判定内、纯逻辑、headless 解析无错。

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

## 已收集的书房试卷（第三/第四，顺序无关）数量。
var _study_papers_collected: int = 0

signal stage_changed(new_stage: int)


func _ready() -> void:
	add_to_group("c3flow")
	_reset_flags()
	if "--self-check" in OS.get_cmdline_user_args():
		run_self_check()
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


## 直接设置阶段（供调试/自检/房间切换）。
func set_stage(s: int) -> void:
	current_stage = s
	stage_changed.emit(s)


# ─── 事件钩子（场景/t6e 接线调用）───

## 玩家离开书房 → 锁书房-客厅门（无法回）+ 进入 LEAVE_STUDY（§6.2）。
func on_player_left_study() -> void:
	GameState.set_process_flag(FLAG_STUDY_GATE_OPEN, false)
	if current_stage == STAGE_STUDY:
		set_stage(STAGE_LEAVE_STUDY)


## 试卷得分回调（由 C3PaperItem 调用；paper_id: 试卷标识，score: 100/99）。
func on_paper_collected(paper_id: String, score: int) -> void:
	if paper_id == "paper_living":
		GameState.set_process_flag(FLAG_PAPER_LIVING, true)
	elif paper_id == "paper_kitchen":
		GameState.set_process_flag(FLAG_PAPER_KITCHEN, true)
	elif paper_id == "study_a" or paper_id == "study_b":
		# 第三/第四（顺序无关）：累计，二者都触发→光影
		_collect_study_paper()
	_refresh_study_state()


func _collect_study_paper() -> void:
	_study_papers_collected += 1


## 刷新书房相关状态与阶段推进（§6.2）。
func _refresh_study_state() -> void:
	var living_ok := GameState.get_process_flag(FLAG_PAPER_LIVING)
	var kitchen_ok := GameState.get_process_flag(FLAG_PAPER_KITCHEN)
	# 两张 100 分试卷后：书房门禁解除 + 书房 item 解禁
	if living_ok and kitchen_ok:
		GameState.set_process_flag(FLAG_STUDY_GATE_OPEN, true)
		GameState.set_process_flag(FLAG_STUDY_ITEMS_UNLOCKED, true)
		if current_stage < STAGE_RETURN_STUDY:
			set_stage(STAGE_RETURN_STUDY)
	# 第三/第四（顺序无关）都触发 → 光影进入 ④
	if _study_papers_collected >= 2 and not GameState.get_process_flag(FLAG_LIGHT_PHASE_DONE):
		GameState.set_process_flag(FLAG_LIGHT_PHASE_DONE, true)
		set_stage(STAGE_LIGHT)


# ─── 卧室门三态（§5.2）───

## 流程点名后卧室门可交互（bedroom_door_active=true）。
func on_bedroom_door_named() -> void:
	GameState.set_process_flag(FLAG_BEDROOM_DOOR_ACTIVE, true)


## 进入卧室白模。
func on_bedroom_entered() -> void:
	set_stage(STAGE_BEDROOM)


# ─── 阶段旗标应用（供调试入口 --phase / 流程切换）───

## 按目标阶段写入对应旗标（调试/自检用）。
func debug_set_stage(s: int) -> void:
	set_stage(s)
	_apply_stage_flags(s)


func _apply_stage_flags(s: int) -> void:
	if s >= STAGE_LIGHT:
		GameState.set_process_flag(FLAG_HOLD_BREATH_UNLOCKED, true)
		GameState.set_process_flag(FLAG_LIGHT_PHASE_DONE, true)
	if s >= STAGE_CORRIDOR:
		GameState.set_process_flag(FLAG_CORRIDOR_ENTERED, true)
	if s == STAGE_CORRIDOR_END:
		GameState.set_process_flag(FLAG_CORRIDOR_END, true)
	if s >= STAGE_BEDROOM:
		GameState.set_process_flag(FLAG_BEDROOM_UNLOCKED, true)
		GameState.set_process_flag(FLAG_BEDROOM_INTERACTIONS_DONE, true)


# ─── 自检（--self-check；验证试卷流程/门禁/卧室门三态）───

## headless 自检：模拟 ③ 试卷流程与卧室门状态，读回旗标/阶段一致。
## 返回 true=全 PASS。供 t7（验证）直接调用。
func run_self_check() -> bool:
	var checks: Array[String] = []
	_reset_flags()

	# 初生：书房 item 未解禁、门禁未开、卧室门未点名
	checks.append("s1_study_locked" if (not GameState.get_process_flag(FLAG_STUDY_ITEMS_UNLOCKED) and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN) and current_stage == STAGE_STUDY) else "s1_study_locked_FAIL")

	# 出书房 → 门禁锁定 + LEAVE_STUDY
	on_player_left_study()
	checks.append("s2_leave_study" if (current_stage == STAGE_LEAVE_STUDY and not GameState.get_process_flag(FLAG_STUDY_GATE_OPEN)) else "s2_leave_study_FAIL")

	# 客厅 100 → 厨房 100 → 解锁书房 + RETURN_STUDY
	on_paper_collected("paper_living", 100)
	checks.append("s3_living" if GameState.get_process_flag(FLAG_PAPER_LIVING) else "s3_living_FAIL")
	on_paper_collected("paper_kitchen", 100)
	checks.append("s4_unlock_study" if (GameState.get_process_flag(FLAG_STUDY_ITEMS_UNLOCKED) and GameState.get_process_flag(FLAG_STUDY_GATE_OPEN) and current_stage == STAGE_RETURN_STUDY) else "s4_unlock_study_FAIL")

	# 书房第三/第四（顺序无关）：先后收集，二者都触发→光影
	on_paper_collected("study_b", 99)
	checks.append("s5_study_b" if not GameState.get_process_flag(FLAG_LIGHT_PHASE_DONE) else "s5_study_b_FAIL")
	on_paper_collected("study_a", 100)
	checks.append("s6_light" if (GameState.get_process_flag(FLAG_LIGHT_PHASE_DONE) and current_stage == STAGE_LIGHT) else "s6_light_FAIL")

	# 卧室门三态：默认无反应（未点名）→ 点名后可进
	_reset_flags()
	checks.append("s7_bedroom_default" if not GameState.get_process_flag(FLAG_BEDROOM_DOOR_ACTIVE) else "s7_bedroom_default_FAIL")
	on_bedroom_door_named()
	checks.append("s8_bedroom_named" if GameState.get_process_flag(FLAG_BEDROOM_DOOR_ACTIVE) else "s8_bedroom_named_FAIL")
	on_bedroom_entered()
	checks.append("s9_bedroom_stage" if current_stage == STAGE_BEDROOM else "s9_bedroom_stage_FAIL")

	var failed := false
	for c in checks:
		if c.ends_with("FAIL") or c.contains("FAIL"):
			failed = true
		print("[c3_flow] CHECK " + c)
	print("[c3_flow] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	return not failed
