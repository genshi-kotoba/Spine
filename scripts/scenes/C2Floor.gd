class_name C2Floor
extends FloorTemplate
## C2Floor — c2 关卡：ladder 四态状态机驱动的线性流程 + 白屏转场结局
## （docs/c2_refactor_constraints.md §4.2；取代旧三区域解锁设计）
## 连锁统一由本脚本监听 GameState.state_changed 驱动，item 脚本内不做互相引用。
## 任一 lego 消失 → ① Ladder.advance_state() ② LadderSfx（缺失优雅降级）③ 按已消失
## 总数唤起 c2_dialogue{n}（MODE_INTERACTIVE）。
## 结局：c2_dialogue3 播完且 ladder=="3" → 锁输入 → curten 消失 → 开窗音效 →
## 4s 渐白 → 纯白 3s → 进入 computer_screen（防重入，整局一次）。


## 三个 lego 的 GameState 状态键
const LEGO_IDS: Array[String] = ["c2_lego1", "c2_lego2", "c2_lego3"]

## 第 n 次 lego 交互 → 对话文件（与具体哪个 lego 解耦）
const DIALOGUE_PATHS: Dictionary = {
	1: "res://dialogues/c2_dialogue1.txt",
	2: "res://dialogues/c2_dialogue2.txt",
	3: "res://dialogues/c2_dialogue3.txt",
}

## curten 的 GameState 状态键（结局消失后读档一致）
const ID_CURTEN: String = "c2_curten"

## 结局已播 process_flag（防重入 + 读档一致）
const FLAG_ENDING: String = "c2_ending_done"

## 结局目标场景
const ENDING_SCENE: String = "res://scenes/computer_screen.tscn"

## ladder 音效路径（文件暂缺：禁止 preload，运行时存在性检查后加载，缺失仅 warning）
@export var ladder_sfx_path: String = "res://assets/audio/ladder.mp3"

@onready var _ladder: Ladder = $Items/Ladder
@onready var _curten: Node2D = $Items/Curten
@onready var _ladder_sfx: AudioStreamPlayer = $LadderSfx
@onready var _window_sfx: AudioStreamPlayer = $WindowSfx
@onready var _fade_rect: ColorRect = $EndingLayer/FadeRect


func _ready() -> void:
	super._ready()
	GameState.state_changed.connect(_on_state_changed)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)
	_restore_progress()


## lego 消失（状态 "1"）→ ladder 推进 + 音效 + 按总数唤起对话
func _on_state_changed(object_id: String, new_state: String) -> void:
	if new_state != "1":
		return
	if not LEGO_IDS.has(object_id):
		return
	_ladder.advance_state()
	_play_ladder_sfx()
	var n: int = _lego_count()
	if DIALOGUE_PATHS.has(n):
		print("[c2_floor] lego count=%d, start dialogue %d" % [n, n])
		DialogueManager.start_dialogue(DIALOGUE_PATHS[n], DialogueManager.MODE_INTERACTIVE)


## 已消失 lego 计数（读档恢复后计数仍正确）
func _lego_count() -> int:
	var n: int = 0
	for id: String in LEGO_IDS:
		if GameState.get_object_state(id) == "1":
			n += 1
	return n


## ladder 音效：文件缺失时优雅降级（push_warning 跳过，不允许报错中断流程）
func _play_ladder_sfx() -> void:
	if not ResourceLoader.exists(ladder_sfx_path):
		push_warning("[c2_floor] ladder sfx missing, skipped: %s" % ladder_sfx_path)
		return
	_ladder_sfx.stream = load(ladder_sfx_path)
	_ladder_sfx.play()


## c2_dialogue3 播完且 ladder 已到状态 "3" → 启动结局（防重入，整局一次）
func _on_dialogue_finished() -> void:
	if GameState.get_object_state(Ladder.STATE_KEY) != "3":
		return
	_start_ending()


## 结局序列：锁输入 → curten 消失 → 开窗音效 → 4s 渐白 → 纯白 3s → 转场
func _start_ending() -> void:
	if GameState.get_process_flag(FLAG_ENDING):
		return
	GameState.set_process_flag(FLAG_ENDING, true)
	print("[c2_floor] ending started")
	StoryMonitor.lock_input()
	# curten 消失（写 GameState 便于读档一致）
	GameState.set_object_state(ID_CURTEN, "1")
	if _curten != null:
		_curten.queue_free()
		_curten = null
	_window_sfx.play()
	# 4 秒内渐变为纯白
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 4.0)
	await tween.finished
	# 纯白保持 3 秒
	await get_tree().create_timer(3.0).timeout
	_window_sfx.stop()
	get_tree().change_scene_to_file(ENDING_SCENE)


## 读档恢复：curten 已消失不重现；ladder=="3" 但结局未播（对话3 中途退出）→ 补触发结局
## （lego 消失态与 ladder 贴图分别由 VanishItem / Ladder 各自 _ready 恢复）
func _restore_progress() -> void:
	if GameState.get_object_state(ID_CURTEN) == "1" and _curten != null:
		_curten.queue_free()
		_curten = null
	if GameState.get_object_state(Ladder.STATE_KEY) == "3" \
			and not GameState.get_process_flag(FLAG_ENDING):
		call_deferred("_start_ending")
