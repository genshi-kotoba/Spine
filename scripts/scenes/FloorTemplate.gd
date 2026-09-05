class_name FloorTemplate
extends LevelScene
## FloorTemplate — 可复用楼层模板（规格③，规格⑨）
## 在 LevelScene 基础上补充：出生点应用、自动门触发接线、景深目标设置与相机取景偏移。
## 模板不含任何 C 层专属内容（房间名/数量/尺寸/出生点/闭锁门位置均由实例场景配置）。

## 出生点（实例场景配置；默认场景中心偏左）
@export var player_spawn_position: Vector2 = Vector2(320, 0)
## 相机取景偏移（横向楼层用于垂直取景，实现自由，不属新增设计；实例按需覆盖）
@export var camera_position_offset: Vector2 = Vector2(0, 0)


func _ready() -> void:
	super._ready()
	_apply_spawn()
	_apply_camera_offset()
	_connect_auto_doors()
	_setup_parallax()


## 应用出生点（规格⑥）
func _apply_spawn() -> void:
	_player.position = player_spawn_position


## 相机取景偏移：让整层进入视野（依赖 clamp 恒居中，见约束文档 §4.3）
func _apply_camera_offset() -> void:
	_camera.offset = camera_position_offset


## 自动门触发接线：扫描 AutoDoor 子节点，把玩家 body 触发接到 open/close（规格⑤）
func _connect_auto_doors() -> void:
	for door in find_children("*", "AutoDoor"):
		door.body_entered.connect(_on_door_body_entered.bind(door))
		door.body_exited.connect(_on_door_body_exited.bind(door))


func _on_door_body_entered(body: Node2D, door: AutoDoor) -> void:
	if body == _player:
		door.open()


func _on_door_body_exited(body: Node2D, door: AutoDoor) -> void:
	if body == _player:
		door.close()


## 景深目标：默认跟随角色（规格⑧，组件方式注入玩家引用）
func _setup_parallax() -> void:
	var parallax := get_node_or_null("DepthParallax")
	if parallax != null:
		parallax.target = _player
