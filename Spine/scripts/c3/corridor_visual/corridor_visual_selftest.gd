extends SceneTree
## corridor_visual 自检入口（headless；t7 可复用）：
##   F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine --script res://scripts/c3/corridor_visual/corridor_visual_selftest.gd
## 加载 CorridorVisualLayer → 实例化 → run_self_check() → 退出（PASS=0 / FAIL=1）。
## 不依赖 c3_level.tscn 接线；验证 §5.5 的组件级断言（装饰/滚动读回/远景速度比/氛围参数）。


func _initialize() -> void:
	var script: Script = load("res://scripts/c3/corridor_visual/CorridorVisualLayer.gd")
	if script == null:
		print("[corridor_visual] SELFTEST FAIL (script load)")
		quit(1)
		return
	var layer: Node2D = script.new()
	root.add_child(layer)
	var ok: bool = layer.run_self_check()
	var offset: Vector2 = layer.get_texture_offset()
	var layers: Array = layer.get_backdrop_layers()
	print("[corridor_visual] final texture_offset=" + str(offset) + " backdrop_layers=" + str(layers.size()))
	layer.queue_free()
	quit(0 if ok else 1)
