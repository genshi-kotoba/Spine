class_name GlitchDialogueBox
extends CanvasLayer
## GlitchDialogueBox — 对话模式三（故障散落字幕）UI
## 生命周期与 MODE_AUTO 一致：不锁输入、不接按键切句、自动切换、结束发 dialogue_finished。
## 显示：每句按象限规则取基准点，逐字 0.15s 节奏散落排版，字齐后停留 4s 切句。

signal dialogue_finished

const CHAR_INTERVAL_SEC: float = 0.15
const AUTO_LINE_SEC: float = 4.0
const DY_MIN: float = 10.0
const DY_MAX: float = 30.0
const JITTER_INTERVAL_SEC: float = 0.05
const JITTER_PX: float = 2.0
const FONT_SIZE: int = 32
const ROT_MAX_RAD: float = PI / 36.0  ## ±5°
const SCALE_MIN: float = 0.9
const SCALE_MAX: float = 1.1
const GLITCH_SHADER := preload("res://assets/shaders/glitch_char.gdshader")

@onready var _container: Control = $CharContainer

var _lines: Array = []
var _index: int = 0
var _active: bool = false
var _font_scale: float = 1.0
var _world_anchor: Variant = null
var _persistent: bool = false
var _anchor_screen_origin: Vector2 = Vector2.ZERO
var _line_token: int = 0            ## 自增令牌，防止过期 timer 操作已切句内容
var _quadrant_history: Array[int] = []
var _char_labels: Array[Label] = []
var _base_positions: Array[Vector2] = []
var _layout_positions: Array[Vector2] = []
var _jitter_offsets: Array[Vector2] = []
var _font: SystemFont = null
var _material: ShaderMaterial = null
var _jitter_running: bool = false


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei", "SimSun", "PingFang SC", "Noto Sans CJK SC"])
	_material = ShaderMaterial.new()
	_material.shader = GLITCH_SHADER
	_container.hide()
	print("[glitch_box] ready")
	if OS.get_cmdline_user_args().has("--self-check"):
		_run_self_check()


func is_active() -> bool:
	return _active


func _process(_delta: float) -> void:
	if not _active or _world_anchor == null:
		return
	# CanvasLayer 是屏幕层，但锚点取自世界坐标；相机移动时更新偏移，
	# 使悬浮文本留在场景原位，而不是粘在玩家或视口上。
	var current_anchor: Vector2 = get_viewport().get_canvas_transform() * _world_anchor
	var delta: Vector2 = current_anchor - _anchor_screen_origin
	for i in _layout_positions.size():
		_base_positions[i] = _layout_positions[i] + delta
	_apply_label_positions()


## 开始一段对话（MODE_GLITCH 专用入口）
func show_dialogue(lines: Array, font_scale: float = 1.0, world_anchor: Variant = null, persistent: bool = false) -> void:
	_lines = lines
	_index = 0
	_active = true
	_font_scale = maxf(font_scale, 0.1)
	_world_anchor = world_anchor
	_persistent = persistent
	_quadrant_history.clear()
	_container.show()
	_jitter_running = true
	_jitter_loop()
	_show_line(_index)


## 象限编号：0=左上 1=右上 2=左下 3=右下
func _pick_quadrant() -> int:
	var candidates: Array[int] = []
	for q: int in [0, 1, 2, 3]:
		if not _quadrant_history.has(q):
			candidates.append(q)
	var pick: int = candidates[randi() % candidates.size()]
	_quadrant_history.append(pick)
	while _quadrant_history.size() > 2:
		_quadrant_history.pop_front()
	return pick


func _quadrant_center(q: int) -> Vector2:
	var rect: Rect2 = get_viewport().get_visible_rect()
	var cx: float = rect.size.x / 4.0
	var cy: float = rect.size.y / 4.0
	var center: Vector2 = Vector2(cx, cy)
	if q == 1:
		center = Vector2(rect.size.x - cx, cy)
	elif q == 2:
		center = Vector2(cx, rect.size.y - cy)
	elif q == 3:
		center = Vector2(rect.size.x - cx, rect.size.y - cy)
	return center


## 单字步进：字体实测宽度，为 0 退化为 font_size
func _char_advance(ch: String) -> float:
	var size := int(roundi(float(FONT_SIZE) * _font_scale))
	var w: float = _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if w <= 0.0:
		w = float(size)
	return w


func _clear_chars() -> void:
	for label: Label in _char_labels:
		if is_instance_valid(label):
			label.queue_free()
	_char_labels.clear()
	_base_positions.clear()
	_layout_positions.clear()
	_jitter_offsets.clear()


func _apply_label_positions() -> void:
	var count := mini(_char_labels.size(), mini(_base_positions.size(), _jitter_offsets.size()))
	for i in count:
		if is_instance_valid(_char_labels[i]):
			_char_labels[i].position = _base_positions[i] + _jitter_offsets[i]


