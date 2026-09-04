class_name LockedBedroomDoor
extends InteractableObject
## LockedBedroomDoor — 客厅中央闭锁卧室门（规格⑦，安全约束）
## 闭锁语义 = 锁态（GameState 存 locked）+ 物理阻挡（场景中的 StaticBody2D）+ E 键无效果，三者在场景/基类中同时成立。
## 解锁玩法待用户设计（规格⑦ 明确禁止），故 interact() 为空实现——绝不切换状态、绝不开门体。


func _ready() -> void:
	# 状态集合仅含 locked（规格⑦；基类的 states 非 @export，需在子类填充）
	states = {"locked": {}}
	super._ready()


func interact() -> void:
	# 禁止解锁玩法：解锁待用户设计（规格⑦）。此处刻意保持空实现——
	# 不得切换状态、不得修改 current_state、不得开门体。
	pass
