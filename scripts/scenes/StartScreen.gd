class_name StartScreen
extends MainScene
## StartScreen — 场景一（2026-09-06 重构版）：纯黑过场
## 原「标题 + 开始按钮 + 初始化存档」已全部移除（见 docs/start_screen_constraints.md）。
## 启动后等待 AUTO_ADVANCE_DELAY 秒，自动切换到 computer_screen，无需任何输入。
## 切换时带 FADE_IN_DURATION 秒渐亮过场（v1.1）。

## 自动切场景前的等待时长（秒）
const AUTO_ADVANCE_DELAY: float = 2.0
## 渐亮过场时长（秒）
const FADE_IN_DURATION: float = 0.5
const NEXT_SCENE := "res://scenes/computer_screen.tscn"


func _ready() -> void:
	super._ready()
	_auto_advance()


func _auto_advance() -> void:
	await get_tree().create_timer(AUTO_ADVANCE_DELAY).timeout
	# 渐亮过场：黑罩挂在 SceneTree root 上（不随场景销毁），切场景后淡出。
	var layer := CanvasLayer.new()
	layer.layer = 128
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)
	get_tree().root.add_child(layer)
	var change_error: Error = get_tree().change_scene_to_file(NEXT_SCENE)
	if change_error != OK:
		push_error("StartScreen: unable to open %s (error %d)" % [NEXT_SCENE, change_error])
		layer.queue_free()
		return
	var tween := layer.create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, FADE_IN_DURATION)
	tween.tween_callback(layer.queue_free)
