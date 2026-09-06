class_name WorkIcon
extends InteractableObject
## WorkIcon — 工作图标
## 点击后发出 open_work 信号，由 ComputerScreen 打开 work_screen 弹层
## （docs/desktop_screens_constraints.md §4.4；取消点击直接跳场景）。


## 请求打开工作弹层
signal open_work


func _ready() -> void:
	states = {
		"idle": {
			"texture": "res://assets/sprites/work_icon.png",
			"size": Vector2(50, 70),
		},
	}
	super._ready()


## 点击 → 请求打开工作弹层
func interact() -> void:
	open_work.emit()
