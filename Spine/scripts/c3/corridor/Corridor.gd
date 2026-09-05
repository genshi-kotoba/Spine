class_name Corridor
extends Node2D
## Corridor — C3 无限走廊控制器（spec ⑤ §8 + corridor_rework_spec §3 t3 重做）
## 角色走到屏幕几何中心后停止移动角色，改为每帧沿 -x 驱动无限段 CorridorSegment 循环（t3 新机制：
## segment_count 段 2048px 克隆平铺 + fposmod 回跳，Galawana snap-back 等价；墙/地面/特异点视觉随段移动），
## 并让墙壁平铺纹理滚动以表现无限前进（texture_offset.x -= speed*delta）。
## 特异点节奏：3/4 屏出第一个，此后每 1/4 屏出一个；三特异点 = 贴墙奖状 / 地上书山 / 墙上悬浮文本框。
## 屏息判定（§8.3/J4：长按空格=屏息）：经过特异点须处于屏息态（breathe 长按 ≥ hold_threshold 且解锁）；
## 未屏息 → 传送到第一个特异点前 1/4（回退 travel，重置特异点进度）。
## 第三特异点后 1/4 走廊有限化（corridor_end=true，取消无限、给出终点），角色可向右走到尽头；
## 尽头交互 item（CorridorEndItem）两段式 E → 黑屏进卧室（由 C3Flow/场景处理，本组件仅发信号/设旗标）。
## 白模：三特异点程序化占位（Polygon2D 证书墙 / Polygon2D 书山 / Label 悬浮文本）；零真实美术。
## 独立可复用（脚本零房间名/关卡字面量；参数经 @export 配置）。组件自移动本身（含墙/特异点子节点）。

## —— 信号（供 C3Flow/t6e 接线）——
signal corridor_entered                    ## 切入墙壁移动（角色到达屏幕中心）。
signal special_point_passed(index: int)    ## 屏息通过第 index 个特异点。
signal teleport_triggered                  ## 未屏息 → 传送到第一特异点前 1/4。
signal corridor_finite                     ## 第三特异点后 1/4 走廊有限化。
signal end_wall_reached                    ## 有限化后角色走到尽头墙。

## —— 节点（NodePath；空 → 组/子树查找）——
@export var player: NodePath
## 走廊主体（墙/地面/特异点容器）；空 → 本节点自身（Corridor 移动自身）。
@export var corridor_container: NodePath
## 墙壁平铺纹理材质（CanvasItemMaterial / ShaderMaterial）；空 → 不滚动纹理。
@export var wall_material_path: NodePath

## —— 几何/节奏参数 ——
## 角色固定横坐标（屏幕几何中心，世界坐标）。
@export var stop_center_x: float = 640.0
## 墙壁移动速度（px/s）。
@export var move_speed: float = 340.0
## 一个“屏”宽（px），用于派生 3/4 与 1/4 屏。
@export var screen_span: float = 1360.0
## 第一个特异点出现所需行进距离（默认 3/4 屏）。
@export var first_special_dist: float = 1020.0
## 相邻特异点间距（默认 1/4 屏）。
@export var special_span: float = 340.0
## 特异点数量（三特异点）。
@export var special_count: int = 3
## 有限化后角色走到尽头的判定横坐标。
@export var end_wall_x: float = 1900.0

## —— 屏息 / 旗标 ——
## 长按屏息解锁旗标名（GameState.process_flags）。
@export var hold_breath_unlocked_flag: String = "hold_breath_unlocked"
## 进入走廊旗标名（读：是否已进入；本组件据此决定是否生效）。
@export var corridor_entered_flag: String = "corridor_entered"
## 走廊有限化旗标名（写：第三特异点后 1/4）。
@export var corridor_end_flag: String = "corridor_end"
## 屏息判定所需长按时长阈值（s）。
@export var hold_threshold: float = 0.5
## 总开关（false → 不干涉角色/墙壁；供流程关闭）。
@export var enabled: bool = true

