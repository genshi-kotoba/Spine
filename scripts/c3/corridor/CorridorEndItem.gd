class_name CorridorEndItem
extends "res://scripts/objects/item.gd"
## CorridorEndItem — C3 走廊尽头 item（spec ⑥ §9）
## 两段式交互：第 1 次 E → set_state(1)（占位：变灰/变色/位移），第 2 次 E → set_state(2) 并发射 end_confirmed，
## 请求黑屏过渡进卧室（黑屏/搬运由 C3Flow/场景处理，本组件仅发信号）。
## 复用前置 Item 基类：gate_flag（建议=corridor_end）控制仅在走廊有限化后可交互；
## 覆写 _try_touch()（不覆写 touched()）以保留基类 gate/门控链路。
## 白模：states 表颜色占位（零贴图）。

## 第 2 次 E 确认（黑屏→卧室）——供 C3Flow/场景接线。
signal end_confirmed(state: int)

## 两段式交互上限（spec「按 E 状态更新 → 再按 E 黑屏」）。
@export var interactions_max: int = 2

## 自我校验用：end_confirmed 发射计数。
var _end_confirmed_count: int = 0


func _ready() -> void:
	states = {
		0: {"color": Color(0.70, 0.70, 0.70, 1)},
		1: {"color": Color(0.55, 0.55, 0.60, 1)},
		2: {"color": Color(0.30, 0.30, 0.35, 1)},
	}
	super._ready()
	if "--component-self-check" in OS.get_cmdline_user_args():
		_run_self_check()


## 实际触发（gate/交互开关已由基类 touched 检查）：推进到下一状态；达上限发射 end_confirmed。
func _try_touch() -> bool:
	if current_state >= interactions_max:
		return false
	set_state(current_state + 1)
	if current_state >= interactions_max:
		end_confirmed.emit(current_state)
		_end_confirmed_count += 1
	return true


## 是否已确认（黑屏）——供 C3Flow/场景读取。
func is_confirmed() -> bool:
	return current_state >= interactions_max


func _run_self_check() -> void:
	if not "--component-self-check" in OS.get_cmdline_user_args():
		return
	var checks: Array[String] = []
	# 两段式：E1 → state1；E2 → state2 + end_confirmed；再 E → 封顶不推进。
	_try_touch()
	checks.append("stage1" if current_state == 1 else "stage_FAIL1")
	_try_touch()
	checks.append("stage2" if (current_state == 2 and _end_confirmed_count == 1 and is_confirmed()) else "stage2_FAIL1")
	_try_touch()
	checks.append("capped1" if current_state == 2 and _end_confirmed_count == 1 else "capped_FAIL1")
	var failed := false
	for c in checks:
		if c.contains("FAIL"):
			failed = true
		print("[corridor_end_item] CHECK " + c)
	print("[corridor_end_item] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	get_tree().quit()
