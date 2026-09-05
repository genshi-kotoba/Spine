class_name FxDemo
extends Node2D
## FxDemo — 特效库演示驱动（C3 前置需求④）
## 触发底色粒子 burst / 全屏 ScreenShake / 局部 ItemShake，演示三组件可参数化调用复用。
## --self-check：headless 调用三组件方法并读回参数有效性。

@onready var _burst: ParticleBurst = $ParticleBurst
@onready var _screen_shake: ScreenShake = $Player/Camera2D/ScreenShake
@onready var _item_shake: ItemShake = $ShakeTarget/ItemShake


func _ready() -> void:
	$Player/Camera2D.make_current()
	_run_self_check()


func _run_self_check() -> void:
	if not "--self-check" in OS.get_cmdline_user_args():
		return
	await get_tree().process_frame
	var checks: Array[String] = []

	# ParticleBurst：设置颜色并 burst
	_burst.set_color(Color(1, 0.6, 0.2, 1))
	_burst.burst()
	checks.append("particleburst1" if _burst.color == Color(1, 0.6, 0.2, 1) else "particleburst_FAIL1")

	# ScreenShake：触发 shake
	_screen_shake.shake(12.0, 0.3)
	checks.append("screenshake1" if _screen_shake._shaking or _screen_shake._amp > 0.0 else "screenshake_FAIL1")

	# ItemShake：触发 shake
	_item_shake.shake(8.0, 0.25)
	checks.append("itemshake1" if _item_shake._shaking or _item_shake._amp > 0.0 else "itemshake_FAIL1")

	var failed := false
	for c in checks:
		if c.ends_with("FAIL") or c.contains("FAIL"):
			failed = true
		print("[fx_demo] CHECK " + c)
	print("[fx_demo] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	get_tree().quit()