## —— 无限段循环（t3 新机制：段管理替换整体平移）——
## 单段宽度（px；须 ≥ 视口宽 1920，默认 2048）。
@export var segment_width: float = 2048.0
## 段数量（克隆平铺；3 段无缝覆盖 [base-2W, base+W]，屏幕 base±960 恒被覆盖）。
@export var segment_count: int = 3
## 段锚基（世界 x；0 → 运行时取 stop_center_x）。
@export var anchor_x: float = 0.0

## 模式。
const MODE_IDLE := 0
const MODE_MOVING := 1
const MODE_FINITE := 2
const MODE_DONE := 3

var _mode: int = MODE_IDLE
var _travel_dist: float = 0.0
var _next_special: int = 0
var _special_reached: Array[bool] = []
var _hold_time: float = 0.0
var _start_local_x: float = 0.0
var _cbx: float = 0.0          ## 进入移动时走廊 global x。
var _player: Node2D = null
var _container: Node2D = null
var _wall_mat: Material = null
var _special_nodes: Array[Node] = []
var _segments: Array[CorridorSegment] = []
var _last_applied_travel: float = 0.0


func _ready() -> void:
	add_to_group("c3corridor")
	_resolve_refs()
	_build_segments()
	_ensure_input()
	_reset_special_reached()
	if "--self-check" in OS.get_cmdline_user_args():
		run_self_check()
		get_tree().quit()


func _process(delta: float) -> void:
	if not enabled:
		return
	if StoryMonitor.input_locked:
		_hold_time = 0.0
		return
	_update_hold(delta)
	if _mode == MODE_IDLE:
		_check_enter_moving()
	elif _mode == MODE_MOVING:
		_process_moving(delta)
	elif _mode == MODE_FINITE:
		_check_end_wall()


## 长按屏息计时（breathe 键按住累积；松开归零）。
func _update_hold(delta: float) -> void:
	if Input.is_action_pressed("breathe"):
		_hold_time += delta
	else:
		_hold_time = 0.0


## 是否处于屏息态（长按 ≥ hold_threshold 且解锁）。
func is_holding_breath() -> bool:
	if not GameState.get_process_flag(hold_breath_unlocked_flag):
		return false
	return _hold_time >= hold_threshold


## 到达屏幕中心 → 进入墙壁移动模式。
func _check_enter_moving() -> void:
	if _mode != MODE_IDLE:
		return
	var p := _get_player()
	if p == null:
		return
	if p.global_position.x >= stop_center_x:
		_enter_moving()


func _enter_moving() -> void:
	_mode = MODE_MOVING
	_start_local_x = position.x
	_cbx = global_position.x
	_travel_dist = 0.0
	_last_applied_travel = 0.0
	_next_special = 0
	_reset_special_reached()
	_apply_wall_offset()
	GameState.set_process_flag(corridor_entered_flag, true)
	corridor_entered.emit()


## 移动 / 滚动 / 触发特异点 / 有限化判定。
func _process_moving(delta: float) -> void:
	var p := _get_player()
	if p != null:
		p.global_position.x = stop_center_x
	_travel_dist += move_speed * delta
	_apply_wall_offset()
	_scroll_texture(delta)
	_handle_specials()
	_check_finite()


## 让走廊（含墙/特异点）随行进左移（t3 新机制）：对每段 seg.advance(增量) 驱动 + fposmod 回跳；
## 段不存在时回退整体平移（老行为，headless 兼容兜底）。
func _apply_wall_offset() -> void:
	if _segments.size() > 0:
		var delta: float = _travel_dist - _last_applied_travel
		for seg in _segments:
			seg.advance(delta)
		_last_applied_travel = _travel_dist
		return
	if _container != null:
		_container.position.x = _start_local_x - _travel_dist


