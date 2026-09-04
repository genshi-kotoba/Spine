class_name InteractableObject
extends Area2D
## InteractableObject — 可交互对象基类
## 所有可交互对象的场景与脚本都基于此基类。
## 内部维护状态机，当前状态同步到 GameState 全局变量。
## 本阶段仅框架：状态集合与贴图映射由子类填充，动画为虚方法预留。

## 对象唯一 ID（GameState 字典的 key）
@export var object_id: String = ""

## 初始状态（状态集合在子类中枚举定义）
@export var initial_state: String = ""

## 状态 → 配置映射表（size / position / 贴图路径），子类填充
var states: Dictionary = {}

## 状态机当前状态
var current_state: String = ""

## 动画节点引用（有动画的对象在场景中挂载；无动画对象退化为静态贴图切换）
@onready var _animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	input_event.connect(_on_input_event)
	var saved := GameState.get_object_state(object_id)
	change_state(saved if saved != "" else initial_state)


## 根据状态设置本对象的 size、position、纹理图像（纹理用状态→贴图路径映射表配置）
func apply_state(state: String) -> void:
	# TODO: 从 states 映射表读取 size / position / 贴图路径并应用
	pass


## 切换状态机 → 更新 GameState → 调用 apply_state → 需要时播放对应动画
func change_state(new_state: String) -> void:
	current_state = new_state
	if object_id != "":
		GameState.set_object_state(object_id, new_state)
	apply_state(new_state)
	play_state_animation(new_state)


## 外部触发入口（被其他对象/角色调用，关卡场景用）。子类按需覆写。
func interact() -> void:
	# TODO: 子类定义状态切换规则
	pass


## 播放状态对应动画。无动画对象保持默认空实现即可。
func play_state_animation(state: String) -> void:
	pass


## 被点击触发（主场景用）
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if StoryMonitor.input_locked:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		interact()
