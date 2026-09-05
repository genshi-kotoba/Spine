class_name AnimatedObjectSample
extends InteractableObject
## AnimatedObjectSample — 空示例子类（带动画钩子）
## 本阶段仅框架：不填充状态集合、贴图映射与动画内容。


## 状态集合（示例枚举，后续按对象设计填充）
enum State { IDLE }


func _ready() -> void:
	# TODO: 填充 states 映射表（状态 → size / position / 贴图路径）
	super._ready()


func play_state_animation(state: String) -> void:
	# TODO: 使用 _animated_sprite 播放状态对应动画
	pass


func interact() -> void:
	# TODO: 定义点击/按键交互时的状态切换规则
	pass
