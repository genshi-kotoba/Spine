class_name CorridorVisualLayer
extends Node2D
## CorridorVisualLayer — C3 走廊视觉层（spine-corridor-rework t4 / corridor_rework_spec §5）
## 只做渲染层，不挂游戏逻辑；与移动机制数据流解耦（速度经 set_move_speed 注入，不引用 Corridor 类型/文件）。
## 1. 墙壁纹理滚动（修 B2，D-R3）：decorate_segment() 给每段挂 WallVisual/GroundVisual Polygon2D，
##    材质 = corridor_scroll.gdshader（ShaderMaterial 运行时构建，不落 .tres 避免资产 UID 冲突）；
##    texture_offset 每帧累加写入 → 纹理随移动连续滚动（≈move_speed，MCP 可读回）。
## 2. 地面视觉（修 B3，D-R4）：每段 Ground 条（宽=segment_width、高=ground_height、y=ground_y=1008），
##    随段回跳无限循环；物理地面 StaticBody2D（CorridorFloor）由场景保持固定，本层不碰。
## 3. 景深氛围（修 B4，D-R2）：build_backdrop() 构建 2 层官方 Parallax2D（far 0.3 / mid 0.6 速度比），
##    autoscroll + repeat_size=(2048,0)；内容=程序化柱影/壁龛条带（白模 Polygon2D，零真实美术），
##    落在墙顶上方与地面下方的可见景深带（墙覆盖 y∈[wall_top_y,wall_bottom_y] 之外的区域）。
## 4. 氛围微压暗（§5.4）：ATMOSPHERE_* 配置常量 + apply_atmosphere_to()/set_atmosphere_enabled()/
##    set_atmosphere_intensity() 参数化开关；复用场景既有 DarknessMask，不新增全局节点类型。
## 组装提示（t6）：本层节点放在走廊锚点（stop_center_x≈4460）附近；decorate_segment 经
##   Corridor.decorate_segment 接线；若 Corridor 兼容分支（wall_material_path 指向本层 WallVisual）
##   同时在驱动 texture_offset，请置 scroll_driver=false 避免双倍滚动（两驱动二选一）。

## 滚动 shader 路径（规格 §5.1 原文写 assets/shaders/；本任务 inScope 限 corridor_visual，落地于此）。
const SHADER_PATH = "res://scripts/c3/corridor_visual/corridor_scroll.gdshader"

## —— 氛围微压暗配置（§5.4；参照 C3Flow LIGHT-D 写法：极暗色 + 低 alpha + 大半径）——
const ATMOSPHERE_COLOR = Color(0.02, 0.02, 0.05, 1.0)
const ATMOSPHERE_RADIUS_INNER = 260.0
const ATMOSPHERE_RADIUS_OUTER = 900.0
const ATMOSPHERE_SOFTNESS = 0.6

