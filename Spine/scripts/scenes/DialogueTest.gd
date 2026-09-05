class_name DialogueTest
extends Node2D
## DialogueTest — 对话系统测试场景
## T：对话1（交互模式，锁输入 + 1s 冷却）
## Y：对话2（自动模式，每句 4s 自动切换）
## U：对话3（故障散落字幕，生命周期同自动模式）
## 输入锁定期间（交互模式对话中）T/Y/U 不生效；自动/故障模式期间 T/Y/U 正常入队。


func _unhandled_input(event: InputEvent) -> void:
	if StoryMonitor.input_locked:
		return
	if event.is_action_pressed("dialogue_t"):
		DialogueManager.start_dialogue("res://dialogues/dialogue1.txt", DialogueManager.MODE_INTERACTIVE)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dialogue_y"):
		DialogueManager.start_dialogue("res://dialogues/dialogue2.txt", DialogueManager.MODE_AUTO)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dialogue_u"):
		DialogueManager.start_dialogue("res://dialogues/dialogue3.txt", DialogueManager.MODE_GLITCH)
		get_viewport().set_input_as_handled()
