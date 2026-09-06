class_name SpecialPointLayer
extends Node2D
## SpecialPointLayer — C3 无限走廊特异点层（corridor_rework_spec §4 t5 契约）
##
## 职责（只做内容与参数，不做判定）：
##  1) 三特异点内容按规格构建：① 贴满墙奖状（4×3 白/浅黄 Polygon2D 块）② 地上书山（6 本三色书块）
##     ③ 墙上悬浮文本「提升一分，干掉千人」（Label font_size 34）。
##  2) 内容挂到无限墙段（CorridorSegment）上作为段子节点——内容随段 fposmod 回跳自动循环，
##     修复 B6 定位漂移（不再依赖 _cbx 单次赋值基准；装饰时按「段锚 + fposmod(tau, W)」换算本地坐标，
##     任意装饰时刻/任意 travel 下每个特异点恰落在一段上且世界位置正确）。
##  3) D-R6 屏息判定参数：本层导出 hold_threshold（默认 1.0s，用户定案），sync_hold_threshold=true 时同步到
##     Corridor.hold_threshold；判定入口仍为 Corridor.is_holding_breath()（长按 ≥ hold_threshold 且
##     hold_breath_unlocked）。BreathSystem.hold_burst_delay 独立、本层不触碰。
##
## 不写 GameState 旗标、不发射判定信号、不移动玩家——屏息通过/未屏息传送/有限化全部仍由
## Corridor 按 travel 阈值独占执行（本层内容为纯视觉，不影响判定）。

## —— 指向走廊控制器 ——
@export var corridor_path: NodePath = NodePath("../Corridor")

## 屏息判定阈值（用户定案：长按 1s；与 BreathSystem.hold_burst_delay 参数独立）。
@export var hold_threshold: float = 1.0

## 是否把本层 hold_threshold 同步到 Corridor.hold_threshold（true=以本层参数为准；
## t6 若直接改 Corridor 侧参数，置 false 避免覆盖）。
@export var sync_hold_threshold: bool = true

## 内容布局随机种子（0=与旧实现一致的固定布局，测试稳定；非 0=证书/书本位置 ±6px 确定性抖动）。
@export var seed_value: int = 0

## 总开关（false → 不装饰内容，纯空层）。
@export var enabled: bool = true

var _corridor: Node = null
var _specials: Array[Node2D] = []
var _decorated: int = 0


func _ready() -> void:
	add_to_group("special_point_layer")
	_resolve_corridor()
	_apply_hold_threshold()
	if enabled:
		decorate_all.call_deferred()


## 解析走廊控制器：显式路径 → c3corridor 组。
func _resolve_corridor() -> void:
	if _corridor != null:
		return
	if corridor_path != NodePath():
		_corridor = get_node_or_null(corridor_path)
	if _corridor == null:
		_corridor = get_tree().get_first_node_in_group("c3corridor")


## D-R6：屏息判定阈值同步到 Corridor（判定入口不变，仍为 Corridor.is_holding_breath）。
func _apply_hold_threshold() -> void:
	if not sync_hold_threshold or _corridor == null:
		return
	if "hold_threshold" in _corridor:
		_corridor.set("hold_threshold", hold_threshold)


## 段装饰入口（t6 可把 Corridor.decorate_segment 接本函数；本层 _ready 亦会自动 decorate_all）。
## 幂等：段上已存在同名特异点节点则跳过，重复装饰安全。
## 相位算法（任意装饰时刻/任意 travel 均正确）：特异点 i 阈值 tau = first_special_dist + i*special_span；
## 该段回跳锚为 anchor_j、段宽 W，本地坐标 L = (base - anchor_j) + fposmod(tau, W)，0 <= L < W 时挂该段。
## 段随 travel 回跳：g(t) = anchor_j - fposmod(t, W)，故特异点世界 x = base + fposmod(tau, W) - fposmod(t, W)，
## 在每个 travel ≡ tau (mod W) 的帧恰好位于 base（屏幕几何中心），内容随段循环、判定随 travel 触发（B6 修复）。
func decorate(seg: Node2D) -> void:
	if not enabled:
		return
	if _corridor == null:
		_resolve_corridor()
	if _corridor == null:
		return
	var base := _base_x()
	var w := _segment_width(seg)
	var anchor_j := _segment_anchor_x(seg)
	var count: int = int(_corridor.get("special_count"))
	var first: float = float(_corridor.get("first_special_dist"))
	var span: float = float(_corridor.get("special_span"))
	for i in range(count):
		var node_name := "Special%d" % i
		if seg.get_node_or_null(node_name) != null:
			continue
		var tau: float = first + float(i) * span
		var local_x: float = base - anchor_j + fposmod(tau, w)
		if local_x < 0.0 or local_x >= w:
			continue
		var node := _build_special(i, node_name)
		node.position.x = local_x
		seg.add_child(node)
		_specials.append(node)
		_decorated += 1


