class_name DialogueBox
extends CanvasLayer
## DialogueBox — 剧情对话 UI
## 文本左右居中、距画面下边缘 100px（锚点布局，分辨率变化保持相对位置）。
## 交互模式：任意键切句 + 1s 冷却 + 锁定输入；自动模式：每句 4s 自动切换，不锁输入。

## 播完一段对话时发出（DialogueManager 监听以驱动队列）
signal dialogue_finished

const MODE_INTERACTIVE := 0
const MODE_AUTO := 1
const COOLDOWN_SEC := 1.0
const AUTO_LINE_SEC := 4.0

@onready var _label: RichTextLabel = $DialogueLabel
@onready var _backdrop: ColorRect = $DialogueBackdrop
@onready var _auto_timer: Timer = $AutoTimer

var _lines: Array = []
var _index: int = 0
var _active: bool = false
var _mode: int = MODE_INTERACTIVE
var _cooldown_until_msec: int = 0


func _ready() -> void:
	_label.hide()
	_backdrop.hide()
	_auto_timer.wait_time = AUTO_LINE_SEC
	_auto_timer.one_shot = true
	_auto_timer.timeout.connect(_on_auto_timeout)


## 开始一段对话
func show_dialogue(lines: Array, mode: int = MODE_INTERACTIVE) -> void:
	_lines = lines
	_index = 0
	_mode = mode
	_active = true
	if _mode == MODE_INTERACTIVE:
		StoryMonitor.lock_input()
	# 首句显示即启动冷却：防止触发对话的同一按键立刻切走首句
	_cooldown_until_msec = Time.get_ticks_msec() + int(COOLDOWN_SEC * 1000)
	_label.show()
	_backdrop.show()
	_show_current()


func is_active() -> bool:
	return _active


## 切换到下一句；播完结束
func next_line() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_show_current()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _mode != MODE_INTERACTIVE:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# 全程拦截按键，防止穿透到游戏场景
		get_viewport().set_input_as_handled()
		if Time.get_ticks_msec() < _cooldown_until_msec:
			return  # 冷却期内的按键被忽略
		_cooldown_until_msec = Time.get_ticks_msec() + int(COOLDOWN_SEC * 1000)
		next_line()


func _show_current() -> void:
	_label.text = str(_lines[_index])
	if _mode == MODE_AUTO:
		_auto_timer.start()


func _on_auto_timeout() -> void:
	if _active and _mode == MODE_AUTO:
		next_line()


func _finish() -> void:
	_active = false
	_auto_timer.stop()
	_label.hide()
	_backdrop.hide()
	if _mode == MODE_INTERACTIVE:
		StoryMonitor.unlock_input()
	dialogue_finished.emit()