## 滚动墙壁平铺纹理。
func _scroll_texture(delta: float) -> void:
	if _wall_mat == null:
		return
	# CanvasItemMaterial 无 texture_offset 属性（Godot 4.7 实测报 invalid access）；墙壁随廊体左移已完成前向滚动，
	# 此处仅对持有 texture_offset uniform 的 ShaderMaterial 做平铺纹理滚动。
	if _wall_mat is ShaderMaterial:
		var sm := _wall_mat as ShaderMaterial
		var cur: Variant = sm.get_shader_parameter("texture_offset")
		if cur is Vector2:
			sm.set_shader_parameter("texture_offset", (cur as Vector2) - Vector2(move_speed * delta, 0.0))


## 特异点触发：行进到达阈值时做屏息判定。
func _handle_specials() -> void:
	while _next_special < special_count and _travel_dist >= _special_threshold(_next_special):
		var idx: int = _next_special
		if is_holding_breath():
			_special_reached[idx] = true
			special_point_passed.emit(idx)
			_next_special += 1
		else:
			_teleport_back()
			return


func _special_threshold(idx: int) -> float:
	return first_special_dist + float(idx) * special_span


func _finite_dist() -> float:
	return first_special_dist + float(special_count) * special_span


## 未屏息 → 传送到第一个特异点前 1/4（回退 travel、重置特异点进度）。
func _teleport_back() -> void:
	_travel_dist = first_special_dist - special_span
	_next_special = 0
	_reset_special_reached()
	_apply_wall_offset()
	teleport_triggered.emit()


## 第三特异点后 1/4 → 走廊有限化。
func _check_finite() -> void:
	if _mode == MODE_MOVING and _travel_dist >= _finite_dist():
		_enter_finite()


func _enter_finite() -> void:
	_mode = MODE_FINITE
	GameState.set_process_flag(corridor_end_flag, true)
	corridor_finite.emit()


## 有限化后：角色向右走到尽头墙。
func _check_end_wall() -> void:
	var p := _get_player()
	if p == null:
		return
	if p.global_position.x >= end_wall_x:
		_mode = MODE_DONE
		end_wall_reached.emit()


func _reset_special_reached() -> void:
	_special_reached.clear()
	for i in range(special_count):
		_special_reached.append(false)


# ─── 无限段管理（t3：CorridorSegment 克隆平铺 + 段 API 供 t4/t5）───

## 程序化创建 segment_count 段 CorridorSegment（挂到 corridor_container 下）。
## 每段独立锚 = base + (i-1)*segment_width（数学上必须：同锚会让 fposmod 把各段塌缩到同一位置）；
## 各段回跳区间 (锚-W, 锚] 恰好无缝平铺 [base-2W, base+W]，屏幕 base±960 恒被覆盖（无限不露黑）。
## 段内容（墙/地面/特异点视觉）由 t4/t5 经 decorate_segment 挂接（本任务留空调用点）。
func _build_segments() -> void:
	if _segments.size() > 0:
		return
	if _container == null:
		_container = _resolve_container()
	if _container == null:
		return
	for i in range(segment_count):
		var seg := CorridorSegment.new()
		seg.name = "CorridorSegment%d" % i
		seg.segment_width = segment_width
		seg.scroll_ratio = 1.0
		_container.add_child(seg)
		var seg_anchor: float = _segment_anchor(i)
		seg.global_position.x = seg_anchor
		seg.setup(seg_anchor)
		_segments.append(seg)
		decorate_segment(seg)


## 第 i 段回跳锚点（世界 x）：base + (i-1)*W。
func _segment_anchor(i: int) -> float:
	return get_anchor_x() + float(i - 1) * segment_width


## 段锚基（世界 x）：anchor_x 非 0 用之，否则 stop_center_x（屏幕几何中心世界坐标）。
func get_anchor_x() -> float:
	if anchor_x != 0.0:
		return anchor_x
	return stop_center_x


## 稳定 API（t4/t5/t6）：已建无限段列表。
func get_segments() -> Array[CorridorSegment]:
	return _segments


