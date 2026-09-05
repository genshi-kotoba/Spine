class_name C2Floor
extends FloorTemplate
## C2Floor — c2 关卡：ladder 四态状态机驱动的线性流程 + 白屏转场结局（v2）
## （docs/c2_refactor_constraints.md §4.1）
## v2 时序：lego 交互 → 先音效+对话 → 相机 0.75s 平滑到场景正中 → ladder 换贴图
##   → 0.75s 平滑回玩家恢复跟随。
## v2 结局：ladder 到状态 "3" → curten 变为可交互；玩家对 curten 按 E → curten 消失
##   → 锁输入 → 开窗音效 → 4s 渐白 → 3s 纯白 → computer_screen（防重入，整局一次）。
## 相机接管：覆写 _update_camera + _camera_locked，LevelScene 零改动。
## 连锁统一由本脚本监听 GameState.state_changed 驱动，item 脚本内不做互相引用。


## 三个 lego 的 GameState 状态键
const LEGO_IDS: Array[String] = ["c2_lego1", "c2_lego2", "c2_lego3"]

## 第 n 次 lego 交互 → 对话文件（与具体哪个 lego 解耦）
const DIALOGUE_PATHS: Dictionary = {
	1: "res://dialogues/c2_dialogue1.txt",
	2: "res://dialogues/c2_dialogue2.txt",
	3: "res://dialogues/c2_dialogue3.txt",
}

## curten 的 GameState 状态键
const ID_CURTEN: String = "c2_curten"

## 结局已播 process_flag（防重入 + 读档一致）
const FLAG_ENDING: String = "c2_ending_done"

## 结局目标场景
const ENDING_SCENE: String = "res://scenes/computer_screen.tscn"

## 场景正中间视野中心（地图 3840 宽 × 游戏带 y∈[211,1028] 的几何中心）
const SCENE_CENTER: Vector2 = Vector2(1920, 619.5)

## 相机强制移动时长（秒）
const CAMERA_MOVE_TIME: float = 0.75

## ladder 音效路径（文件暂缺：禁止 preload，运行时存在性检查后加载，缺失仅 warning）
@export var ladder_sfx_path: String = "res://assets/audio/ladder.mp3"

## 相机接管标志：true 时 _update_camera 挂起（Tween 接管相机），false 恢复逐帧跟随
var _camera_locked: bool = false

@onready var _ladder: Ladder = $Items/Ladder
@onready var _curten: Area2D = $Items/Curten
@onready var _ladder_sfx: AudioStreamPlayer = $LadderSfx
@onready var _window_sfx: AudioStreamPlayer = $WindowSfx
@onready var _fade_rect: ColorRect = $EndingLayer/FadeRect


func _ready() -> void:
	super._ready()
	GameState.state_changed.connect(_on_state_changed)
	_restore_progress()


## 相机接管：锁定期间挂起 LevelScene 的逐帧跟随（虚方法分派，LevelScene 零改动）
func _update_camera(delta: float) -> void:
	if _camera_locked:
		return
	super._update_camera(delta)


func _on_state_changed(object_id: String, new_state: String) -> void:
	if LEGO_IDS.has(object_id) and new_state == "1":
		_run_lego_sequence()
	elif object_id == Ladder.STATE_KEY and new_state == "3":
		_enable_curten()
	elif object_id == ID_CURTEN and new_state == "1":
		_start_ending()


## v2 lego 时序（async）：音效+对话 → 相机至正中(0.75s) → ladder 换贴图 → 相机回玩家(0.75s)
func _run_lego_sequence() -> void:
	_play_ladder_sfx()
	var n: int = _lego_count()
	if DIALOGUE_PATHS.has(n):
		print("[c2_floor] lego count=%d, start dialogue %d" % [n, n])
		DialogueManager.start_dialogue(DIALOGUE_PATHS[n], DialogueManager.MODE_INTERACTIVE)
	# 相机强制移动到场景正中间（global_position 目标 = 视野中心 - offset）
	_camera_locked = true
	var tween_in: Tween = create_tween()
	tween_in.tween_property(_camera, "global_position",
			SCENE_CENTER - _camera.offset, CAMERA_MOVE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_in.finished
	# 此刻才更换 ladder 贴图
	_ladder.advance_state()
	# 平滑回到玩家跟随位（x 与 clamp 结果一致，解锁后无缝衔接）
	var back: Vector2 = Vector2(_follow_target_x(), _player.global_position.y)
	var tween_out: Tween = create_tween()
	tween_out.tween_property(_camera, "global_position", back, CAMERA_MOVE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_out.finished
	_camera_locked = false


## 复现 LevelScene clamp 语义：返回相机应跟随的 x（倒挂保护同原逻辑）
func _follow_target_x() -> float:
	var half_width: float = get_viewport_rect().size.x * 0.5 * _camera.zoom.x
	var min_bound: float = map_min_x + half_width
	var max_bound: float = map_max_x - half_width
	if min_bound > max_bound:
		return (map_min_x + map_max_x) * 0.5
	var clamped_x: float = clamp(_player.position.x, min_bound, max_bound)
	return clamped_x


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


## ladder 到达状态 "3"：curten 变为可交互（高亮随范围进出自动恢复）
func _enable_curten() -> void:
	if _curten != null:
		_curten.set_interaction_enabled(true)
		print("[c2_floor] ladder maxed, curten interactable")


## 结局序列（curten 交互触发）：锁输入 → 开窗音效 → 4s 渐白 → 3s 纯白 → 转场
## （curten 已由 VanishItem 自行隐藏并写 GameState，本函数不再处理）
func _start_ending() -> void:
	if GameState.get_process_flag(FLAG_ENDING):
		return
	GameState.set_process_flag(FLAG_ENDING, true)
	print("[c2_floor] ending started")
	StoryMonitor.lock_input()
	_window_sfx.play()
	# 4 秒内渐变为纯白
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 4.0)
	await tween.finished
	# 纯白保持 3 秒
	await get_tree().create_timer(3.0).timeout
	_window_sfx.stop()
	get_tree().change_scene_to_file(ENDING_SCENE)


## 读档恢复：ladder=="3" 且 curten 未消失 → curten 仍可交互；
## curten 已交互但结局未播完（中途退出）→ 清 flag 补播结局（防死档）
## （lego 消失态、ladder 贴图、curten 隐藏态由各 item 自身 _ready 恢复）
func _restore_progress() -> void:
	if GameState.get_object_state(Ladder.STATE_KEY) == "3" \
			and GameState.get_object_state(ID_CURTEN) != "1":
		_enable_curten()
	if GameState.get_object_state(ID_CURTEN) == "1":
		GameState.set_process_flag(FLAG_ENDING, false)
		call_deferred("_start_ending")
