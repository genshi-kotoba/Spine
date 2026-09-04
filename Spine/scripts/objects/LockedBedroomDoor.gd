class_name LockedBedroomDoor
extends InteractableObject
## LockedBedroomDoor — 客厅中央卧室门（用户定案 2026-09-05：正视房门样式、纯背景不阻挡、触发即开）
## 锁态语义保留：GameState 仍存 locked（解锁玩法待用户设计，interact() 空实现）；
## 门体不再物理阻挡（纯背景），玩家进入检测区触发开门摆开动画，离开后延迟关闭。

@export var trigger_margin: float = 40.0
## 开门动画时长（s）
@export var open_duration: float = 0.35
## 离开后延迟关门（s）
@export var close_delay: float = 0.8

@onready var _door_visual: Polygon2D = $DoorBody/DoorLeaf

var is_open: bool = false
var _tween: Tween = null
var _close_countdown: float = 0.0
var _base_rotation: float = 0.0


func _ready() -> void:
	# 状态集合仅含 locked（解锁玩法待用户设计）
	states = {"locked": {}}
	super._ready()
	_base_rotation = _door_visual.rotation
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func interact() -> void:
	# 禁止解锁玩法：解锁待用户设计。此处刻意保持空实现。
	pass


func _process(delta: float) -> void:
	# 离开后延迟关门（_process 倒计时，headless 下可靠）
	if _close_countdown > 0.0:
		_close_countdown -= delta
		if _close_countdown <= 0.0:
			_do_close()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		open()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		close()


## 开门：门扇绕门轴摆开（正视门样式）
func open() -> void:
	_close_countdown = 0.0
	if is_open:
		return
	is_open = true
	_animate_to(true)


## 关门：延迟 close_delay 后执行；close_delay=0 语义 = 立即关门
func close() -> void:
	if not is_open or _close_countdown > 0.0:
		return
	if close_delay <= 0.0:
		_do_close()
		return
	_close_countdown = close_delay


func _do_close() -> void:
	_close_countdown = 0.0
	if not is_open:
		return
	is_open = false
	_animate_to(false)


func _animate_to(opening: bool) -> void:
	if _tween != null:
		_tween.kill()
	var target_rotation: float = deg_to_rad(-95.0) if opening else _base_rotation
	_tween = create_tween()
	_tween.tween_property(_door_visual, "rotation", target_rotation, open_duration) 		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
