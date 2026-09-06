class_name MailboxScreen
extends CanvasLayer
## MailboxScreen — 邮箱弹层（重构版，docs/desktop_screens_constraints.md §4.2）
## mailbox.png 原尺寸 Panel（491×483）+ 右上角原尺寸关闭钮 + DragBar 拖拽（clamp 不出屏）
## + 滚轮文本框 + pre/next 切换已解锁邮件（越界重显当前，不循环）。
## 四段老式刷新：盖板 1/2 + 1/6×3，揭开间隔 0.2s/0.1s/0.1s，动画期间忽略 pre/next。
## 打开/关闭语义：closed 信号 + queue_free（ComputerScreen 监听解锁输入）。

## 弹层已关闭
signal closed

## 盖板揭开间隔（Cover1→2 / 2→3 / 3→4）
const REVEAL_DELAYS: Array[float] = [0.2, 0.1, 0.1]

@onready var _dim: ColorRect = $Dim
@onready var _panel: Panel = $Panel
@onready var _drag_bar: Control = $Panel/DragBar
@onready var _close_button: TextureButton = $Panel/CloseButton
@onready var _pre_button: Button = $Panel/PreButton
@onready var _next_button: Button = $Panel/NextButton
@onready var _mail_text: RichTextLabel = $Panel/TextScroll/MailText
@onready var _covers: Array = [
	$Panel/Cover1, $Panel/Cover2, $Panel/Cover3, $Panel/Cover4,
]

## 已解锁邮件列表（有序）
var _mails: Array[int] = []
## 当前显示邮件在 _mails 中的索引
var _current: int = 0
## 刷新动画进行中（忽略 pre/next）
var _animating: bool = false
## 拖拽状态
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_center_panel()
	_close_button.pressed.connect(close)
	_pre_button.pressed.connect(_on_pre_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_drag_bar.gui_input.connect(_on_drag_bar_gui_input)
	_dim.gui_input.connect(_on_dim_gui_input)
	MailWorkManager.mails_changed.connect(_on_mails_changed)
	_reload_mails()
	_show_mail(0)


func _center_panel() -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	_panel.position = (view_size - _panel.size) * 0.5


## 重取已解锁列表并钳制当前索引
func _reload_mails() -> void:
	_mails = MailWorkManager.get_unlocked_mails()
	_current = clamp(_current, 0, _mails.size() - 1)


## 显示指定索引邮件并播放刷新动画（越界 = 重显当前，不循环跳变）
func _show_mail(idx: int) -> void:
	if _mails.is_empty():
		_mail_text.text = "[暂无邮件]"
		return
	_current = clamp(idx, 0, _mails.size() - 1)
	_mail_text.text = MailWorkManager.get_mail_text(_mails[_current])
	_play_refresh()


## 四段刷新：文本一次性填充后被盖板完全遮盖，按序揭开（0.2s / 0.1s / 0.1s）
func _play_refresh() -> void:
	_animating = true
	for cover in _covers:
		cover.show()
	for i: int in _covers.size():
		_covers[i].hide()
		if i < REVEAL_DELAYS.size():
			await get_tree().create_timer(REVEAL_DELAYS[i]).timeout
	_animating = false


func _on_pre_pressed() -> void:
	if _animating:
		return
	_show_mail(_current - 1)


func _on_next_pressed() -> void:
	if _animating:
		return
	_show_mail(_current + 1)


## 弹层打开期间解锁新邮件：刷新列表，保持当前索引（不强制跳新邮件）
func _on_mails_changed() -> void:
	_reload_mails()
	if _mails.is_empty():
		_mail_text.text = "[暂无邮件]"
		return
	_mail_text.text = MailWorkManager.get_mail_text(_mails[_current])


## 拖拽整窗：左键按住 DragBar 拖动，clamp 保证窗口任何部分不超出可视区域
func _on_drag_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = _panel.position - get_viewport().get_mouse_position()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var target: Vector2 = get_viewport().get_mouse_position() + _drag_offset
		var view: Rect2 = get_viewport().get_visible_rect()
		var max_x: float = view.size.x - _panel.size.x
		var max_y: float = view.size.y - _panel.size.y
		var clamped_x: float = clamp(target.x, 0.0, max_x)
		var clamped_y: float = clamp(target.y, 0.0, max_y)
		_panel.position = Vector2(clamped_x, clamped_y)


## 关闭弹层
func close() -> void:
	closed.emit()
	queue_free()


## 点击遮罩（Panel 外区域）关闭
func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
