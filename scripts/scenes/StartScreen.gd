class_name StartScreen
extends MainScene
## StartScreen — 场景一（2026-09-06 重构版）：纯黑过场
## 原「标题 + 开始按钮 + 初始化存档」已全部移除（见 docs/start_screen_constraints.md）。
## 启动后等待 AUTO_ADVANCE_DELAY 秒，自动切换到 computer_screen，无需任何输入。

## 自动切场景前的等待时长（秒）
const AUTO_ADVANCE_DELAY: float = 2.0
const NEXT_SCENE := "res://scenes/computer_screen.tscn"


func _ready() -> void:
	super._ready()
	_auto_advance()


func _auto_advance() -> void:
	await get_tree().create_timer(AUTO_ADVANCE_DELAY).timeout
	get_tree().change_scene_to_file(NEXT_SCENE)