## 墙壁平铺纹理（沿用项目既有占位纹理 J5）。
@export var wall_texture_path: String = "res://assets/ui/corridor_wall.png"
## 段宽（与 CorridorSegment.segment_width 一致；duck-typed 段缺失时用此默认）。
@export var segment_width: float = 2048.0
## 墙面垂直范围（沿用旧 CorridorWall 几何 y∈[200,980]）。
@export var wall_top_y: float = 200.0
@export var wall_bottom_y: float = 980.0
## 地面条中心 y / 高度（沿用旧 CorridorFloorVisual y=1008 / h=40）。
@export var ground_y: float = 1008.0
@export var ground_height: float = 40.0
## 每平铺格世界像素（与多边形 uv 网格一致；沿用旧墙 ~64px/格观感）。
@export var tile_world_px: float = 64.0
## 移动速度（px/s；t6 从 Corridor.move_speed 注入；默认同 Corridor）。
@export var move_speed: float = 340.0
## 远景 / 中景速度比（D-R2 / V9：0.3 / 0.6）。
@export var far_speed_ratio: float = 0.3
@export var mid_speed_ratio: float = 0.6
## 远景层 repeat_size.x（官方坑位：≥ 视口宽 1920）。
@export var backdrop_repeat_x: float = 2048.0
## 滚动驱动开关：true=本层每帧写 texture_offset；false=交给外部（Corridor 兼容分支）驱动。
@export var scroll_driver: bool = true
## 总开关（false → 不滚动、不更新远景 autoscroll）。
@export var enabled: bool = true
## x 相位 uv（默认开，v1.1 B2 硬性验收必要）：corridor_wall.png 为纯水平条纹纹理
## （实测 row_var(沿x)=0.0，T(u,v)=f(v)），shader 只平移 u 则画面比特级不变；
## 本开关令 uv.y = p.x/tile_world_px（纹理行映射到世界 x 轴→墙上呈竖条纹），配合
## shader 把 texture_offset.x 同时写入 uv.y（T=f(x/64-Δ)），图案即以精确 move_speed 左移。
## false=恢复纯水平平铺（横向滚动不可见，仅用于对照）。
@export var x_phase_uv: bool = true
## 可选 DarknessMask 引用（t6 场景层接线；空 → 仅经 apply_atmosphere_to 生效）。
@export var atmosphere_mask_path: NodePath
## 氛围开关 / 压暗强度（alpha，0=无压暗）。
@export var atmosphere_enabled: bool = true
@export_range(0.0, 1.0) var atmosphere_alpha: float = 0.22

var _texture: Texture2D = null
var _shader: Shader = null
var _materials: Array[ShaderMaterial] = []
var _wall_nodes: Array[Node2D] = []
var _tex_offset: Vector2 = Vector2.ZERO
var _backdrop: Node2D = null
var _far_layer: Parallax2D = null
var _mid_layer: Parallax2D = null
var _atmosphere: Node = null


func _ready() -> void:
	add_to_group("corridor_visual")
	_load_resources()
	if atmosphere_mask_path != NodePath():
		_atmosphere = get_node_or_null(atmosphere_mask_path)
		if _atmosphere != null:
			apply_atmosphere_to(_atmosphere)


func _process(delta: float) -> void:
	_drive_scroll(delta)


# ─── 资源 / 驱动 ───

func _load_resources() -> void:
	if _texture == null and wall_texture_path != "":
		var tex: Texture2D = load(wall_texture_path) as Texture2D
		if tex != null:
			_texture = tex
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader


## 驱动一帧纹理滚动（_process 同逻辑；供自检/MCP 直接调用）。
func _drive_scroll(delta: float) -> void:
	if not enabled or not scroll_driver:
		return
	_tex_offset.x -= move_speed * delta
	for mat in _materials:
		mat.set_shader_parameter("texture_offset", _tex_offset)


func _make_scroll_material() -> ShaderMaterial:
	_load_resources()
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("tex", _texture)
	mat.set_shader_parameter("scroll_speed", 0.0)
	mat.set_shader_parameter("tex_scale", 1.0)
	mat.set_shader_parameter("tile_world_px", tile_world_px)
	mat.set_shader_parameter("texture_offset", _tex_offset)
	_materials.append(mat)
	return mat


