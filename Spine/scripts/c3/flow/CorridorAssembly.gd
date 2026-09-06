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


## 特异点①：贴满墙真实奖状（3 张素材随机混排，约 20-30 张重叠）。
func _build_certificate_wall(root: Node2D) -> void:
	var textures: Array[Texture2D] = [
		preload("res://assets/corridor/certificates/certificate_1.png"),
		preload("res://assets/corridor/certificates/certificate_2.png"),
		preload("res://assets/corridor/certificates/certificate_3.png"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC3CE271
	# 真实奖状贴在特异点一上方，故意错位、旋转并重叠，形成杂乱墙面。
	for i in range(24):
		var cert := Sprite2D.new()
		cert.name = "Cert%02d" % i
		cert.texture = textures[rng.randi_range(0, textures.size() - 1)]
		cert.position = Vector2(rng.randf_range(-300.0, 300.0), rng.randf_range(150.0, 760.0))
		cert.rotation = rng.randf_range(-0.20, 0.20)
		var scale := rng.randf_range(0.16, 0.23)
		cert.scale = Vector2(scale, scale)
		cert.modulate = Color(1.0, 1.0, 1.0, rng.randf_range(0.86, 1.0))
		cert.z_index = 4 + i
		root.add_child(cert)


## 特异点②：从 corridor/books 素材动态堆叠高书山；目录为空时使用程序化书本回退。
func _build_book_mountain(root: Node2D) -> void:
	var textures := _load_book_textures()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC3B005
	var colors: Array[Color] = [
		Color("#7b302b"), Color("#31566b"), Color("#596436"),
		Color("#8a6538"), Color("#46385f"), Color("#263d3b")
	]
	# The rows run from the floor to roughly 3/4 of the wall. Lower rows are wider
	# and denser, producing a triangular book pile instead of a flat line of props.
	var row_count := 12
	for row in range(row_count):
		var t := float(row) / float(row_count - 1)
		var y := lerpf(948.0, 285.0, t)
		var half_width := lerpf(300.0, 72.0, t)
		var count := maxi(2, int(round(lerpf(11.0, 2.0, t))))
		var step := (half_width * 2.0) / float(count)
		for column in range(count):
			var book := _make_book("Book_%02d_%02d" % [row, column], textures, colors, rng, step)
			var x := -half_width + step * (float(column) + 0.5)
			# Small horizontal jitter lets covers overlap naturally while keeping the
			# silhouette within the intended mountain width.
			book.position = Vector2(x + rng.randf_range(-step * 0.22, step * 0.22), y + rng.randf_range(-13.0, 13.0))
			book.rotation = rng.randf_range(-0.16, 0.16) * (1.0 - t * 0.35)
			root.add_child(book)


func _load_book_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var dir_path := "res://assets/corridor/books"
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return textures
	var files := dir.get_files()
	for file_name in files:
		var ext := file_name.get_extension().to_lower()
		if ext not in ["png", "jpg", "jpeg", "webp"]:
			continue
		var texture := load(dir_path.path_join(file_name)) as Texture2D
		if texture != null:
			textures.append(texture)
	return textures


func _make_book(book_name: String, textures: Array[Texture2D], colors: Array[Color], rng: RandomNumberGenerator, step: float) -> Node2D:
	var book := Node2D.new()
	book.name = book_name
	var book_width := clampf(step * rng.randf_range(0.82, 1.18), 42.0, 126.0)
	var book_height := rng.randf_range(22.0, 42.0)
	if not textures.is_empty():
		var cover := Sprite2D.new()
		cover.name = "BookCover"
		cover.texture = textures[rng.randi_range(0, textures.size() - 1)]
		var source_size := cover.texture.get_size()
		var source_width := maxf(source_size.x, 1.0)
		var source_height := maxf(source_size.y, 1.0)
		cover.scale = Vector2(book_width / source_width, book_height / source_height)
		cover.modulate = Color(0.82, 0.82, 0.82, 1.0)
		book.add_child(cover)
		# A subtle dark spine keeps very thin/bright source covers readable in a pile.
		var spine := Polygon2D.new()
		spine.name = "BookSpine"
		spine.color = Color(0.08, 0.06, 0.05, 0.42)
		spine.polygon = PackedVector2Array([
			Vector2(-book_width * 0.5, -book_height * 0.5),
			Vector2(-book_width * 0.5 + 5.0, -book_height * 0.5),
			Vector2(-book_width * 0.5 + 5.0, book_height * 0.5),
			Vector2(-book_width * 0.5, book_height * 0.5)
		])
		book.add_child(spine)
	else:
		var fallback := Polygon2D.new()
		fallback.name = "BookFallback"
		fallback.color = colors[rng.randi_range(0, colors.size() - 1)]
		fallback.polygon = PackedVector2Array([
			Vector2(-book_width * 0.5, -book_height * 0.5),
			Vector2(book_width * 0.5, -book_height * 0.5),
			Vector2(book_width * 0.5, book_height * 0.5),
			Vector2(-book_width * 0.5, book_height * 0.5)
		])
		book.add_child(fallback)
		var spine := Polygon2D.new()
		spine.name = "BookSpine"
		spine.color = Color(0.10, 0.08, 0.07, 0.48)
		spine.polygon = PackedVector2Array([
			Vector2(-book_width * 0.5, -book_height * 0.5),
			Vector2(-book_width * 0.5 + 5.0, -book_height * 0.5),
			Vector2(-book_width * 0.5 + 5.0, book_height * 0.5),
			Vector2(-book_width * 0.5, book_height * 0.5)
		])
		book.add_child(spine)
	return book


## 特异点③：墙上故障文本框（多句循环式占位）。
func _build_floating_text(root: Node2D) -> void:
	# 第三个特异点的故障文字统一由 main 分支 GlitchDialogueBox 按流程触发，
	# 这里不再创建静态 Label，避免重复显示和跟随旧节点渲染。
	root.z_index = 100


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
	var book_count := 0
	var book_top := INF
	if _special_nodes.size() > 1:
		for child in _special_nodes[1].get_children():
			if child.name.begins_with("Book"):
				book_count += 1
				book_top = minf(book_top, (child as Node2D).position.y)
	checks.append("book_mountain" if book_count >= 40 and book_top <= 300.0 else "book_mountain_FAIL(%d,%.1f)" % [book_count, book_top])
	checks.append("corridor_hidden_initial" if (_corridor is CanvasItem and not (_corridor as CanvasItem).visible) else "corridor_hidden_initial_FAIL")
	checks.append("legacy_cleaned" if legacy_cleanup_done() else "legacy_cleaned_FAIL1")
	var failed := false
	for c in checks:
		if c.contains("FAIL"):
			failed = true
		print("[corridor_assembly] CHECK " + c)
	print("[corridor_assembly] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	return not failed
