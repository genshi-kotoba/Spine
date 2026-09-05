class_name OkPopup
extends CanvasLayer
## OkPopup — 交互成功占位提示（新需求 t26）
## 黑色字体 "ok" 文本，在【确定交互成功】后短暂显示（约 0.7s 后消失），作占位（后续换真实反馈）。
## 监听 item.interaction_succeeded 信号（由 C3Flow 接线）；可复用（无关卡字面量）。

## 字体大小。
@export var font_size: int = 40
## 文本颜色（黑）。
@export var text_color: Color = Color(0, 0, 0, 1)
## 显示时长（s）。
@export var display_time: float = 0.7
## 文本偏移（相对指定位置）。
@export var text_offset: Vector2 = Vector2(0, -40)

var _label: Label = null
var _timer: SceneTreeTimer = null


func _ready() -> void:
	layer = 10
	_build_label()
	_show(false)


func _build_label() -> void:
	_label = Label.new()
	_label.name = "OkLabel"
	_label.text = "ok"
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", text_color)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)


## 显示一次 "ok"（可指定落点；空则取上一个位置/默认）。
## 世界坐标须转屏幕坐标（CanvasLayer 用屏幕像素，f3）。
func show_ok(global_pos: Vector2 = Vector2.ZERO) -> void:
	if _label == null:
		return
	if global_pos != Vector2.ZERO:
		var screen := get_viewport().get_canvas_transform() * global_pos
		_label.position = screen + text_offset
	_show(true)
	_reset_timer()


func _show(visible: bool) -> void:
	if _label != null:
		_label.visible = visible


func _reset_timer() -> void:
	_timer = get_tree().create_timer(display_time)
	_timer.timeout.connect(func() -> void: _show(false))
