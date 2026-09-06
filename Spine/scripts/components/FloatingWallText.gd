@tool
class_name FloatingWallText
extends Node2D
## 可直接实例化的破碎悬浮文字组件。
## 复用 main 分支的 glitch_char shader：逐字散落、切片错位、RGB 分离、闪烁和抖动。

const GLITCH_SHADER := preload("res://assets/shaders/glitch_char.gdshader")

@export_group("Content")
@export var phrases: PackedStringArray = PackedStringArray([
	"知道得太多，也是一种病。",
	"不要回头",
	"门后没有答案",
	"保持安静",
	"记录不会说谎",
	"它在阅读你",
]):
	set(value):
		phrases = value
		_request_rebuild()

@export_multiline var font_families: String = "PingFang SC\nMicrosoft YaHei\nNoto Sans CJK SC\nSimSun":
	set(value):
		font_families = value
		_request_rebuild()

@export_group("Layout")
@export var layout_size: Vector2 = Vector2(900.0, 420.0):
	set(value):
		layout_size = value.max(Vector2(160.0, 100.0))
		_request_rebuild()
@export_range(12, 160, 1) var min_font_size: int = 28:
	set(value):
		min_font_size = value
		_request_rebuild()
@export_range(12, 180, 1) var max_font_size: int = 58:
	set(value):
		max_font_size = value
		_request_rebuild()
@export_range(0.0, 18.0, 0.1) var max_tilt_degrees: float = 5.5:
	set(value):
		max_tilt_degrees = value
		_request_rebuild()
@export var seed_value: int = 7319:
	set(value):
		seed_value = value
		_request_rebuild()

@export_group("Appearance")
@export var text_color: Color = Color("e8e1d1"):
	set(value):
		text_color = value
		_request_rebuild()
@export var accent_color: Color = Color("c43d32"):
	set(value):
		accent_color = value
		_request_rebuild()
@export var shadow_color: Color = Color(0.02, 0.015, 0.015, 0.92):
	set(value):
		shadow_color = value
		_request_rebuild()
@export var glow_color: Color = Color(1.0, 1.0, 1.0, 0.28):
	set(value):
		glow_color = value
		_request_rebuild()
@export_range(0, 16, 1) var outline_size: int = 3:
	set(value):
		outline_size = value
		_request_rebuild()
@export_range(1, 8, 1) var accent_frequency: int = 3:
	set(value):
		accent_frequency = value
		_request_rebuild()

@export_group("Motion")
@export var animated: bool = true:
	set(value):
		animated = value
		set_process(animated or Engine.is_editor_hint())
@export var animate_in_editor: bool = true
@export_range(0.0, 8.0, 0.1) var jitter_amount: float = 1.8
@export_range(0.0, 12.0, 0.1) var float_amount: float = 3.5
@export_range(0.1, 8.0, 0.1) var motion_speed: float = 1.2
@export_range(0.0, 2.0, 0.01) var entrance_duration: float = 0.38
@export_range(0.0, 0.5, 0.01) var entrance_stagger: float = 0.06

var _font: SystemFont
var _content: Node2D
var _entries: Array[Dictionary] = []
var _elapsed := 0.0
var _rebuild_queued := false
var _glitch_material: ShaderMaterial = null


