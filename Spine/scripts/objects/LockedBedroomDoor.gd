class_name LockedBedroomDoor
extends InteractableObject
## LockedBedroomDoor — 客厅中央卧室门（用户定案 2026-09-05 修订）
## 属性与隔间自动门明确区分：默认锁着（GameState 存 locked）、纯背景（无碰撞）、
## 静态锁门——不触发任何开门动画、无检测区。
## 解锁玩法待用户设计（interact() 空实现）。


func _ready() -> void:
	# 状态集合仅含 locked（解锁玩法待用户设计）
	states = {"locked": {}}
	super._ready()


func interact() -> void:
	# 禁止解锁玩法：解锁待用户设计。此处刻意保持空实现。
	pass