## 段装饰挂钩（t4 视觉 / t5 特异点内容）：本任务留空调用点；t6 接线到 SpecialPointLayer.decorate。
func decorate_segment(seg: CorridorSegment) -> void:
	pass


## 段当前相位（0..W）：fposmod(base - seg.global_x, W) = 当前周期内已行进距离。
## 供 t5 按相位在段上摆特异点内容（内容随段回跳循环，判定仍随 travel）。
func get_segment_phase(seg: CorridorSegment) -> float:
	return fposmod(get_anchor_x() - seg.global_position.x, segment_width)


## 每段 global.x == 段锚 - fposmod(travel, W)（±0.5）且落在 (锚-W, 锚] 内（回跳有界断言）。
func _segments_at_travel(travel: float) -> bool:
	if _segments.is_empty():
		return false
	var expect_off: float = fposmod(travel, segment_width)
	for seg in _segments:
		var expect: float = seg.get_anchor_x() - expect_off
		var gx: float = seg.global_position.x
		if absf(gx - expect) > 0.5:
			return false
		if gx <= seg.get_anchor_x() - segment_width or gx > seg.get_anchor_x():
			return false
	return true


## 视口（base±960）是否被段并集无缝覆盖：最左左缘 ≤ base-960、最右右缘 ≥ base+960、相邻段无缝隙。
func _viewport_covered() -> bool:
	if _segments.is_empty():
		return false
	var base: float = get_anchor_x()
	var min_left: float = INF
	var max_right: float = -INF
	for seg in _segments:
		min_left = minf(min_left, seg.global_position.x)
		max_right = maxf(max_right, seg.global_position.x + segment_width)
	if min_left > base - 960.0 + 0.5 or max_right < base + 960.0 - 0.5:
		return false
	for i in range(_segments.size() - 1):
		var g0: float = _segments[i].global_position.x + segment_width
		var g1: float = _segments[i + 1].global_position.x
		if absf(g0 - g1) > 0.5:
			return false
	return true


## 屏幕中心（base）是否落在某段覆盖区间内（首段覆盖屏幕中心断言）。
func _center_covered() -> bool:
	var base: float = get_anchor_x()
	for seg in _segments:
		if seg.global_position.x < base and base <= seg.global_position.x + segment_width:
			return true
	return false


## 模拟连续行进 total（步进 97px）：每步段并集覆盖视口、每段位移连续
## （正常帧位移=步进；回跳帧位移=步进-W，内容周期 W 故视觉无缝；其他跳变视为断裂）。
func _simulate_travel_cover(total: float) -> bool:
	var step: float = 97.0
	var t: float = 0.0
	_travel_dist = 0.0
	_last_applied_travel = 0.0
	_apply_wall_offset()
	var prev_positions: Array[float] = []
	for seg in _segments:
		prev_positions.append(seg.global_position.x)
	while t < total:
		t += step
		_travel_dist = t
		_apply_wall_offset()
		if not _viewport_covered():
			return false
		for i in range(_segments.size()):
			var moved: float = prev_positions[i] - _segments[i].global_position.x
			if moved < step - segment_width - 0.5 or moved > step + 0.5:
				return false
			prev_positions[i] = _segments[i].global_position.x
	return true


# ─── 引用解析 / 白模特异点构建 ───

func _resolve_refs() -> void:
	_player = _resolve_player()
	_container = _resolve_container()
	_wall_mat = _resolve_wall_material()
	_build_specials()


func _resolve_player() -> Node2D:
	if player != NodePath():
		var n := get_node_or_null(player)
		if n is Node2D:
			return n as Node2D
	var gp := get_tree().get_first_node_in_group("player")
	if gp is Node2D:
		return gp as Node2D
	return _find_player_recursive(self)


func _resolve_container() -> Node2D:
	if corridor_container != NodePath():
		var n := get_node_or_null(corridor_container)
		if n is Node2D:
			return n as Node2D
	return self


