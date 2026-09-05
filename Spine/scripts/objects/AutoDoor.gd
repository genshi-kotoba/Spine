class_name AutoDoor
extends Area2D
## AutoDoor — 可复用自动木门（规格⑤，规格⑩）
## 触发式：占用 Area2D 的 body 检测，不占用 interact 键。
## 玩家进入检测区时打开门体并禁用其碰撞；离开后延迟 close_delay 自动关闭。
## 宿主楼层模板（FloorTemplate）负责把玩家 body 触发接线到本门（见 FloorTemplate._connect_auto_doors）。
## 本脚本不含任何 C 层专属内容，可复用于任意楼层。
## 关闭延迟用 _process 倒计时实现（不依赖 SceneTreeTimer，避免 headless 下延时不可靠）。

signal door_opened
signal door_closed

## 触发区超出门洞的宽度（px，规格⑩）
@export var trigger_margin: float = 40.0
## 开门动画时长（s，规格⑩）
@export var open_duration: float = 0.35
## 离开后延迟关门（s，规格⑩）
@export var close_delay: float = 0.8

@onready var _detection_shape: CollisionShape2D = $DetectionShape
@onready var _door_body: StaticBody2D = $DoorBody
@onready var _door_visual: Polygon2D = $DoorBody/DoorVisual

var is_open: bool = false
var _tween: Tween = null
var _close_countdown: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _auto_open_enabled: bool = true


func _ready() -> void:
	# 检测区 = 门体 + 两侧 trigger_margin（把 @export 接到实际行为）
	var door_shape := _door_body.get_node("CollisionShape2D").shape as RectangleShape2D
	var detect := _detection_shape.shape as RectangleShape2D
	detect.size = door_shape.size + Vector2(trigger_margin * 2.0, trigger_margin * 2.0)
	_base_scale = _door_visual.scale


func _process(delta: float) -> void:
	# 离开后延迟关门（_process 倒计时在 headless 与窗口播放下都可靠）
	if _close_countdown > 0.0:
		_close_countdown -= delta
		if _close_countdown <= 0.0:
			_do_close()


## 开门：播放开合动画并禁用门体碰撞（开启后不得阻挡玩家，规格⑤）
## 重入触发区时取消待关闭倒计时，避免门关在角色身上（评审 F1）。
func open() -> void:
	if not _auto_open_enabled:
		return
	_close_countdown = 0.0
	if is_open:
		return
	is_open = true
	_set_blocking(false)
	_animate_to(true)
	door_opened.emit()


## 外部流程可临时锁住自动门。禁用时立即结束已开始的开门，所有 open() 调用均无效。
func set_auto_open_enabled(enabled: bool) -> void:
	_auto_open_enabled = enabled
	if not enabled:
		_do_close()


func is_auto_open_enabled() -> bool:
	return _auto_open_enabled


## 关门：延迟 close_delay 后执行（规格⑤，规格⑩的 close_delay）
## close_delay=0 语义 = 立即关门（约束文档 §12-A2，评审 F1）。
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
	_set_blocking(true)
	_animate_to(false)
	door_closed.emit()


func _set_blocking(blocking: bool) -> void:
	var col := _door_body.get_node("CollisionShape2D")
	col.set_deferred("disabled", not blocking)


func _animate_to(opening: bool) -> void:
	# 用户定案 2026-09-05：同一扇门做开合（20×280 侧板，水平收边开/归位关），无正视门、无虚影。
	if _tween != null:
		_tween.kill()
	var target_scale := Vector2(0.06, 1.0) if opening else Vector2(1.0, 1.0)
	_tween = create_tween()
	_tween.tween_property(_door_visual, "scale", target_scale, open_duration) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
