extends Node
## DialogueManager — Autoload 单例
## 职责：对话的统一入口与队列调度。
## 同一时刻只允许一段对话；进行中收到新请求 → FIFO 排队，当前结束后自动开始下一段。

signal dialogue_started
signal dialogue_finished

## 对话模式
enum {
	MODE_INTERACTIVE = 0,  ## 按键切换（锁定输入）
	MODE_AUTO = 1,         ## 自动切换（不锁定输入）
	MODE_GLITCH = 2,       ## 故障散落字幕（生命周期同 MODE_AUTO，仅显示方式不同）
}

const BOX_SCENE := preload("res://ui/dialogue_box.tscn")
const GLITCH_BOX_SCENE := preload("res://ui/glitch_dialogue_box.tscn")

var _box: DialogueBox = null
var _glitch_box = null  ## GlitchDialogueBox（路径实例化，避免依赖全局类缓存）
var _active: bool = false
var _queue: Array[Dictionary] = []


func _ready() -> void:
	_box = BOX_SCENE.instantiate()
	_box.dialogue_finished.connect(_on_box_finished)
	add_child(_box)
	_glitch_box = GLITCH_BOX_SCENE.instantiate()
	_glitch_box.dialogue_finished.connect(_on_box_finished)
	add_child(_glitch_box)
	print("[dialogue_manager] glitch box ready")


func is_dialogue_active() -> bool:
	return _active


## 请求开始一段对话；进行中则进入队列等待
func start_dialogue(file_path: String, mode: int) -> void:
	if _active:
		_queue.append({"file_path": file_path, "mode": mode})
		return
	_begin(file_path, mode)


## 直接播放运行时提供的句子；适合交互反馈等不需要独立文件的短字幕。
func start_lines(lines: Array, mode: int = MODE_INTERACTIVE) -> void:
	var clean_lines: Array = []
	for line in lines:
		var clean := str(line).strip_edges()
		if not clean.is_empty():
			clean_lines.append(clean)
	if clean_lines.is_empty():
		return
	if _active:
		_queue.append({"lines": clean_lines, "mode": mode})
		return
	_begin_lines(clean_lines, mode)


func _begin(file_path: String, mode: int) -> void:
	_begin_lines(_load_lines(file_path), mode)


func _begin_lines(lines: Array, mode: int) -> void:
	_active = true
	dialogue_started.emit()
	print("[dialogue_manager] begin mode=%d lines=%d" % [mode, lines.size()])
	if mode == MODE_GLITCH:
		_glitch_box.show_dialogue(lines)
	else:
		_box.show_dialogue(lines, mode)


## 按行读取文本文件：换行分句，忽略空行
func _load_lines(file_path: String) -> Array:
	var lines: Array = []
	if not FileAccess.file_exists(file_path):
		push_error("DialogueManager: 对话文件不存在 %s" % file_path)
		return lines
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("DialogueManager: 无法读取对话文件 %s" % file_path)
		return lines
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line != "":
			lines.append(line)
	return lines


func _on_box_finished() -> void:
	_active = false
	dialogue_finished.emit()
	if not _queue.is_empty():
		var next: Dictionary = _queue.pop_front()
		if next.has("lines"):
			_begin_lines(next["lines"], next["mode"])
		else:
			_begin(next["file_path"], next["mode"])
