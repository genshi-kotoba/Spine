class_name CorridorAssembly
extends Node2D
## CorridorAssembly — C3 固定走廊组装（用户 2026-09-05 定案：无限循环废弃，7680 固定走廊）
## 职责：
##  1) 构建 3 个固定坐标特异点视觉（奖状墙/书山/悬浮文本，白模 Polygon2D/Label 占位），位置由 Corridor.special_x 读取。
##  2) 旧内容清理：移除旧 _build_specials 的 Special0/1/2（段循环时代产物）。固定视觉（CorridorWall/CorridorFloorVisual）保留。
##  3) 频闪修复：Corridor 节点初始隐藏，corridor_entered 旗标后显示（三房阶段不渲染走廊视觉）。
## 无遮罩：不再注入视觉层/特异点层/氛围微压暗（用户删遮罩定案）。

## —— 节点引用 ——
@export var corridor_path: NodePath = NodePath("../Corridor")
@export var cleanup_legacy: bool = true
@export var enabled: bool = true

var _corridor: Node = null
var _special_nodes: Array[Node2D] = []


func _ready() -> void:
	add_to_group("corridor_assembly")
	if not enabled:
		return
	_resolve_refs()
	# 频闪根因修正：Corridor 整体初始隐藏（墙/地面/特异点全隐），进入走廊阶段再显示。
	if _corridor is CanvasItem:
		(_corridor as CanvasItem).visible = false
	if _corridor != null:
		_build_fixed_specials()
		_cleanup_legacy()


func _process(_delta: float) -> void:
	# corridor_entered 旗标后显示 Corridor 整体（固定视觉+特异点）。
	var entered: bool = GameState.get_process_flag("corridor_entered")
	if entered:
		if _corridor is CanvasItem and not (_corridor as CanvasItem).visible:
			(_corridor as CanvasItem).visible = true


func _resolve_refs() -> void:
	if corridor_path != NodePath():
		_corridor = get_node_or_null(corridor_path)
	if _corridor == null:
		_corridor = get_tree().get_first_node_in_group("c3corridor")


## 固定坐标三特异点：位置取 Corridor.special_x（duck-typed）；内容=奖状墙/书山/悬浮文本。
func _build_fixed_specials() -> void:
	var xs: Array = _corridor.get("special_x") as Array
	for i in range(mini(xs.size(), 3)):
		var x: float = float(xs[i])
		var node := _build_special_node(i, x)
		if node != null:
			_corridor.add_child(node)
			_special_nodes.append(node)


func _build_special_node(i: int, x: float) -> Node2D:
	var root := Node2D.new()
	root.name = "FixedSpecial%d" % i
	root.position = Vector2(x - (_corridor as Node2D).position.x, 0.0) if _corridor is Node2D else Vector2(x, 0.0)
	_build_judgment_zone(root)
	if i == 0:
		_build_certificate_wall(root)
	elif i == 1:
		_build_book_mountain(root)
	else:
		_build_floating_text(root)
	return root


## 判定区域标记（用户定案）：每个特异点地面标出屏息判定带 + 亮线 + 「屏息」标签。
func _build_judgment_zone(root: Node2D) -> void:
	var band := Polygon2D.new()
	band.name = "JudgeZone"
	band.z_index = 2
	band.color = Color(1.0, 0.8, 0.3, 0.16)
	band.polygon = PackedVector2Array([Vector2(-180, 845), Vector2(180, 845), Vector2(180, 1012), Vector2(-180, 1012)])
	root.add_child(band)
	var line := Polygon2D.new()
	line.name = "JudgeLine"
	line.z_index = 3
	line.color = Color(1.0, 0.85, 0.4, 0.6)
	line.polygon = PackedVector2Array([Vector2(-3, 845), Vector2(3, 845), Vector2(3, 1012), Vector2(-3, 1012)])
	root.add_child(line)
	var lab := Label.new()
	lab.name = "JudgeLabel"
	lab.z_index = 3
	lab.text = "屏息"
	lab.position = Vector2(-24, 800)
	lab.add_theme_font_size_override("font_size", 30)
	lab.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55, 0.95))
	root.add_child(lab)


## 特异点①：贴满墙奖状（白色/浅黄占位块，贴墙 y 带）。
func _build_certificate_wall(root: Node2D) -> void:
	for r in range(4):
		for c in range(3):
			var plate := Polygon2D.new()
			plate.name = "Cert"
			plate.position = Vector2(c * 60.0 - 60.0, r * 46.0 + 320.0)
			plate.color = Color(0.95, 0.90, 0.70, 1)
			plate.polygon = PackedVector2Array([Vector2(-24, -17), Vector2(24, -17), Vector2(24, 17), Vector2(-24, 17)])
			root.add_child(plate)


## 特异点②：地上书山（地面堆放书占位块，y≈988 地面带）。
func _build_book_mountain(root: Node2D) -> void:
	var colors: Array[Color] = [Color(0.45, 0.35, 0.28, 1), Color(0.30, 0.42, 0.35, 1), Color(0.38, 0.34, 0.50, 1)]
	for i in range(6):
		var book := Polygon2D.new()
		book.name = "Book"
		book.position = Vector2(i * 44.0 - 110.0, 988.0 - (i % 3) * 18.0)
		book.color = colors[i % colors.size()]
		book.polygon = PackedVector2Array([Vector2(-20, -7), Vector2(20, -7), Vector2(20, 7), Vector2(-20, 7)])
		root.add_child(book)


## 特异点③：墙上悬浮文本框（占位文本「提升一分，干掉千人」）。
func _build_floating_text(root: Node2D) -> void:
	var label := Label.new()
	label.name = "Text"
	label.text = "提升一分，干掉千人"
	label.position = Vector2(-130, 320)
	label.add_theme_font_size_override("font_size", 34)
	root.add_child(label)


## 旧内容清理：旧段循环时代的 Special0/1/2 移除（固定视觉 CorridorWall/CorridorFloorVisual 保留）。
func _cleanup_legacy() -> void:
	if not cleanup_legacy:
		return
	for i in range(3):
		var old := _corridor.get_node_or_null("Special%d" % i)
		if old != null:
			old.queue_free()


# ─── 公开接口（验证读回）───

func get_special_nodes() -> Array[Node2D]:
	return _special_nodes


func legacy_cleanup_done() -> bool:
	if _corridor == null:
		return false
	for i in range(3):
		var old := _corridor.get_node_or_null("Special%d" % i)
		if old != null and not old.is_queued_for_deletion():
			return false
	return true


func run_self_check() -> bool:
	var checks: Array[String] = []
	checks.append("corridor_ref" if _corridor != null else "corridor_ref_FAIL1")
	checks.append("specials3" if _special_nodes.size() >= 3 else "specials3_FAIL1(%d)" % _special_nodes.size())
	var zones: int = 0
	for s in _special_nodes:
		if s != null and is_instance_valid(s) and s.get_node_or_null("JudgeZone") != null and s.get_node_or_null("JudgeLabel") != null:
			zones += 1
	checks.append("zones3" if zones == 3 else "zones_FAIL(%d)" % zones)
	checks.append("corridor_hidden_initial" if (_corridor is CanvasItem and not (_corridor as CanvasItem).visible) else "corridor_hidden_initial_FAIL")
	checks.append("legacy_cleaned" if legacy_cleanup_done() else "legacy_cleaned_FAIL1")
	var failed := false
	for c in checks:
		if c.contains("FAIL"):
			failed = true
		print("[corridor_assembly] CHECK " + c)
	print("[corridor_assembly] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	return not failed
