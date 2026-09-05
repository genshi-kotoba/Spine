class_name CorridorSegment
extends Node2D
## 一段可无限循环的走廊视觉段：advance() 前进 + fposmod 回跳（Galawana snap-back 等价实现）。
## t3 实现注记（重要）：每段的锚点必须彼此错开——第 i 段锚 = 基锚(stop_center_x) + (i-1)*segment_width。
## 若所有段共用同一锚点，advance() 的 fposmod 会把各段塌缩到同一位置（数学上必然），无法平铺无缝；
## 段锚独立后，每段恒落在 (锚-W, 锚] 区间，segment_count 段恰好无缝平铺 [base-2W, base+W]。
## 段子节点由 t4/t5 装饰（墙/地面/特异点视觉随段移动）；段自身只管平移与回跳。

@export var segment_width: float = 2048.0   # 段宽，必须 ≥ 视口宽（1920）
@export var scroll_ratio: float = 1.0       # 深度比：墙/地面=1.0，近景>1，远景<1

var _anchor_x: float = 0.0

func setup(anchor_world_x: float) -> void:
	_anchor_x = anchor_world_x

func advance(travel_delta: float) -> void:
	position.x -= travel_delta * scroll_ratio
	var off: float = fposmod(_anchor_x - global_position.x, segment_width)
	global_position.x = _anchor_x - off

## 本段回跳锚点（世界 x）。
func get_anchor_x() -> float:
	return _anchor_x