func _show_line(line_idx: int) -> void:
	_line_token += 1
	var token: int = _line_token
	_clear_chars()

	var text: String = str(_lines[line_idx])
	var quadrant: int = _pick_quadrant()
	var base_pos: Vector2
	if _world_anchor != null:
		# 运动基准必须保留真实世界锚点；显示位置的 clamp 只作用于本句初始排版，
		# 不能把 clamp 后的位置写回原点，否则相机移动时会叠加错误偏移。
		var raw_anchor: Vector2 = get_viewport().get_canvas_transform() * _world_anchor
		_anchor_screen_origin = raw_anchor
		base_pos = raw_anchor
	else:
		base_pos = _quadrant_center(quadrant)

	# 预估整行宽度，右端超屏则左移 clamp
	var total_w: float = 0.0
	for i: int in text.length():
		total_w += _char_advance(text.substr(i, 1))
	total_w += JITTER_PX * 2.0
	var screen_w: float = get_viewport().get_visible_rect().size.x
	if base_pos.x + total_w > screen_w:
		base_pos.x = screen_w - total_w
	base_pos.x = maxf(base_pos.x, 0.0)

	print("[glitch_box] line %d/%d quadrant=%d base=(%d,%d)" % [line_idx + 1, _lines.size(), quadrant, int(base_pos.x), int(base_pos.y)])
	_spawn_chars(text, base_pos, token)


func _spawn_chars(text: String, base_pos: Vector2, token: int) -> void:
	var pos: Vector2 = base_pos
	_layout_positions.clear()
	for i: int in text.length():
		if token != _line_token or not _active:
			return
		var ch: String = text.substr(i, 1)
		var label: Label = Label.new()
		label.text = ch
		label.add_theme_font_override("font", _font)
		var font_px := int(roundi(float(FONT_SIZE) * _font_scale))
		label.add_theme_font_size_override("font_size", font_px)
		# 按字形绘制紧贴轮廓的灰色外沿，替代整块背景板；在暗场和缺氧遮罩下保持可读。
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.48, 0.52, 0.58, 0.92))
		label.add_theme_constant_override("outline_size", maxi(3, int(roundi(float(font_px) * 0.16))))
		label.material = _material
		label.position = pos
		label.rotation = randf_range(-ROT_MAX_RAD, ROT_MAX_RAD)
		var s: float = randf_range(SCALE_MIN, SCALE_MAX)
		label.scale = Vector2(s, s)
		_container.add_child(label)
		_char_labels.append(label)
		_base_positions.append(pos)
		_layout_positions.append(pos)
		_jitter_offsets.append(Vector2.ZERO)
		# 下一字位置：x 步进 + y 随机偏移 ±[10,30]
		var dir: float = 1.0
		if randf() < 0.5:
			dir = -1.0
		pos = Vector2(pos.x + _char_advance(ch), pos.y + randf_range(DY_MIN, DY_MAX) * dir)
		if i < text.length() - 1:
			await get_tree().create_timer(CHAR_INTERVAL_SEC).timeout
	if _persistent:
		return
	# 整句字齐 → 停留 4s → 切句
	if token != _line_token or not _active:
		return
	await get_tree().create_timer(AUTO_LINE_SEC).timeout
	if token != _line_token or not _active:
		return
	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_show_line(_index)


## 位置抖动：每 0.05s 在散落基准坐标上叠加 ±2px 偏移
func _jitter_loop() -> void:
	while _jitter_running:
		for i: int in _char_labels.size():
			if is_instance_valid(_char_labels[i]):
				_jitter_offsets[i] = Vector2(randf_range(-JITTER_PX, JITTER_PX), randf_range(-JITTER_PX, JITTER_PX))
		_apply_label_positions()
		await get_tree().create_timer(JITTER_INTERVAL_SEC).timeout


func _finish() -> void:
	_active = false
	_jitter_running = false
	_line_token += 1
	_clear_chars()
	_world_anchor = null
	_font_scale = 1.0
	_persistent = false
	_container.hide()
	print("[glitch_box] finished")
	dialogue_finished.emit()


## --self-check：验证象限历史规则（任意句与前两句不同象限）
func _run_self_check() -> void:
	var record: Array[int] = []
	for trial: int in 12:
		var q: int = _pick_quadrant()
		var n: int = record.size()
		if n >= 1 and q == record[n - 1]:
			print("[glitch_box] SELF-CHECK FAIL repeat of previous quadrant")
			get_tree().quit()
			return
		if n >= 2 and q == record[n - 2]:
			print("[glitch_box] SELF-CHECK FAIL repeat of quadrant two lines ago")
			get_tree().quit()
			return
		record.append(q)
	print("[glitch_box] SELF-CHECK PASS quadrant history rule holds over %d picks" % record.size())
	get_tree().quit()