## 由多边形顶点生成平铺 uv（每 tile_world_px 世界像素一格）。
## x_phase_uv=true：uv.y 取 p.x 相位（纹理行沿世界 x 轴展开），配合 shader 双轴偏移使
## 纯水平条纹纹理的水平滚动肉眼可辨（v1.1 B2 实测）；跨段相位仍连续（x=0 与 x=segment_width 同余）。
func _tile_uv(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if tile_world_px <= 0.0:
		return out
	for p in points:
		if x_phase_uv:
			out.append(Vector2(p.x / tile_world_px, p.x / tile_world_px))
		else:
			out.append(Vector2(p.x / tile_world_px, p.y / tile_world_px))
	return out


# ─── 段装饰（t6 经 Corridor.decorate_segment 接线；幂等可重复调用）───

## 给一段 CorridorSegment（duck-typed：读 segment_width）挂墙/地面视觉。
func decorate_segment(seg: Node2D) -> void:
	if seg == null:
		return
	_load_resources()
	_build_wall_visual(seg)
	_build_ground_visual(seg)


func _segment_width_of(seg: Node2D) -> float:
	if seg == null:
		return segment_width
	var w: Variant = seg.get("segment_width")
	if w == null:
		return segment_width
	var wf: float = float(w)
	return wf if wf > 0.0 else segment_width


func _build_wall_visual(seg: Node2D) -> void:
	var wall: Polygon2D = seg.get_node_or_null("WallVisual") as Polygon2D
	if wall == null:
		wall = Polygon2D.new()
		wall.name = "WallVisual"
		seg.add_child(wall)
	var w: float = _segment_width_of(seg)
	wall.polygon = PackedVector2Array([Vector2(0, wall_top_y), Vector2(w, wall_top_y), Vector2(w, wall_bottom_y), Vector2(0, wall_bottom_y)])
	wall.uv = _tile_uv(wall.polygon)
	wall.color = Color(0.62, 0.60, 0.58, 1)
	if _texture != null:
		wall.texture = _texture
	wall.material = _make_scroll_material()
	if not _wall_nodes.has(wall):
		_wall_nodes.append(wall)


func _build_ground_visual(seg: Node2D) -> void:
	var ground: Polygon2D = seg.get_node_or_null("GroundVisual") as Polygon2D
	if ground == null:
		ground = Polygon2D.new()
		ground.name = "GroundVisual"
		ground.z_index = 1
		seg.add_child(ground)
	var w: float = _segment_width_of(seg)
	var half: float = ground_height * 0.5
	ground.polygon = PackedVector2Array([Vector2(0, -half), Vector2(w, -half), Vector2(w, half), Vector2(0, half)])
	ground.uv = _tile_uv(ground.polygon)
	ground.position = Vector2(0, ground_y)
	ground.color = Color(0.5, 0.55, 0.5, 1)
	if _texture != null:
		ground.texture = _texture
	ground.material = _make_scroll_material()


# ─── 远景 / 中景（D-R2；官方 Parallax2D，不用已弃用的 ParallaxLayer）───

## 构建 2 层 Parallax2D 远景。官方坑位遵守：内容从 (0,0) 起锚；repeat_size.x ≥ 视口；
## 纯视觉不挂游戏逻辑；入树后不移动层（本层创建后仅由 autoscroll 驱动）。
func build_backdrop(parent: Node2D = null) -> void:
	if _backdrop != null:
		return
	var host: Node2D = parent if parent != null else self
	_backdrop = Node2D.new()
	_backdrop.name = "Backdrop"
	_backdrop.z_index = -20
	host.add_child(_backdrop)
	_far_layer = _make_parallax_layer("FarLayer", far_speed_ratio, -21)
	_mid_layer = _make_parallax_layer("MidLayer", mid_speed_ratio, -20)
	_backdrop.add_child(_far_layer)
	_backdrop.add_child(_mid_layer)
	_fill_far_content(_far_layer)
	_fill_mid_content(_mid_layer)
	_update_backdrop_scroll()


func _make_parallax_layer(layer_name: String, ratio: float, z: int) -> Parallax2D:
	var layer: Parallax2D = Parallax2D.new()
	layer.name = layer_name
	layer.z_index = z
	layer.scroll_scale = Vector2(ratio, 1.0)
	layer.repeat_size = Vector2(backdrop_repeat_x, 0.0)
	layer.autoscroll = Vector2(-move_speed * ratio, 0.0)
	return layer


## 远景内容：深色柱影节奏（墙顶上方可见带）+ 远处地面暗带（地面下方可见带）。
func _fill_far_content(layer: Parallax2D) -> void:
	var dark: Color = Color(0.08, 0.08, 0.11, 1.0)
	var x: float = 0.0
	while x < backdrop_repeat_x:
		var pillar := Polygon2D.new()
		pillar.name = "FarPillar"
		pillar.color = dark
		pillar.polygon = PackedVector2Array([Vector2(x, 40), Vector2(x + 36, 40), Vector2(x + 36, wall_top_y), Vector2(x, wall_top_y)])
		layer.add_child(pillar)
		x += 256.0
	var floor_band := Polygon2D.new()
	floor_band.name = "FarFloorBand"
	floor_band.color = dark
	floor_band.polygon = PackedVector2Array([Vector2(0, 1032), Vector2(backdrop_repeat_x, 1032), Vector2(backdrop_repeat_x, 1130), Vector2(0, 1130)])
	layer.add_child(floor_band)


## 中景内容：中等灰度柱/壁龛节奏 + 地面灰带。
func _fill_mid_content(layer: Parallax2D) -> void:
	var gray: Color = Color(0.30, 0.30, 0.34, 1.0)
	var x: float = 0.0
	while x < backdrop_repeat_x:
		var pillar := Polygon2D.new()
		pillar.name = "MidPillar"
		pillar.color = gray
		pillar.polygon = PackedVector2Array([Vector2(x, 90), Vector2(x + 60, 90), Vector2(x + 60, wall_top_y), Vector2(x, wall_top_y)])
		layer.add_child(pillar)
		x += 512.0
	var band := Polygon2D.new()
	band.name = "MidFloorBand"
	band.color = gray
	band.polygon = PackedVector2Array([Vector2(0, 1030), Vector2(backdrop_repeat_x, 1030), Vector2(backdrop_repeat_x, 1068), Vector2(0, 1068)])
	layer.add_child(band)


func _update_backdrop_scroll() -> void:
	var sx: float = -move_speed if enabled else 0.0
	if _far_layer != null:
		_far_layer.autoscroll = Vector2(sx * far_speed_ratio, 0.0)
	if _mid_layer != null:
		_mid_layer.autoscroll = Vector2(sx * mid_speed_ratio, 0.0)


# ─── 氛围（§5.4；复用既有 DarknessMask，duck-typed 写入配置）───

## 把微压暗配置写到任意 DarknessMask 兼容节点（t6 场景层接线；参数化开关）。
func apply_atmosphere_to(mask: Node) -> void:
	if mask == null:
		return
	var c: Color = ATMOSPHERE_COLOR
	c.a = atmosphere_alpha
	mask.set("darkness_color", c)
	mask.set("radius_inner", ATMOSPHERE_RADIUS_INNER)
	mask.set("radius_outer", ATMOSPHERE_RADIUS_OUTER)
	mask.set("softness", ATMOSPHERE_SOFTNESS)
	mask.set("enabled", atmosphere_enabled)


func set_atmosphere_enabled(on: bool) -> void:
	atmosphere_enabled = on
	if _atmosphere != null:
		apply_atmosphere_to(_atmosphere)


func set_atmosphere_intensity(alpha: float) -> void:
	atmosphere_alpha = clampf(alpha, 0.0, 1.0)
	if _atmosphere != null:
		apply_atmosphere_to(_atmosphere)


# ─── 公开接口（t6 组装 / t7 验证 / MCP 读回）───

func set_move_speed(px_s: float) -> void:
	move_speed = px_s
	_update_backdrop_scroll()


func get_move_speed() -> float:
	return move_speed


func set_scroll_enabled(on: bool) -> void:
	enabled = on
	_update_backdrop_scroll()


## 纹理滚动累计偏移（世界像素；随移动连续变化，MCP/自检读回）。
func get_texture_offset() -> Vector2:
	return _tex_offset


## 远景/中景两层 Parallax2D（供 t7 断言 autoscroll/repeat_size；V9）。
func get_backdrop_layers() -> Array:
	var out: Array = []
	if _far_layer != null:
		out.append(_far_layer)
	if _mid_layer != null:
		out.append(_mid_layer)
	return out


## 各段 WallVisual 节点（t6 可把 Corridor.wall_material_path 指向其中之一做兼容驱动）。
func get_wall_nodes() -> Array[Node2D]:
	return _wall_nodes


# ─── 自检（--self-check / 手动调用；t7 可复用）───

## 装饰 / 远景 / 滚动读回 / 氛围参数断言。
func run_self_check() -> bool:
	var checks: Array[String] = []
	var ok: bool = true
	_load_resources()
	checks.append("shader_loaded" if _shader != null else "shader_loaded_FAIL")

	var seg := Node2D.new()
	seg.name = "SelfCheckSegment"
	seg.set("segment_width", segment_width)
	add_child(seg)
	decorate_segment(seg)
	var wall: Polygon2D = seg.get_node_or_null("WallVisual") as Polygon2D
	var ground: Polygon2D = seg.get_node_or_null("GroundVisual") as Polygon2D
	checks.append("wall_built" if wall != null and wall.material is ShaderMaterial else "wall_built_FAIL")
	checks.append("ground_built" if ground != null else "ground_built_FAIL")
	if wall != null:
		var sm: ShaderMaterial = wall.material as ShaderMaterial
		checks.append("tex_set" if sm.get_shader_parameter("tex") != null else "tex_set_FAIL")
		checks.append("scroll_param" if sm.get_shader_parameter("texture_offset") is Vector2 else "scroll_param_FAIL")
		checks.append("wall_span" if absf(wall.polygon[1].x - segment_width) < 0.5 else "wall_span_FAIL")
	if ground != null:
		checks.append("ground_span" if absf(ground.polygon[1].x - segment_width) < 0.5 else "ground_span_FAIL")
		checks.append("ground_y" if absf(ground.position.y - ground_y) < 0.5 else "ground_y_FAIL")

	# 滚动读回：驱动两帧，texture_offset 连续左移且与材质参数一致。
	set_move_speed(340.0)
	var off0: Vector2 = get_texture_offset()
	_drive_scroll(0.5)
	var off1: Vector2 = get_texture_offset()
	_drive_scroll(0.5)
	var off2: Vector2 = get_texture_offset()
	checks.append("scroll_advances" if off2.x < off1.x and off1.x < off0.x else "scroll_advances_FAIL")
	if wall != null:
		var param: Vector2 = (wall.material as ShaderMaterial).get_shader_parameter("texture_offset") as Vector2
		checks.append("material_sync" if absf(param.x - off2.x) < 0.001 else "material_sync_FAIL")

	# 远景两层：速度比 0.3/0.6 与 repeat_size ≥ 1920（V9）。
	build_backdrop(self)
	var layers: Array = get_backdrop_layers()
	checks.append("backdrop_layers" if layers.size() == 2 else "backdrop_layers_FAIL")
	if layers.size() == 2:
		var far: Parallax2D = layers[0] as Parallax2D
		var mid: Parallax2D = layers[1] as Parallax2D
		checks.append("far_ratio" if absf(far.autoscroll.x - (-move_speed * far_speed_ratio)) < 0.5 else "far_ratio_FAIL")
		checks.append("mid_ratio" if absf(mid.autoscroll.x - (-move_speed * mid_speed_ratio)) < 0.5 else "mid_ratio_FAIL")
		checks.append("repeat_size" if far.repeat_size.x >= 1920.0 and mid.repeat_size.x >= 1920.0 else "repeat_size_FAIL")

	# 氛围参数写入（以真实 DarknessMask 为目标；Object.set 需要脚本属性存在）。
	var mask_probe: Node2D = (load("res://scripts/components/DarknessMask.gd") as Script).new() as Node2D
	apply_atmosphere_to(mask_probe)
	var probe_color: Color = mask_probe.get("darkness_color") as Color
	checks.append("atmosphere_params" if mask_probe.get("radius_inner") == ATMOSPHERE_RADIUS_INNER and mask_probe.get("enabled") == atmosphere_enabled and absf(probe_color.a - atmosphere_alpha) < 0.001 else "atmosphere_params_FAIL")
	mask_probe.free()

	ok = true
	for c in checks:
		if c.contains("FAIL"):
			ok = false
		print("[corridor_visual] CHECK " + c)
	print("[corridor_visual] SELF-CHECK " + ("PASS" if ok else "FAIL"))
	return ok
