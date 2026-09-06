class_name EndingTextSequence
extends CanvasLayer
## EndingTextSequence — 结尾文字序列组件（docs/c5_floor_constraints.md §5）
## start(paths) 逐文件播放：逐行亮起（0.5s/行，串行保持）→ 整体保持 3.0s →
## 全部行 0.5s 一起淡出 → 下一文件。全部播完发 sequence_finished。
## 状态机用 Tween + await，不用 Timer 堆叠；输入锁由调用方负责；不支持跳过。

## 全部文件播完（末文件淡出后）
signal sequence_finished

## 字号
const FONT_SIZE := 18
## 行间距（= 字号的一半）
const LINE_SPACING := 9
## 单行亮起时长（秒）
const LINE_FADE_SEC := 0.5
## 单文件末行亮起后的整体保持时长（秒）
const HOLD_SEC := 3.0
## 单文件全体淡出时长（秒）
const FILE_FADE_SEC := 0.5

var _running: bool = false


## 依次播放 paths 指向的文本文件；缺失/空文件 push_error 后跳过，不中断序列。
func start(paths: Array[String]) -> void:
	if _running:
		return
	_running = true
	for path: String in paths:
		var lines: Array[String] = _load_lines(path)
		if lines.is_empty():
			continue
		await _play_file(lines)
	_running = false
	sequence_finished.emit()


## 单文件：逐行建 Label（屏幕居中成块）→ 逐行亮起 → 保持 → 全体淡出 → 清理。
func _play_file(lines: Array[String]) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", LINE_SPACING)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)
	var labels: Array[Label] = []
	for line: String in lines:
		var lab := Label.new()
		lab.text = line
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", FONT_SIZE)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.modulate.a = 0.0
		vbox.add_child(lab)
		labels.append(lab)
	# 严格逐行串行亮起，亮起后保持
	for lab: Label in labels:
		var tween := create_tween()
		tween.tween_property(lab, "modulate:a", 1.0, LINE_FADE_SEC)
		await tween.finished
	# 末行亮起后整体保持
	await get_tree().create_timer(HOLD_SEC).timeout
	# 全部行一起淡出
	var fade_out := create_tween()
	for lab: Label in labels:
		fade_out.parallel().tween_property(lab, "modulate:a", 0.0, FILE_FADE_SEC)
	await fade_out.finished
	center.queue_free()


## 按行读 UTF-8 文本：忽略空行；缺失 push_error 返回空数组。
func _load_lines(path: String) -> Array[String]:
	var lines: Array[String] = []
	if not FileAccess.file_exists(path):
		push_error("EndingTextSequence: 文本缺失 %s" % path)
		return lines
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("EndingTextSequence: 无法读取 %s" % path)
		return lines
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line != "":
			lines.append(line)
	return lines