## 对 Corridor 全部已建段执行装饰（幂等；_ready 自动调用，t6/测试亦可手动调用）。
func decorate_all() -> void:
	if _corridor == null:
		_resolve_corridor()
	if _corridor == null or not _corridor.has_method("get_segments"):
		return
	var segs: Array = _corridor.call("get_segments")
	for seg in segs:
		if seg is Node2D:
			decorate(seg)


## 已装饰特异点节点数（验收读回）。
func get_decorated_count() -> int:
	return _decorated


## 已建特异点节点（顺序 0..special_count-1）。
func get_specials() -> Array[Node2D]:
	return _specials


## 特异点 i 当前世界 x（MCP 验收读回：travel == 阈值时 == 屏幕中心 base）。
func special_world_x(i: int) -> float:
	var node := _find_special(i)
	if node == null:
		return NAN
	return node.global_position.x


func _find_special(i: int) -> Node2D:
	var node_name := "Special%d" % i
	for s in _specials:
		if s != null and is_instance_valid(s) and s.name == node_name:
			return s
	return null


## 段锚基（世界 x）：Corridor.get_anchor_x()，回退 stop_center_x。
func _base_x() -> float:
	if _corridor != null and _corridor.has_method("get_anchor_x"):
		return float(_corridor.call("get_anchor_x"))
	if _corridor != null:
		return float(_corridor.get("stop_center_x"))
	return 0.0


func _segment_width(seg: Node2D) -> float:
	if "segment_width" in seg:
		return float(seg.get("segment_width"))
	if _corridor != null and "segment_width" in _corridor:
		return float(_corridor.get("segment_width"))
	return 2048.0


## 段回跳锚（世界 x）：CorridorSegment.get_anchor_x()，回退段当前 global x。
func _segment_anchor_x(seg: Node2D) -> float:
	var ax := 0.0
	if seg.has_method("get_anchor_x"):
		ax = float(seg.call("get_anchor_x"))
	elif "_anchor_x" in seg:
		ax = float(seg.get("_anchor_x"))
	if ax == 0.0:
		ax = seg.global_position.x
	return ax


# ─── 三特异点内容构建（结构与旧 _build_specials 一致，走查口径不变）───

func _build_special(i: int, node_name: String) -> Node2D:
	if i == 0:
		return _build_certificate_wall(node_name)
	if i == 1:
		return _build_book_mountain(node_name)
	return _build_floating_text(node_name)


## 特异点①：贴满墙奖状（4×3 白色/浅黄奖状块，Polygon2D）。
func _build_certificate_wall(node_name: String) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	for r in range(4):
		for c in range(3):
			var plate := Polygon2D.new()
			plate.name = "Cert%d" % (r * 3 + c)
			plate.position = Vector2(c * 60.0 - 60.0 + _jitter(0, r * 3 + c), r * 46.0 - 70.0 + _jitter(1, r * 3 + c))
			plate.color = Color(0.95, 0.90, 0.70, 1)
			plate.polygon = _rect_points(Vector2(48, 34))
			root.add_child(plate)
	return root


## 特异点②：地上书山（6 本书占位块，三色）。
func _build_book_mountain(node_name: String) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	var colors: Array[Color] = [Color(0.45, 0.35, 0.28, 1), Color(0.30, 0.42, 0.35, 1), Color(0.38, 0.34, 0.50, 1)]
	for i in range(6):
		var book := Polygon2D.new()
		book.name = "Book%d" % i
		book.position = Vector2(i * 44.0 - 110.0 + _jitter(2, i), 120.0 - (i % 3) * 18.0)
		book.color = colors[i % colors.size()]
		book.polygon = _rect_points(Vector2(40, 14))
		root.add_child(book)
	return root


