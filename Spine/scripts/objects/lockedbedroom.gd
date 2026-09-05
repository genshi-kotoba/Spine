class_name LockedBedroom
extends "res://scripts/objects/item.gd"
## LockedBedroom — 楼层卧室门交互区（godot_c3_prompt §1，c2/c4 复用见第六阶段）
## E 键 + 玩家在交互范围内 → 切换场景到 target_scene。
## 场景跳转非状态机变更：不改状态机、不写 GameState（LockedBedroomDoor 的 locked 状态保留）。
## 无独立贴图：交互区叠加在既有 LockedBedroomDoor 视觉（160×320 @ (1920,828)）上。


## 目标场景（c2/c4 实例在编辑器覆盖；默认保持 c3 的 bedroom.tscn）
@export var target_scene: String = "res://scenes/bedroom.tscn"


## 走基类 gate 链路（覆写 _try_touch 而非 touched）；范围外不触发
func _try_touch() -> bool:
	if not player_in_range:
		return false
	get_tree().change_scene_to_file(target_scene)
	return true
