class_name C2Bedroom
extends Bedroom
## C2Bedroom — c2 卧室（godot_c2_c4_prompt §4）：中央 ladder_window，无 test_item。
## ladder_window 交互成功 → 锁输入 → 5 秒渐白 → 纯白 3 秒 → 切换 computer_screen。


const NEXT_SCENE := "res://scenes/computer_screen.tscn"
const FADE_SEC := 5.0
const HOLD_SEC := 3.0

@onready var _ladder: LadderWindow = $LadderWindow
@onready var _fade: ColorRect = $WhiteFade/FadeRect

var _transitioning: bool = false


func _ready() -> void:
	super._ready()
	print("[c2_bedroom] ready")
	_ladder.interaction_succeeded.connect(_on_ladder_interacted)


## 白屏转场（_transitioning + 输入锁双重防二次触发）
func _on_ladder_interacted() -> void:
	if _transitioning:
		return
	_transitioning = true
	StoryMonitor.lock_input()
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_SEC)
	tween.tween_interval(HOLD_SEC)
	tween.tween_callback(_go_next)


func _go_next() -> void:
	StoryMonitor.unlock_input()
	get_tree().change_scene_to_file(NEXT_SCENE)
