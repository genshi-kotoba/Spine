class_name RoomTable
extends Node
## RoomTable — 可复用房间区间表（C3 前置需求⑥，§15）
## 数据源：room_id → {x_min, x_max}；提供 get_room_of(x) 返回含该 x 的 room_id。
## 不含任何房间名/关卡字面量，区间由场景配置（白模三房 [0,1280]/[1280,2560]/[2560,3840]），代码零硬编码。

## room_id → {x_min: float, x_max: float}
var rooms: Dictionary = {}


## 设置房间区间表（覆盖）。
func set_rooms(rooms_config: Dictionary) -> void:
	rooms = rooms_config


## 返回含 x 的 room_id；无匹配返回 ""。
func get_room_of(x: float) -> String:
	for room_id in rooms:
		var config: Dictionary = rooms[room_id]
		var x_min: float = config.get("x_min", -INF)
		var x_max: float = config.get("x_max", INF)
		if x >= x_min and x < x_max:
			return room_id
	return ""