## 特异点③：墙上故障文本（用户提供的多句压力式文案）。
func _build_floating_text(node_name: String) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	var lines := ["提升一分，干掉千人", "努力", "你一定可以", "你凭什么不行", "我就说你怎么了"]
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimSun", "PingFang SC", "Noto Sans CJK SC"])
	root.z_index = 100
	for i in range(lines.size()):
		var label := Label.new()
		label.name = "GlitchText%d" % i
		label.text = lines[i]
		label.position = Vector2(-150.0 + (i % 2) * 18.0, -40.0 + i * 48.0)
		label.rotation = deg_to_rad(-10.0 if i % 2 == 0 else 8.0)
		label.pivot_offset = Vector2(80.0, 18.0)
		label.z_index = 100
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.86, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.04, 0.98))
		label.add_theme_constant_override("outline_size", 6)
		root.add_child(label)
	return root


func _rect_points(size: Vector2) -> PackedVector2Array:
	var tw := size.x * 0.5
	var th := size.y * 0.5
	return PackedVector2Array([Vector2(-tw, -th), Vector2(tw, -th), Vector2(tw, th), Vector2(-tw, th)])


## 确定性抖动（seed_value=0 时固定布局，与旧实现一致）。
func _jitter(salt: int, cell: int) -> float:
	if seed_value == 0:
		return 0.0
	var s: int = (seed_value * 1103515245 + salt * 12345 + cell * 67890) & 0x7fffffff
	return float(s % 13) - 6.0


# ─── 自检（MCP/验收手动调用：结构走查 + 相位断言）───

## 走查三特异点结构 + 装饰相位正确性（不改 Corridor；判定自检仍由 Corridor.run_self_check 承担）。
func run_self_check() -> bool:
	var checks: Array[String] = []
	decorate_all()
	checks.append("decorated3" if _specials.size() >= 3 else "decorated_FAIL1")
	var cert_ok := _specials.size() > 0 and _count_children(_specials[0], "Cert") == 12
	checks.append("cert12" if cert_ok else "cert_FAIL1")
	var book_ok := _specials.size() > 1 and _count_children(_specials[1], "Book") == 6
	checks.append("book6" if book_ok else "book_FAIL1")
	var text_ok := false
	if _specials.size() > 2:
		var t := _specials[2].get_node_or_null("GlitchText0")
		if t is Label:
			var lab := t as Label
			text_ok = lab.text == "提升一分，干掉千人" and lab.get_theme_font_size("font_size") == 34
	checks.append("text34" if text_ok else "text_FAIL1")
	# 相位断言：特异点 i 世界 x 应恒等于 base + fposmod(tau_i, W) - fposmod(travel, W)（±0.5）。
	# 等价于：travel ≡ tau_i (mod W) 时恰在 base（屏幕几何中心）。
	if _corridor != null and _specials.size() >= 3:
		var first: float = float(_corridor.get("first_special_dist"))
		var span: float = float(_corridor.get("special_span"))
		var travel: float = float(_corridor.get("_travel_dist"))
		var w: float = _segment_width(_specials[0])
		var phase_ok := true
		for i in range(3):
			var node := _find_special(i)
			if node == null or node.get_parent() == null:
				phase_ok = false
				continue
			var tau: float = first + float(i) * span
			var expect: float = _base_x() + fposmod(tau, w) - fposmod(travel, w)
			if absf(node.global_position.x - expect) > 0.5:
				phase_ok = false
		checks.append("phase3" if phase_ok else "phase_FAIL1")
	var failed := false
	for c in checks:
		if c.contains("FAIL"):
			failed = true
		print("[special_layer] CHECK " + c)
	print("[special_layer] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	return not failed


func _count_children(node: Node2D, name_prefix: String) -> int:
	if node == null:
		return 0
	var n := 0
	for child in node.get_children():
		if child.name.begins_with(name_prefix):
			n += 1
	return n
