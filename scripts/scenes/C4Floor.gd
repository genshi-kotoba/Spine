class_name C4Floor
extends FloorTemplate
## C4Floor — c4_floor 场景脚本（docs/c4_waste_constraints.md §4.2）
## 职责：监听 GameState.state_changed，统计已消失 waste 数量；
## 每满 4 个（第 4 / 8 / 12 个）经 DialogueManager 唤起一段 MODE_INTERACTIVE 剧情对话。
## 已播标记写 process_flags（随存档持久化）；读档恢复时已达阈值静默补位，不重播。

## 12 个 waste 的 GameState 状态键（与场景节点 state_id 一一对应）
const WASTE_IDS: Array[String] = [
	"c4_waste1", "c4_waste2", "c4_waste3", "c4_waste4",
	"c4_waste5", "c4_waste6", "c4_waste7", "c4_waste8",
	"c4_waste9", "c4_waste10", "c4_waste11", "c4_waste12",
]

## 对话触发阈值：消失数量达到即播
const THRESHOLDS: Array[int] = [4, 8, 12]

## 阈值 → 对话文本路径
const DIALOGUE_PATHS: Dictionary = {
	4: "res://dialogues/c4_dialogue1.txt",
	8: "res://dialogues/c4_dialogue2.txt",
	12: "res://dialogues/c4_dialogue3.txt",
}

## process_flags 已播标记键前缀（键 = FLAG_PREFIX + str(阈值)）
const FLAG_PREFIX: String = "c4_dialogue_shown_"


func _ready() -> void:
	super._ready()
	GameState.state_changed.connect(_on_state_changed)
	_restore_dialogue_flags()


## GameState 状态变更监听：waste 消失（状态 "1"）时计数并按阈值触发对话
func _on_state_changed(object_id: String, new_state: String) -> void:
	if new_state != "1":
		return
	if not WASTE_IDS.has(object_id):
		return
	var n: int = _waste_count()
	# 取当前满足的最小未播阈值；一次状态变更至多触发一段
	for t: int in THRESHOLDS:
		if n >= t and not GameState.get_process_flag(FLAG_PREFIX + str(t)):
			GameState.set_process_flag(FLAG_PREFIX + str(t), true)
			print("[c4_floor] waste count=%d, start dialogue %d" % [n, t])
			DialogueManager.start_dialogue(DIALOGUE_PATHS[t], DialogueManager.MODE_INTERACTIVE)
			break


## 已消失 waste 计数（GameState 状态为 "1" 的个数）
func _waste_count() -> int:
	var n: int = 0
	for id: String in WASTE_IDS:
		if GameState.get_object_state(id) == "1":
			n += 1
	return n


## 读档恢复：按存档中已消失数量把已达到的阈值 flag 静默置位，不重播已看过的对话
func _restore_dialogue_flags() -> void:
	var n: int = _waste_count()
	if n <= 0:
		return
	for t: int in THRESHOLDS:
		if n >= t:
			GameState.set_process_flag(FLAG_PREFIX + str(t), true)
	print("[c4_floor] restored %d wastes, flags synced" % n)