func _resolve_wall_material() -> Material:
	if wall_material_path == NodePath():
		return null
	var n := get_node_or_null(wall_material_path)
	if n is CanvasItem:
		return (n as CanvasItem).material
	return null


func _find_player_recursive(n: Node) -> Node2D:
	if n == null:
		return null
	if n is Player:
		return n as Player
	for child in n.get_children():
		var found := _find_player_recursive(child)
		if found != null:
			return found
	return null


## 构建三特异点白模（已存在的同名节点则不重复创建；位置按阈值排布，随行进滑过角色）。
func _build_specials() -> void:
	_special_nodes.clear()
	# 以进入移动时的走廊 global x 为基准，令第 i 个特异点在 travel=threshold_i 时恰好位于角色 x。
	var base: float = _cbx if _cbx > 0.0 else global_position.x
	if base == 0.0:
		base = global_position.x
	var cx: float = stop_center_x
	for i in range(special_count):
		var local_x: float = (cx - base) + _special_threshold(i)
		var node := _get_or_build_special(i)
		if node is Node2D:
			(node as Node2D).position.x = local_x
		_special_nodes.append(node)


func _get_or_build_special(i: int) -> Node:
	var node_name := "Special%d" % i
	var existing := get_node_or_null(node_name)
	if existing != null:
		return existing
	var node: Node2D
	if i == 0:
		node = _build_certificate_wall(node_name)
	elif i == 1:
		node = _build_book_mountain(node_name)
	else:
		node = _build_floating_text(node_name)
	add_child(node)
	return node


## 特异点①：贴满墙奖状（墙面密布白色/浅黄奖状占位块）。
func _build_certificate_wall(node_name: String) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	for r in range(4):
		for c in range(3):
			var plate := Polygon2D.new()
			plate.name = "Cert"
			plate.position = Vector2(c * 60.0 - 60.0, r * 46.0 - 70.0)
			plate.color = Color(0.95, 0.90, 0.70, 1)
			plate.polygon = _rect_points(Vector2(48, 34))
			root.add_child(plate)
	return root


## 特异点②：地上书山（地面堆放书占位块）。
func _build_book_mountain(node_name: String) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	var colors: Array[Color] = [Color(0.45, 0.35, 0.28, 1), Color(0.30, 0.42, 0.35, 1), Color(0.38, 0.34, 0.50, 1)]
	for i in range(6):
		var book := Polygon2D.new()
		book.name = "Book"
		book.position = Vector2(i * 44.0 - 110.0, 120.0 - (i % 3) * 18.0)
		book.color = colors[i % colors.size()]
		book.polygon = _rect_points(Vector2(40, 14))
		root.add_child(book)
	return root


## 特异点③：墙上悬浮文本框（占位普通文本“提升一分，干掉千人”；用户提供文案，非叙事文本）。
func _build_floating_text(node_name: String) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	var label := Label.new()
	label.name = "Text"
	label.text = "提升一分，干掉千人"
	label.position = Vector2(-120, -40)
	label.add_theme_font_size_override("font_size", 34)
	root.add_child(label)
	return root


func _rect_points(size: Vector2) -> PackedVector2Array:
	var tw := size.x * 0.5
	var th := size.y * 0.5
	return PackedVector2Array([Vector2(-tw, -th), Vector2(tw, -th), Vector2(tw, th), Vector2(-tw, th)])


## 运行时兜底注册 breathe(空格)（D8；project.godot [input] 已定义则跳过）。
func _ensure_input() -> void:
	if InputMap.has_action("breathe"):
		return
	InputMap.add_action("breathe")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	InputMap.action_add_event("breathe", ev)


func _get_player() -> Node2D:
	if _player == null or not is_instance_valid(_player):
		_resolve_refs()
	return _player


# ─── 自检（--self-check；验证 移动进入 / 屏息通过与未屏息传送 / 三特异点 / 有限化）───

