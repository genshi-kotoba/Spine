extends Node
## GameState — Autoload 单例
## 职责：以字典存储所有可交互对象的全局状态，并提供 JSON 存档读写。

signal state_changed(object_id: String, new_state: String)

const SAVE_PATH := "user://savegame.json"

## key = 对象唯一 ID，value = 该对象状态机当前状态
var object_states: Dictionary = {}

## 独立过程旗标字典（C3 前置需求②）：key = 进程旗标名，value = bool。
## 与 object_states 是两个相互独立的字典，互不读写；为 GameState 既有 JSON 存档的并列键。
## 供 Item 读取做交互门控（gate_flag），也可用于光影/特效联动。不新增 autoload。
var process_flags: Dictionary = {}


func _ready() -> void:
	load_game()


## 退出时自动存档（godot_c2_c4_prompt 存档验证：中途保存退出重进可恢复）
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func set_object_state(object_id: String, new_state: String) -> void:
	object_states[object_id] = new_state
	state_changed.emit(object_id, new_state)


func get_object_state(object_id: String) -> String:
	return object_states.get(object_id, "")


## 设置指定进程旗标（缺省 false）。随后可随 save_game 持久化。
func set_process_flag(name: String, value: bool) -> void:
	process_flags[name] = value


## 读取指定进程旗标；未设置时缺省 false。
func get_process_flag(name: String) -> bool:
	return process_flags.get(name, false)


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameState: 无法写入存档 %s" % SAVE_PATH)
		return
	# 追加 process_flags 为并列键（与 object_states 独立；向后兼容旧存档无该键）
	file.store_string(JSON.stringify({"object_states": object_states, "process_flags": process_flags}))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		object_states = {}
		process_flags = {}
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameState: 无法读取存档 %s" % SAVE_PATH)
		object_states = {}
		process_flags = {}
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		object_states = {}
		process_flags = {}
		return
	# 新格式：{object_states:{...}, process_flags:{...}}；旧格式：顶层即 object_states 平铺字典（无 object_states 键）
	if data.has("object_states"):
		object_states = data["object_states"] if data["object_states"] is Dictionary else {}
		process_flags = data.get("process_flags", {}) if data.get("process_flags", {}) is Dictionary else {}
	else:
		# 旧存档：顶层字典即 object_states，process_flags 缺省为空（向后兼容）
		object_states = data
		process_flags = {}
