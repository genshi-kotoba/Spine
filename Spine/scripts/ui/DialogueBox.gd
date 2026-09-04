class_name DialogueBox
extends CanvasLayer
## DialogueBox — 对话剧情文本框
## 画面下半部分弹出；点击画面任意位置切换到下一句；
## 全部播完后关闭文本框并解除输入锁定。

## 播完一段对话时发出
signal dialogue_finished

@onready var _panel: Panel = $Panel
@onready var _label: RichTextLabel = $Panel/RichTextLabel

var _lines: Array = []
var _index: int = 0
var _active: bool = false


func _ready() -> void:
	_panel.hide()


## 开始一段对话：锁定输入并逐句显示
func show_dialogue(lines: Array) -> void:
	_lines = lines
	_index = 0
	_active = true
	StoryMonitor.lock_input()
	_panel.show()
	_show_current_line()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		next_line()
		get_viewport().set_input_as_handled()


## 切换到下一句；播完关闭并解锁
func next_line() -> void:
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_current_line()


func _show_current_line() -> void:
	_label.text = str(_lines[_index])


func _close() -> void:
	_active = false
	_panel.hide()
	StoryMonitor.unlock_input()
	dialogue_finished.emit()
