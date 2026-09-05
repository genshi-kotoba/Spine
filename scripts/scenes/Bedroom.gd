class_name Bedroom
extends FloorTemplate
## Bedroom — 卧室场景基座（godot_c3_prompt §2；c2/c4 复用见第六阶段）
## y 轴与源楼层完全一致；x 轴 = 源楼层的 1/4。
## 地图宽度单一来源：运行时读取 source_floor_scene 的 map_max_x 计算，不双写硬编码。


## 源楼层场景（默认 c3_floor；c2_bedroom/c4_bedroom 在编辑器覆盖为对应 floor）
@export var source_floor_scene: PackedScene = preload("res://scenes/c3_floor.tscn")


func _ready() -> void:
	# 实例化仅为读取配置（未入树不触发其 _ready），读后立即释放
	var src := source_floor_scene.instantiate()
	map_min_x = 0.0
	map_max_x = src.map_max_x / 4.0
	src.free()
	super._ready()
