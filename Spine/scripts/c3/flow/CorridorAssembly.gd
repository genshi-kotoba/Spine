class_name CorridorAssembly
extends Node2D
## CorridorAssembly — t6 走廊三模块组装与联调（corridor_rework_spec §6）
## 职责（运行时程序化组装，D-R5 并行安全收口；不改三模块源码）：
##  1) 视觉层注入：CorridorVisualLayer（墙段滚动 shader 材质 + 地面段 + Parallax2D 远景/中景 + 氛围配置常量），
##     按 Corridor.move_speed 注入速度，对每段 decorate_segment（幂等）。
##  2) 特异点层注入：SpecialPointLayer（三特异点内容挂段随段回跳循环，修 B6；_ready 自动 decorate_all；
##     sync_hold_threshold=true 同步 D-R6 阈值到 Corridor，判定仍由 Corridor 独占）。
##  3) 旧内容二选一清理（§6.2）：移除旧 _build_specials 的 Special0/1/2、隐藏旧 CorridorWall/CorridorFloorVisual
##     （新段视觉接管，防双倍绘制/双倍特异点）。
##  4) 走廊微压暗氛围（§5.4）：玩家进入墙壁移动（_mode==MOVING）后一次性把 ATMOSPHERE 配置写到场景
##     DarknessMask（复用既有节点，不新增全局节点类型）；LIGHT 序列期间不触碰（掩码归 C3Flow）。
## 不写 GameState 旗标、不发射判定信号；C3Flow/Corridor 信号接线保持原样。

## 层脚本路径（运行时动态加载；不依赖全局 class cache，headless 稳定）。
const VISUAL_LAYER_PATH := "res://scripts/c3/corridor_visual/CorridorVisualLayer.gd"
const SPECIAL_LAYER_PATH := "res://scripts/c3/corridor_specials/SpecialPointLayer.gd"

## —— 节点引用（相对本节点；本节点挂在 C3Level 根下、Corridor 之后）——
@export var corridor_path: NodePath = NodePath("../Corridor")
@export var darkness_mask_path: NodePath = NodePath("../DarknessMask")
## 旧内容清理开关（§6.2 二选一；true=启用新层并移除旧特异点/隐藏旧墙视觉）。
@export var cleanup_legacy: bool = true
## 走廊微压暗氛围接线开关（§5.4/§6.4）。
@export var atmosphere_on_corridor: bool = true
## 总开关（false → 不注入任何层；供流程/调试关闭）。
@export var enabled: bool = true

var _corridor: Node = null
var _visual: Node2D = null
var _special_layer: Node = null
var _mask: Node = null
var _atmosphere_applied: bool = false


func _ready() -> void:
	add_to_group("corridor_assembly")
	if not enabled:
		return
	_resolve_refs()
	if _external_driver_active():
		# 测试/调试隔离：外部 runner（如 special_layer_selftest）会在入树前把 C3Flow._phase_debug_loaded
		# 置 true 以自行驱动走廊（自建层/自移除旧节点）。组装层让位，避免第二份特异点层先装饰段、
		# 使 runner 层的幂等装饰被跳过（同名节点冲突）。
		return
	if _corridor != null:
		_inject_visual_layer()
		_inject_special_layer()
		_cleanup_legacy()
	if "--self-check" in OS.get_cmdline_user_args():
		run_self_check()


## 外部测试驱动是否已接管（C3Flow 调试旗标在入树前被预置：--script runner 场景）。
## 注：--phase 命令行调试在 C3Flow._ready（本节点 _ready 之后）才置旗标，不影响组装注入。
func _external_driver_active() -> bool:
	var flow: Node = get_parent()
	if flow == null or not ("_phase_debug_loaded" in flow):
		return false
	return bool(flow.get("_phase_debug_loaded"))


func _process(_delta: float) -> void:
	# 走廊微压暗：进入墙壁移动后一次性应用（LIGHT 序列由 C3Flow 独占掩码，此处不抢先）。
	if _atmosphere_applied or not atmosphere_on_corridor:
		return
	if _corridor == null:
		return
	var mode: int = int(_corridor.get("_mode"))
	if mode != 1:
		return
	_atmosphere_applied = true
	# 走廊视觉层在进入移动模式时显示（频闪修复：三房阶段不渲染走廊视觉）。
	if _visual != null and not _visual.visible:
		_visual.visible = true
	if _mask == null and darkness_mask_path != NodePath():
		_mask = get_node_or_null(darkness_mask_path)
	if _mask != null and _visual != null and _visual.has_method("apply_atmosphere_to"):
		_visual.call("apply_atmosphere_to", _mask)


# ─── 引用解析 ───

func _resolve_refs() -> void:
	if corridor_path != NodePath():
		_corridor = get_node_or_null(corridor_path)
	if _corridor == null:
		_corridor = get_tree().get_first_node_in_group("c3corridor")
	if darkness_mask_path != NodePath():
		_mask = get_node_or_null(darkness_mask_path)


