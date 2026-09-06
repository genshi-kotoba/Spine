class_name C5Floor
extends FloorTemplate
## C5Floor — C5 楼层（docs/c5_floor_constraints.md）
## 3 个隐形触发区顺序唤起 tr1/tr2/tr3 对话（各整局一次，process_flags 记已播）；
## 三段全部播完 → 2s 渐黑 → EndingTextSequence 播 1~7.txt → sequence_finished → 退出游戏。

## 触发区对话文本（texts/，决策 D1：用户已放真实文本于此，不用 prompt 的 dialogues/ 路径）
const TRIGGER_TEXTS: Array[String] = [
	"res://texts/tr1.txt",
	"res://texts/tr2.txt",
	"res://texts/tr3.txt",
]
## 结尾序列文本（顺序即播放顺序）
const ENDING_TEXTS: Array[String] = [
	"res://texts/1.txt",
	"res://texts/2.txt",
	"res://texts/3.txt",
	"res://texts/4.txt",
	"res://texts/5.txt",
	"res://texts/6.txt",
	"res://texts/7.txt",
]
## 已播旗标键前缀（process_flags）
const FLAG_PREFIX := "c5_tr"

@onready var _black_rect: ColorRect = $EndingLayer/BlackRect
@onready var _ending_sequence: EndingTextSequence = $EndingTextSequence

## 各触发区对话是否已播完（运行态；已播标记持久层是 process_flags）
var _tr_finished: Array[bool] = [false, false, false]
## 当前等待播完的触发区编号（0 基；-1 = 无）
var _pending_trigger: int = -1
## 结尾序列防重入
var _ending_started: bool = false


func _ready() -> void:
	super._ready()
	var triggers := get_node_or_null("Triggers")
	if triggers != null:
		var idx := 0
		for child in triggers.get_children():
			if child is Area2D:
				(child as Area2D).body_entered.connect(_on_trigger_entered.bind(idx))
				idx += 1
	if not DialogueManager.dialogue_finished.is_connected(_on_dialogue_finished):
		DialogueManager.dialogue_finished.connect(_on_dialogue_finished)


## 玩家首次进入触发区 → 记旗标 + 停用自身 + 唤起对话（MODE_INTERACTIVE 锁输入任意键切句）
func _on_trigger_entered(body: Node2D, idx: int) -> void:
	if not (body is Player):
		return
	if idx < 0 or idx >= TRIGGER_TEXTS.size():
		return
	var flag: String = "%s%d_shown" % [FLAG_PREFIX, idx + 1]
	if GameState.get_process_flag(flag):
		return
	GameState.set_process_flag(flag, true)
	var triggers := get_node_or_null("Triggers")
	if triggers != null:
		var area := triggers.get_child(idx) as Area2D
		if area != null:
			area.set_deferred("monitoring", false)
	_pending_trigger = idx
	DialogueManager.start_dialogue(TRIGGER_TEXTS[idx], DialogueManager.MODE_INTERACTIVE)


## 对话播完：标记对应触发区完成；三段齐 → 启动结尾
func _on_dialogue_finished() -> void:
	if _pending_trigger >= 0 and _pending_trigger < _tr_finished.size():
		_tr_finished[_pending_trigger] = true
		_pending_trigger = -1
	for done: bool in _tr_finished:
		if not done:
			return
	_start_ending()


## 结尾：锁输入 → 2s 渐黑 → 七段文字序列 → 退出游戏（防重入整局一次）
func _start_ending() -> void:
	if _ending_started:
		return
	_ending_started = true
	StoryMonitor.lock_input()
	if _black_rect != null:
		_black_rect.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_black_rect, "modulate:a", 1.0, 2.0)
		await tween.finished
	if _ending_sequence != null:
		_ending_sequence.start(ENDING_TEXTS)
		await _ending_sequence.sequence_finished
	get_tree().quit()
