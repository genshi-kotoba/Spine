extends SceneTree
## corridor_visual B2 截图验收脚本（windowed，v1.1 §5.5 硬性验收；t7 可复用）：
##   F:\Godot\godot\godot.exe --path F:\Godot\Spine\Spine --script res://scripts/c3/corridor_visual/corridor_visual_screenshot_check.gd
## 实验设计（一次运行，窗口化 ~3s 自动退出，exit 0=全过）：
##   A/B（t=0.5/1.0，滚动开，合成棋盘格纹理）：验证 shader+驱动管线本身（期望 diff>1%）。
##   C/D（t=1.5/2.0，滚动开，真实 corridor_wall.png）：验证真实资产是否可辨滚动（v1.1 硬性验收）。
##   E/F（t=2.2/2.7，滚动关，棋盘格）：对照（期望 diff<1%，证明差异来自滚动而非噪声）。
## 另打印 corridor_wall.png 的行/列方差各向异性（水平平移不变性诊断）。
## 帧 PNG 落 F:/Godot/corridor_probe/（仓库外）；不改任何场景/存档；无残留进程。

var _layer: Node2D = null
var _wall: Polygon2D = null
var _checker: ImageTexture = null
var _real_tex: Texture2D = null
var _t: float = 0.0
var _phase: int = 0
var _img_a: Image = null
var _img_b: Image = null
var _img_c: Image = null
var _img_d: Image = null
var _img_e: Image = null
var _img_f: Image = null


func _initialize() -> void:
	get_root().size = Vector2i(960, 620)
	_checker = _make_checker()
	_real_tex = load("res://assets/ui/corridor_wall.png")
	_print_texture_stats()
	var layer_script: Script = load("res://scripts/c3/corridor_visual/CorridorVisualLayer.gd")
	_layer = layer_script.new()
	_layer.name = "ProbeLayer"
	_layer.position = Vector2(0, -200)
	_layer.set_move_speed(340.0)
	_layer.scroll_driver = true
	_layer.enabled = true
	_layer.atmosphere_mask_path = NodePath()
	get_root().add_child(_layer)
	var seg: Node2D = Node2D.new()
	seg.name = "ProbeSeg"
	seg.set("segment_width", 2048.0)
	_layer.add_child(seg)
	_layer.decorate_segment(seg)
	_layer.build_backdrop(_layer)
	_wall = _layer.get_wall_nodes()[0]
	_set_tex(_checker)


func _process(delta: float) -> bool:
	_t += delta
	if _phase == 0 and _t >= 0.5:
		_img_a = _capture("A")
		_phase = 1
	elif _phase == 1 and _t >= 1.0:
		_img_b = _capture("B")
		_set_tex(_real_tex)
		_phase = 2
	elif _phase == 2 and _t >= 1.5:
		_img_c = _capture("C")
		_phase = 3
	elif _phase == 3 and _t >= 2.0:
		_img_d = _capture("D")
		_layer.set_scroll_enabled(false)
		_set_tex(_checker)
		_phase = 4
	elif _phase == 4 and _t >= 2.2:
		_img_e = _capture("E")
		_phase = 5
	elif _phase == 5 and _t >= 2.7:
		_img_f = _capture("F")
		_finish()
	return false


func _set_tex(t: Texture2D) -> void:
	if _wall != null and _wall.material is ShaderMaterial:
		(_wall.material as ShaderMaterial).set_shader_parameter("tex", t)


func _make_checker() -> ImageTexture:
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for by in range(0, 64, 8):
		for bx in range(0, 64, 8):
			var on: bool = ((bx / 8) + (by / 8)) % 2 == 0
			img.fill_rect(Rect2i(bx, by, 8, 8), Color(0.9, 0.9, 0.9, 1) if on else Color(0.1, 0.1, 0.1, 1))
	return ImageTexture.create_from_image(img)


func _capture(tag: String) -> Image:
	var img: Image = get_root().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png("F:/Godot/corridor_probe/frame_" + tag + ".png")
	print("[cvshot] captured " + tag + " t=" + str(_t) + " off=" + str(_layer.get_texture_offset()))
	return img


func _diff(a: Image, b: Image) -> int:
	var n: int = 0
	var w: int = mini(a.get_width(), b.get_width())
	var h: int = mini(a.get_height(), b.get_height())
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


func _print_texture_stats() -> void:
	var img: Image = _real_tex.get_image()
	# 各向异性：行内方差（沿 x 变化）vs 列内方差（沿 y 变化）。
	var row_var_acc: float = 0.0
	var col_var_acc: float = 0.0
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in range(h):
		var m: float = 0.0
		for x in range(w):
			m += img.get_pixel(x, y).get_luminance()
		m /= float(w)
		var v: float = 0.0
		for x in range(w):
			var d: float = img.get_pixel(x, y).get_luminance() - m
			v += d * d
		row_var_acc += v / float(w)
	for x in range(w):
		var m: float = 0.0
		for y in range(h):
			m += img.get_pixel(x, y).get_luminance()
		m /= float(h)
		var v: float = 0.0
		for y in range(h):
			var d: float = img.get_pixel(x, y).get_luminance() - m
			v += d * d
		col_var_acc += v / float(h)
	print("[cvshot] texture=" + str(img.get_size()) + " row_var(along x)=" + str(row_var_acc / float(h)) + " col_var(along y)=" + str(col_var_acc / float(w)))


func _finish() -> void:
	var total: int = int(_img_a.get_width() / 2) * int(_img_a.get_height() / 2)
	var ab: int = _diff(_img_a, _img_b)
	var cd: int = _diff(_img_c, _img_d)
	var ef: int = _diff(_img_e, _img_f)
	var pct_ab: float = float(ab) / float(total) * 100.0
	var pct_cd: float = float(cd) / float(total) * 100.0
	var pct_ef: float = float(ef) / float(total) * 100.0
	print("[cvshot] A->B diff=" + str(pct_ab) + "%  [0.5s checker, scroll ON]  expect >1%")
	print("[cvshot] C->D diff=" + str(pct_cd) + "%  [0.5s corridor_wall.png, scroll ON]  expect >1% (v1.1)")
	print("[cvshot] E->F diff=" + str(pct_ef) + "%  [0.5s checker, scroll OFF] expect <1%")
	var pass_ab: bool = pct_ab > 1.0
	var pass_cd: bool = pct_cd > 1.0
	var pass_ef: bool = pct_ef < 1.0
	print("[cvshot] SCREENSHOT-CHECK " + ("PASS" if pass_ab and pass_cd and pass_ef else "FAIL") + " (AB>1% & CD>1% & EF<1%)")
	quit(0 if pass_ab and pass_cd and pass_ef else 1)