# ─── 层注入 ───

## 视觉层：创建 + 速度注入 + 段装饰 + 远景构建（节点挂本节点下，世界位置=走廊锚点基 4460）。
func _inject_visual_layer() -> void:
	if _visual != null:
		return
	# 动态加载（不依赖全局 class cache：headless/CI 免重扫）。
	var visual_script: Script = load(VISUAL_LAYER_PATH) as Script
	if visual_script == null:
		return
	var visual: Node2D = visual_script.new() as Node2D
	visual.name = "CorridorVisualLayer"
	add_child(visual)
	_visual = visual
	var speed: float = float(_corridor.get("move_speed"))
	visual.set_move_speed(speed)
	if _corridor.has_method("get_segments"):
		var segs: Array = _corridor.call("get_segments")
		for seg in segs:
			if seg is Node2D:
				visual.decorate_segment(seg)
	visual.build_backdrop(visual)
	# 频闪修复：走廊视觉层初始隐藏（段初始排布覆盖三房区域，开场即渲染会与白模视觉重叠频闪）；
	# 进入走廊移动模式（_process 检测 mode==1）后才显示。
	visual.visible = false


## 特异点层：创建（其 _ready 自动解析走廊 + 同步 hold_threshold + decorate_all.call_deferred）。
func _inject_special_layer() -> void:
	if _special_layer != null:
		return
	var layer_script: Script = load(SPECIAL_LAYER_PATH) as Script
	if layer_script == null:
		return
	var layer: Node = layer_script.new() as Node
	layer.name = "SpecialPointLayer"
	layer.set("corridor_path", NodePath("../Corridor"))
	add_child(layer)
	_special_layer = layer


## 旧内容清理（§6.2）：旧固定位置特异点移除、旧墙/旧地面视觉隐藏。
func _cleanup_legacy() -> void:
	if not cleanup_legacy:
		return
	for i in range(3):
		var old := _corridor.get_node_or_null("Special%d" % i)
		if old != null:
			old.queue_free()
	var old_wall := _corridor.get_node_or_null("CorridorWall")
	if old_wall is CanvasItem:
		(old_wall as CanvasItem).visible = false
	var old_floor := _corridor.get_node_or_null("CorridorFloorVisual")
	if old_floor is CanvasItem:
		(old_floor as CanvasItem).visible = false


# ─── 公开接口（t7 验证 / MCP 读回）───

func get_visual_layer() -> Node2D:
	return _visual


func get_special_layer() -> Node:
	return _special_layer


## 旧特异点是否已排队删除 / 旧墙视觉已隐藏（t7 断言二选一完成）。
func legacy_cleanup_done() -> bool:
	if _corridor == null:
		return false
	for i in range(3):
		var old := _corridor.get_node_or_null("Special%d" % i)
		if old != null and not old.is_queued_for_deletion():
			return false
	var old_wall := _corridor.get_node_or_null("CorridorWall")
	if old_wall is CanvasItem and (old_wall as CanvasItem).visible:
		return false
	var old_floor := _corridor.get_node_or_null("CorridorFloorVisual")
	if old_floor is CanvasItem and (old_floor as CanvasItem).visible:
		return false
	return true


# ─── 自检（--self-check 时打印；t7 可复用）───

## 组装断言：层注入 / 段装饰 / 远景两层 / 特异点装饰 / 旧内容清理（不改三模块，不改判定）。
func run_self_check() -> bool:
	var checks: Array[String] = []
	checks.append("corridor_ref" if _corridor != null else "corridor_ref_FAIL1")
	checks.append("visual_injected" if _visual != null else "visual_injected_FAIL1")
	checks.append("special_injected" if _special_layer != null else "special_injected_FAIL1")
	if _visual != null:
		var walls: Array = _visual.call("get_wall_nodes")
		checks.append("walls_decorated" if walls.size() >= 3 else "walls_decorated_FAIL1(%d)" % walls.size())
		var layers: Array = _visual.call("get_backdrop_layers")
		checks.append("backdrop2" if layers.size() == 2 else "backdrop2_FAIL1")
	if _special_layer != null:
		# 同步触发一次装饰（幂等；_ready 的 call_deferred 与此合并），保证断言立即成立。
		if _special_layer.has_method("decorate_all"):
			_special_layer.call("decorate_all")
		var decorated: int = int(_special_layer.call("get_decorated_count"))
		checks.append("specials_decorated" if decorated >= 3 else "specials_decorated_FAIL1(%d)" % decorated)
	checks.append("legacy_cleaned" if legacy_cleanup_done() else "legacy_cleaned_FAIL1")
	var failed := false
	for c in checks:
		if c.contains("FAIL"):
			failed = true
		print("[corridor_assembly] CHECK " + c)
	print("[corridor_assembly] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	return not failed