func _ready() -> void:
	_glitch_material = ShaderMaterial.new()
	_glitch_material.shader = GLITCH_SHADER
	_ensure_content()
	_rebuild()
	set_process(animated or Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		play_entrance()


func _process(delta: float) -> void:
	if not animated or (Engine.is_editor_hint() and not animate_in_editor):
		return
	_elapsed += delta
	for entry in _entries:
		var holder := entry["holder"] as Node2D
		if not is_instance_valid(holder):
			continue
		var phase := float(entry["phase"])
		var base_position := entry["base_position"] as Vector2
		var base_rotation := float(entry["base_rotation"])
		var micro_x := sin(_elapsed * motion_speed * 5.7 + phase * 1.3) * jitter_amount
		var micro_y := sin(_elapsed * motion_speed * 7.9 + phase * 0.7) * jitter_amount * 0.55
		holder.position = base_position + Vector2(micro_x, micro_y)
		holder.rotation = base_rotation


## 运行时替换全部文字；布局与动画会立即重建。
func set_phrases(value: PackedStringArray) -> void:
	phrases = value


## 播放逐条显现演出。模块默认在运行时进入场景时自动播放一次。
func play_entrance() -> void:
	for i in range(_entries.size()):
		var holder := _entries[i]["holder"] as Node2D
		holder.modulate.a = 0.0
		holder.scale = Vector2(0.96, 0.96)
		if entrance_duration <= 0.0:
			holder.modulate.a = 1.0
			holder.scale = Vector2.ONE
			continue
		var tween := create_tween()
		tween.tween_interval(float(i) * entrance_stagger)
		tween.tween_property(holder, "modulate:a", 1.0, entrance_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(holder, "scale", Vector2.ONE, entrance_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 供流程脚本控制整体淡入/淡出，不改变各条文字配置。
func set_revealed(value: bool, duration: float = 0.2) -> void:
	var target_alpha := 1.0 if value else 0.0
	if duration <= 0.0:
		modulate.a = target_alpha
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", target_alpha, duration)


func get_entry_count() -> int:
	return _entries.size()


func get_entry_font_sizes() -> PackedInt32Array:
	var result := PackedInt32Array()
	for entry in _entries:
		result.append(int(entry["font_size"]))
	return result


func get_entry_positions() -> PackedVector2Array:
	var result := PackedVector2Array()
	for entry in _entries:
		var holder := entry["holder"] as Node2D
		result.append(holder.position)
	return result


func _request_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _ensure_content() -> void:
	_content = get_node_or_null("GeneratedText") as Node2D
	if _content == null:
		_content = Node2D.new()
		_content.name = "GeneratedText"
		add_child(_content)


func _rebuild() -> void:
	_rebuild_queued = false
	_ensure_content()
	for child in _content.get_children():
		child.free()
	_entries.clear()
	_font = SystemFont.new()
	_font.font_names = _font_names()
	var clean_phrases: PackedStringArray = []
	for phrase in phrases:
		var clean := phrase.strip_edges()
		if not clean.is_empty():
			clean_phrases.append(clean)
	if clean_phrases.is_empty():
		queue_redraw()
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var columns := 1 if clean_phrases.size() == 1 else 2
	var rows := ceili(float(clean_phrases.size()) / float(columns))
	var cell_size := Vector2(layout_size.x / float(columns), layout_size.y / float(rows))
	var safe_min := mini(min_font_size, max_font_size)
	var safe_max := maxi(min_font_size, max_font_size)
	for i in range(clean_phrases.size()):
		var holder := Node2D.new()
		holder.name = "Phrase%02d" % (i + 1)
		_content.add_child(holder)
		var font_size := rng.randi_range(safe_min, safe_max)
		if safe_max > safe_min and clean_phrases.size() > 1:
			font_size = clampi(font_size + (safe_max - safe_min) * (1 if i % 3 == 0 else -1) / 5, safe_min, safe_max)
		var label_size := _fit_label_size(clean_phrases[i], font_size, cell_size.x - 36.0)
		font_size = int(label_size.y)
		var measured := _font.get_string_size(clean_phrases[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var accent := (i + 1) % maxi(1, accent_frequency) == 0
		_add_label(holder, clean_phrases[i], font_size, measured, accent)
		var col := i % columns
		var row := i / columns
		var cell_center := Vector2(
			-layout_size.x * 0.5 + cell_size.x * (float(col) + 0.5),
			-layout_size.y * 0.5 + cell_size.y * (float(row) + 0.5)
		)
		var offset_limit := Vector2(cell_size.x * 0.12, cell_size.y * 0.16)
		var base_position := cell_center + Vector2(rng.randf_range(-offset_limit.x, offset_limit.x), rng.randf_range(-offset_limit.y, offset_limit.y))
		var base_rotation := deg_to_rad(rng.randf_range(-max_tilt_degrees, max_tilt_degrees))
		holder.position = base_position
		holder.rotation = base_rotation
		_entries.append({
			"holder": holder,
			"base_position": base_position,
			"base_rotation": base_rotation,
			"phase": rng.randf_range(0.0, TAU),
			"font_size": font_size,
			"size": measured,
			"accent": accent,
		})
	queue_redraw()


func _add_label(holder: Node2D, value: String, font_size: int, measured: Vector2, accent: bool) -> void:
	var label_position := -measured * 0.5
	# 每个字独立生成，沿用 MODE_GLITCH 的右移步进与上下 10~30px 散落。
	var char_rng := RandomNumberGenerator.new()
	char_rng.seed = hash(value) ^ seed_value
	var cursor := label_position
	for i in range(value.length()):
		var ch := value.substr(i, 1)
		var glyph := Label.new()
		glyph.name = "Glyph%02d" % i
		glyph.text = ch
		glyph.position = cursor + Vector2(0.0, char_rng.randf_range(-30.0, 30.0))
		glyph.rotation = deg_to_rad(char_rng.randf_range(-5.0, 5.0))
		glyph.scale = Vector2.ONE * char_rng.randf_range(0.9, 1.1)
		glyph.add_theme_font_override("font", _font)
		glyph.add_theme_font_size_override("font_size", font_size)
		glyph.add_theme_color_override("font_color", Color.WHITE if not accent else text_color)
		glyph.add_theme_color_override("font_outline_color", shadow_color)
		glyph.add_theme_constant_override("outline_size", outline_size)
		if _glitch_material != null:
			glyph.material = _glitch_material
		holder.add_child(glyph)
		cursor.x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _fit_label_size(value: String, initial_size: int, available_width: float) -> Vector2:
	var size := initial_size
	while size > mini(min_font_size, max_font_size):
		var measured := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		if measured.x <= available_width:
			break
		size -= 1
	return Vector2(_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, float(size))


func _font_names() -> PackedStringArray:
	var result := PackedStringArray()
	for family in font_families.split("\n", false):
		var clean := family.strip_edges()
		if not clean.is_empty():
			result.append(clean)
	return result


func _draw() -> void:
	var half := layout_size * 0.5
	var corner := 34.0
	draw_line(Vector2(-half.x, -half.y + corner), Vector2(-half.x, -half.y), accent_color, 3.0)
	draw_line(Vector2(-half.x, -half.y), Vector2(-half.x + corner * 2.0, -half.y), accent_color, 3.0)
	draw_line(Vector2(half.x, half.y - corner), Vector2(half.x, half.y), accent_color, 3.0)
	draw_line(Vector2(half.x, half.y), Vector2(half.x - corner * 2.0, half.y), accent_color, 3.0)
	for i in range(_entries.size()):
		var entry := _entries[i]
		var pos := entry["base_position"] as Vector2
		var size := entry["size"] as Vector2
		var rotation_value := float(entry["base_rotation"])
		draw_set_transform(pos, rotation_value)
		if bool(entry["accent"]):
			draw_rect(Rect2(Vector2(-size.x * 0.5 - 12.0, size.y * 0.54), Vector2(size.x + 24.0, 3.0)), accent_color, true)
		else:
			draw_rect(Rect2(Vector2(-size.x * 0.5 - 8.0, size.y * 0.58), Vector2(minf(size.x * 0.28, 64.0), 2.0)), text_color.darkened(0.35), true)
	draw_set_transform(Vector2.ZERO, 0.0)