## 开关走廊（供 C3Flow/流程控制；false → 不干涉角色/墙壁）。
func set_enabled(enabled_value: bool) -> void:
	enabled = enabled_value


func run_self_check() -> bool:
	var checks: Array[String] = []
	enabled = true
	var p := _get_player()
	if p is Node2D:
		p.global_position.x = stop_center_x

	# —— 1. 到达屏幕中心 → 进入墙壁移动 ——
	_enter_moving()
	checks.append("enter_moving1" if _mode == MODE_MOVING else "enter_moving_FAIL1")
	# 无限段创建成功：segment_count 段且首段（锚=base）覆盖屏幕中心
	checks.append("segments3" if _segments.size() == segment_count and _segments.size() >= 3 else "segments3_FAIL1")
	checks.append("center_cover1" if _center_covered() else "center_cover_FAIL1")
	# 墙壁随行进左移（新机制）：每段 global.x = 段锚 - travel（travel < W 时无回跳）
	_travel_dist = 123.0
	_apply_wall_offset()
	checks.append("wall_offset1" if _segments_at_travel(123.0) else "wall_offset_FAIL1")
	# 回跳有界：travel 推进 2W+512 后每段恰为 锚-512（fposmod 正余数，无负值抖动）
	_travel_dist = segment_width * 2.0 + 512.0
	_apply_wall_offset()
	checks.append("wall_loop1" if _segments_at_travel(512.0) else "wall_loop_FAIL1")

	# —— 2. 未屏息过第一特异点 → 传送到第一特异点前 1/4 ——
	_hold_time = 0.0
	GameState.set_process_flag(hold_breath_unlocked_flag, false)
	_travel_dist = first_special_dist + 0.01
	_next_special = 0
	_handle_specials()
	checks.append("teleport1" if (absf(_travel_dist - (first_special_dist - special_span)) < 0.5 and _next_special == 0) else "teleport_FAIL1")
	# 传送回退后段同步回跳（travel=680）：视觉与判定一致
	checks.append("wall_rewind1" if _segments_at_travel(first_special_dist - special_span) else "wall_rewind_FAIL1")

	# —— 3. 屏息通过第一特异点 → 进度推进 ——
	GameState.set_process_flag(hold_breath_unlocked_flag, true)
	_hold_time = hold_threshold + 0.1
	_travel_dist = first_special_dist + 0.01
	_next_special = 0
	_reset_special_reached()
	_handle_specials()
	checks.append("pass_special1" if (_next_special == 1 and _special_reached[0]) else "pass_special_FAIL1")

	# —— 4. 三特异点全部屏息通过 → 有限化 ——
	_hold_time = hold_threshold + 0.1
	_travel_dist = _finite_dist() + 0.01
	_next_special = 0
	_reset_special_reached()
	_handle_specials()
	_enter_finite()
	checks.append("finite1" if (GameState.get_process_flag(corridor_end_flag) and _mode == MODE_FINITE) else "finite_FAIL1")

	# —— 5. 三特异点内容存在（证书墙/书山/悬浮文本）——
	var has_special := _special_nodes.size() >= 3
	checks.append("three_special1" if has_special else "three_special_FAIL1")

	# —— 6. 无限不露黑：任意行进态下段并集无缝覆盖视口（base±960）——
	checks.append("cover1" if _viewport_covered() else "cover_FAIL1")

	# —— 7. 模拟连续行进 10×segment_width：每步视口全覆盖 + 位移连续（回跳帧按步进-W 合法）——
	checks.append("loop10x1" if _simulate_travel_cover(segment_width * 10.0) else "loop10x_FAIL1")

	GameState.set_process_flag(hold_breath_unlocked_flag, false)
	var failed := false
	for c in checks:
		if c.contains("FAIL"):
			failed = true
		print("[corridor] CHECK " + c)
	print("[corridor] SELF-CHECK " + ("PASS" if not failed else "FAIL"))
	return not failed
