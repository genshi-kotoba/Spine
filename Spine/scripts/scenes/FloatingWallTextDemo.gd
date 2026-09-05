extends Node2D
## 独立演示与 headless 验收入口。

@onready var floating_text: FloatingWallText = $FloatingWallText


func _ready() -> void:
	if "--self-check" in OS.get_cmdline_user_args():
		_run_self_check.call_deferred()


func _run_self_check() -> void:
	await get_tree().process_frame
	var failures: Array[String] = []
	if floating_text.get_entry_count() != floating_text.phrases.size():
		failures.append("entry_count")
	var font_sizes := floating_text.get_entry_font_sizes()
	var unique_sizes: Dictionary = {}
	for font_size in font_sizes:
		unique_sizes[font_size] = true
	if unique_sizes.size() < 2:
		failures.append("font_variation")
	var before := floating_text.get_entry_positions()
	for i in range(8):
		await get_tree().process_frame
	var after := floating_text.get_entry_positions()
	var moved := false
	for i in range(mini(before.size(), after.size())):
		if not before[i].is_equal_approx(after[i]):
			moved = true
			break
	if not moved:
		failures.append("motion")
	floating_text.set_phrases(PackedStringArray(["墙上的字", "仍在呼吸", "不要靠近"]))
	await get_tree().process_frame
	if floating_text.get_entry_count() != 3:
		failures.append("runtime_rebuild")
	if failures.is_empty():
		print("[floating_wall_text_demo] SELF-CHECK PASS")
	else:
		print("[floating_wall_text_demo] SELF-CHECK FAIL: " + ", ".join(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
