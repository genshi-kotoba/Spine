class_name WorkIcon
extends InteractableObject
## WorkIcon — 工作图标
## 点击后发出 open_work 信号，由 ComputerScreen 打开 work_screen 弹层
## （docs/desktop_screens_constraints.md §4.4；取消点击直接跳场景）。


## 请求打开工作弹层
signal open_work

const REMINDER_ANCHOR := Vector2(384.0, -613.0)
var _reminder_root: Node2D
var _reminder_tween: Tween


func _ready() -> void:
	states = {
		"idle": {
			"texture": "res://assets/sprites/work_icon.png",
			"size": Vector2(50, 70),
		},
	}
	super._ready()
	_create_reminder()


## 点击 → 请求打开工作弹层
func interact() -> void:
	_hide_reminder()
	open_work.emit()


## 工作弹层关闭后重新显示提醒。
func show_reminder() -> void:
	_start_reminder()


func _create_reminder() -> void:
	_reminder_root = Node2D.new()
	_reminder_root.name = "WorkReminder"
	_reminder_root.position = REMINDER_ANCHOR
	_reminder_root.z_index = 20
	add_child(_reminder_root)
	var badge := Polygon2D.new()
	badge.name = "RedDot"
	badge.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(8.5, -8.5), Vector2(12, 0), Vector2(8.5, 8.5),
		Vector2(0, 12), Vector2(-8.5, 8.5), Vector2(-12, 0), Vector2(-8.5, -8.5),
	])
	badge.position = Vector2(26, -28)
	badge.color = Color("#ed3b45")
	_reminder_root.add_child(badge)
	_start_reminder()


func _start_reminder() -> void:
	if _reminder_root == null:
		return
	_reminder_root.show()
	if _reminder_tween != null:
		_reminder_tween.kill()
	_reminder_root.rotation = 0.0
	_reminder_tween = create_tween().set_loops()
	_reminder_tween.tween_property(_reminder_root, "rotation", deg_to_rad(-7.0), 0.18)
	_reminder_tween.tween_property(_reminder_root, "rotation", deg_to_rad(7.0), 0.36)
	_reminder_tween.tween_property(_reminder_root, "rotation", 0.0, 0.18)
	_reminder_tween.tween_interval(0.7)


func _hide_reminder() -> void:
	if _reminder_tween != null:
		_reminder_tween.kill()
		_reminder_tween = null
	if _reminder_root != null:
		_reminder_root.hide()
