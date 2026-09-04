class_name StaticObjectSample
extends InteractableObject
## StaticObjectSample — 空示例子类（无动画，静态贴图切换）
## 本阶段仅框架：不填充状态集合与贴图映射。


## 状态集合（示例枚举，后续按对象设计填充）
enum State { IDLE }


func _ready() -> void:
	# TODO: 填充 states 映射表（状态 → size / position / 贴图路径）
	super._ready()


func interact() -> void:
	# TODO: 定义点击/按键交互时的状态切换规则
	pass
