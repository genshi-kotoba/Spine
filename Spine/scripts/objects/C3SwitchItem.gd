class_name C3SwitchItem
extends "res://scripts/objects/item.gd"
## C3SwitchItem — C3 前置需求② 演示子类
## 演示 item 扩展 API：gate_flag 门控、set_interaction_enabled、force_trigger、states 表驱动 apply_state。
## 状态 0/1 通过 states 表切换颜色与位置。touched() 经基类 gate 检查后进入 _try_touch()。
## --self-check：headless 自检 gate 阻止/放行、交互开关、call_item 无视 gate、states 表应用。

## 音效/额外逻辑无需；纯演示。
@export var self_check: bool = false

var _state_color_1: Color = Color(1.0, 0.5, 0.5, 1)
var _state_color_0: Color = Color(0.2, 0.5, 0.9, 1)
var _gate_blocked_emitted: bool = false


func _ready() -> void:
	# 构造 states 表（键 int）：状态 0 / 1 用颜色与位置区分
	states = {
		0: {"color": _state_color_0, "size": size},
		1: {"color": _state_color_1, "size": size * Vector2(1.2, 1.2)}
	}
	super._ready()
	_run_self_check()


## 实际触发（gate/interaction 检查已由基类 touched 完成）：toggle 0↔1
func _try_touch() -> bool:
	var new_state: int = 1 if current_state == 0 else 0
	set_state(new_state)
	return true


## headless 自检：--self-check 时执行；验证 gate 阻止/放行、交互开关、call_item、states 表。
func _run_self_check() -> void:
	if not "--self-check" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	var gate: String = gate_flag
	var checks: Array[String] = []

	# 1) gate 未满足（process_flag=false）→ touched() 不改变状态，发射 gate_blocked
	await _test_gate_blocked(gate, checks)
	# 2) gate 满足（process_flag=true）→ touched() 放行
	current_state = 0
	await _test_gate_passed(gate, checks)
	# 3) set_interaction_enabled(false) 阻止；恢复允许
	await _test_interaction_switch(checks)
	# 4) call_item 无视 gate（force-trigger 路径）→ 直接到目标状态
	current_state = 0
	GameState.set_process_flag(gate, false)
	call_item(1)
	await get_tree().process_frame
	checks.append("call_item2" if current_state == 1 else "call_item_FAIL2")
	# 5) states 表驱动 apply_state：状态 1 应应用颜色
	var visual := get_node_or_null("Visual")
	checks.append("states_table1" if visual is Polygon2D and (visual as Polygon2D).color == _state_color_1 else "states_table_FAIL1")

	var failed := false
	for c in checks:
		if c.ends_with("FAIL") or c.contains("FAIL"):
			failed = true
		print("[c3_switch_item] CHECK " + c)
	print("[c3_switch_item] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	get_tree().quit()


func _test_gate_blocked(gate: String, checks: Array[String]) -> void:
	GameState.set_process_flag(gate, false)
	_gate_blocked_emitted = false
	gate_blocked.connect(_on_gate_blocked, CONNECT_ONE_SHOT)
	var before: int = current_state
	touched()
	await get_tree().process_frame
	checks.append("gate_blocked1" if (_gate_blocked_emitted and current_state == before) else "gate_blocked_FAIL1")


func _on_gate_blocked() -> void:
	_gate_blocked_emitted = true


func _test_gate_passed(gate: String, checks: Array[String]) -> void:
	GameState.set_process_flag(gate, true)
	var before: int = current_state
	touched()
	await get_tree().process_frame
	checks.append("gate_passed1" if current_state != before else "gate_passed_FAIL1")


func _test_interaction_switch(checks: Array[String]) -> void:
	set_interaction_enabled(false)
	var before: int = current_state
	touched()
	await get_tree().process_frame
	var blocked: bool = (current_state == before)
	set_interaction_enabled(true)
	touched()
	await get_tree().process_frame
	var allowed: bool = (current_state != before)
	checks.append("interact_switch1" if (blocked and allowed) else "interact_switch_FAIL1")
