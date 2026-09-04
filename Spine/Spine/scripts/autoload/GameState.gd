extends Node
## GameState — Autoload 单例
## 职责：以字典存储所有可交互对象的全局状态，并提供 JSON 存档读写。

signal state_changed(object_id: String, new_state: String)

const SAVE_PATH := "user://savegame.json"

## key = 对象唯一 ID，value = 该对象状态机当前状态
var object_states: Dictionary = {}


func _ready() -> void:
	load_game()


func set_object_state(object_id: String, new_state: String) -> void:
	object_states[object_id] = new_state
	state_changed.emit(object_id, new_state)


func get_object_state(object_id: String) -> String:
	return object_states.get(object_id, "")


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: 无法写入存档 %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(object_states))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		object_states = {}
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: 无法读取存档 %s" % SAVE_PATH)
		object_states = {}
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	object_states = data if data is Dictionary else {}
