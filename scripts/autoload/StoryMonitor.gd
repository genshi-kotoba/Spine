extends Node
## StoryMonitor — Autoload 单例
## 职责：监听 GameState.state_changed，按触发条件表匹配剧情；剧情期间锁定全局输入。
## 本阶段仅框架：条件表留空，剧情执行逻辑以 TODO 预留。

signal story_triggered(story_id: String)

## 触发条件表：条件 = 一组对象状态组合（本阶段留空，后续在编辑器或脚本中配置）
var trigger_table: Array = []

## 已触发过的剧情 ID（每个剧情只触发一次）
var triggered_ids: Array[String] = []

## 全局输入锁定：主场景与关卡场景的输入处理必须先检查该状态
var input_locked: bool = false


func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)


func lock_input() -> void:
	input_locked = true


func unlock_input() -> void:
	input_locked = false


func _on_state_changed(object_id: String, new_state: String) -> void:
	# TODO: 遍历 trigger_table，匹配对象状态组合；
	# 命中且未触发过时，按剧情类型（cutscene / dialogue）执行并 lock_input()，
	# 剧情结束后 unlock_input()，每个剧情只触发一次。
	pass
