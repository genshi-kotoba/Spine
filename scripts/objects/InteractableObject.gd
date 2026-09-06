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

@export_category("Interaction SFX")
## 可选的交互成功音效（merge 自 Spine_to_merge）。留空时仍发出 interaction_sfx_requested，便于外部音频管理器接入。
@export var interaction_sfx_stream: AudioStream
@export var interaction_sfx_bus: StringName = &"Master"
@export_range(-80.0, 6.0, 0.1) var interaction_sfx_volume_db: float = 0.0

## 统一音效占位请求；兼容旧式 InteractableObject 交互链路。
signal interaction_sfx_requested
signal interaction_sfx_played

var _interaction_sfx_player: AudioStreamPlayer


func _ready() -> void:
	input_event.connect(_on_input_event)
	_setup_interaction_sfx()
	var saved := GameState.get_object_state(object_id)
	change_state(saved if saved != "" else initial_state)


## 根据状态设置本对象的 size、position、纹理图像（纹理用状态→贴图路径映射表配置）
## states[state] = {"texture": 贴图路径, "size": Vector2, "position": Vector2}（键均可选）
func apply_state(state: String) -> void:
	var config: Dictionary = states.get(state, {})
	if config.has("position"):
		position = config["position"]
	if config.has("size"):
		var collision := get_node_or_null("CollisionShape2D")
		if collision and collision.shape is RectangleShape2D:
			collision.shape.size = config["size"]
	if config.has("texture"):
		var sprite := get_node_or_null("Sprite2D")
		if sprite:
			sprite.texture = load(config["texture"])


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
		_request_interaction_sfx()


## 供 LevelScene 等外部交互路由在 interact() 后调用的统一音效占位（merge 自 Spine_to_merge）。
func request_interaction_sfx() -> void:
	_request_interaction_sfx()


func _setup_interaction_sfx() -> void:
	var existing_player := get_node_or_null("InteractionSfxPlayer") as AudioStreamPlayer
	if existing_player != null:
		_interaction_sfx_player = existing_player
	elif interaction_sfx_stream != null:
		_interaction_sfx_player = AudioStreamPlayer.new()
		_interaction_sfx_player.name = "InteractionSfxPlayer"
		add_child(_interaction_sfx_player)
	else:
		return
	if interaction_sfx_stream != null:
		_interaction_sfx_player.stream = interaction_sfx_stream
		_interaction_sfx_player.volume_db = interaction_sfx_volume_db
	_interaction_sfx_player.bus = interaction_sfx_bus if AudioServer.get_bus_index(interaction_sfx_bus) >= 0 else &"Master"


func _request_interaction_sfx() -> void:
	interaction_sfx_requested.emit()
	if _interaction_sfx_player == null or _interaction_sfx_player.stream == null:
		return
	_interaction_sfx_player.play()
	interaction_sfx_played.emit()
