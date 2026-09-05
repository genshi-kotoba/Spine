# 走廊重做实施规格（docs/corridor_rework_spec.md）

> 作者：researcher（spine-corridor-rework 团队，t2 产出）
> 依据：docs/c3_gameplay_constraints.md §8/§9（唯一权威约束，冲突时以它为准）+ t1 调研报告（docs/corridor_reuse_report.md，本仓库）
> 读者：t3（移动机制，engineer）/ t4（视觉层，engineer2）/ t5（特异点与屏息判定层，engineer3）/ t6（组装联调，engineer）/ t7（验证）/ t8（评审）
> 原则：只重做渲染层 + 无限机制 + 视觉层；逻辑层（状态机/信号/屏息判定接口/有限化/调试入口）全部保留。

---

## 1. 重做范围与目标

### 1.1 用户口径（c3_gameplay_constraints.md §8.1 原文，不增删）
角色走到屏幕中间后不再移动角色、改为移动墙壁（需墙壁纹理表现移动）；走廊无限长；走过 3/4 屏后引入第一个特异点贴墙；此后每 1/4 屏出一个；三特异点=贴满墙奖状、地上书山、墙上悬浮文本框（占位普通文本「提升一分，干掉千人」）；每个特异点须屏息通过，未屏息则传送到第一个特异点前 1/4 位置。

### 1.2 重做范围
- 重做：墙/地面的无限滚动渲染（修 B1/B3）、墙壁纹理真实滚动（修 B2）、走廊视觉层（修 B4）、特异点随墙段的载体方式（修 B6 连带）、屏息判定参数化（B5 决议）。
- 保留（禁止改动行为）：Corridor.gd 的 MODE_IDLE/MOVING/FINITE/DONE 状态机、travel 阈值体系（first_special_dist=1020 / special_span=340 / special_count=3）、五信号（corridor_entered / special_point_passed / teleport_triggered / corridor_finite / end_wall_reached）、GameState 旗标写入（corridor_entered / corridor_end）、C3Flow 全部接线、--self-check / --phase 调试入口。
- 不碰：BreathSystem.gd / Bubble.gd / DarknessMask.gd / C3Flow.gd（本模块范围内不改其脚本；C3Flow 的走廊接线保持兼容）。

### 1.3 现状缺陷清单（t1 定位，逐条映射到本规格条目）
| # | 缺陷 | 修复条目 |
|---|---|---|
| B1 | CorridorWall Polygon2D 仅 2000px 宽、整体左移无循环 → 行进露黑、无限感断裂 | §3 段循环（t3） |
| B2 | wall_mat 为 CanvasItemMaterial（无 texture_offset）→ 墙纹理从不滚动，规格「需墙壁纹理表现移动」未达成 | §5.1 滚动 shader（t4） |
| B3 | 地面视觉随墙左移、物理地面固定 → 视觉地面移出屏幕 | §5.2 地面段（t4） |
| B4 | 走廊视觉只有 1 张贴图 + 纯色块，无景深/氛围/变化 | §5 视觉层（t4） |
| B5 | 屏息判定 0.5s 与缺氧触发 0.5s 同阈值（J4 待确认）→ 过点必缺氧 | §4.3 D-R6 决议（t5） |
| B6 | 特异点定位依赖 _cbx 单次赋值基准，重进/hot-reload 漂移 | §4.2 挂段（t5） |

---

## 2. 方案决策（D-R 系列，本规格定案）

- **D-R1 无限机制 = 方案 B（Galawana 移植）**：3 段 CorridorSegment（段宽 segment_width=2048 ≥ 视口 1920）克隆平铺 + fmod 回跳。依据 t1：官方 Parallax 层是纯渲染层不宜挂特异点等游戏逻辑；B 与现有 Corridor.gd 的 position 运算同构，改动面最小；无弃用 API。来源：Galawana 教程（已等价重写，非逐字复制）+ Godot 官方 mirroring 原理（2 实例 + snap-back）。
- **D-R2 远景层 = 官方 Parallax2D（repeat_size + autoscroll）**：纯视觉层一行配置，不挂游戏逻辑。Godot 4.3+ 原生，4.7 可用；ParallaxLayer/ParallaxBackground 官方已弃用，不使用。
- **D-R3 墙纹理滚动 = ShaderMaterial + canvas_item UV 偏移 shader**（修 B2 的唯一正解；Sprite2D region 平移为备选）。CanvasItemMaterial 在 Godot 4 无 texture_offset，禁止继续沿用该材质做滚动。
- **D-R4 物理地面 = 保持现有固定 StaticBody2D CorridorFloor**（角色 x 被钉死，地面无需移动；不动物理即零风险）。视觉地面改由 CorridorSegment 地面段承担（修 B3）。
- **D-R5 模块并行安全 = 运行时程序化构建**：t3/t4/t5 均不改 c3_level.tscn（场景统一由 t6 组装接线）；延续现有 Corridor.gd 运行时构建（_build_specials）模式。
- **D-R6 屏息判定口径（B5/J4 决议）**：屏息判定与缺氧触发**参数独立、默认同值 0.5s**（保持用户原话张力：长按屏息→气泡破裂缺氧 与 过特异点 同框，c3_gameplay_constraints.md §8.3 原口径）。Corridor 判定用 hold_threshold（长按 ≥ 阈值且 hold_breath_unlocked）；BreathSystem 缺氧用 hold_burst_delay（不动其脚本，仅参数）。若 t5 实测体验不可接受（三点全程缺氧压暗），将 hold_threshold 调至 0.35s（过点后立即松手呼吸）——属参数调优，不属设计变更，无需重开评审；默认值仍 0.5s。

---

## 3. t3 契约：走廊移动机制（engineer）

### 3.1 交付物
- 新增 `scripts/c3/corridor/CorridorSegment.gd`（class_name CorridorSegment，段宽 2048 可导出）。
- 改造 `scripts/c3/corridor/Corridor.gd`：段管理 + travel 驱动替换整体平移；特异点相关逻辑**保留函数签名与行为**，仅将其挂接点改为段 API（§4.2，t5 会替换内容构建）。
- 改前先留 `scripts/c3/corridor/Corridor.gd.bak`。

### 3.2 CorridorSegment.gd 接口
```gdscript
class_name CorridorSegment
extends Node2D
## 一段可无限循环的走廊视觉段：advance() 前进 + fposmod 回跳（Galawana snap-back 等价实现）

@export var segment_width: float = 2048.0   # 段宽，必须 ≥ 视口宽（1920）
@export var scroll_ratio: float = 1.0       # 深度比：墙/地面=1.0，近景>1，远景<1

var _anchor_x: float = 0.0

func setup(anchor_world_x: float) -> void:
    _anchor_x = anchor_world_x

func advance(travel_delta: float) -> void:
    position.x -= travel_delta * scroll_ratio
    var off: float = fposmod(_anchor_x - global_position.x, segment_width)
    global_position.x = _anchor_x - off
```
规则：
- 锚点 anchor_world_x = stop_center_x（4460，屏幕几何中心世界坐标）。
- fposmod 取正余数（禁止 fmod，负值会抖动）。
- 段子节点由 t4/t5 装饰；段自身只管平移与回跳。

### 3.3 Corridor.gd 改造点（行为不变清单优先）
**本任务明确修复 B1（缺陷编号见 t1 报告：墙 Polygon2D 仅 2000px 宽且整体左移无循环 → 行进超 2 屏后整面墙移出屏幕露黑、无限感断裂）。修复契约=用段循环替换整体平移：任何行进距离下视口 [anchor_x-960, anchor_x+960] 内必须至少存在一段墙视觉（无露黑、无接缝跳变）；实现不满足此条即本任务 FAIL。**
- 保留全部导出参数（player / corridor_container / wall_material_path / stop_center_x / move_speed / screen_span / first_special_dist / special_span / special_count / end_wall_x / hold_breath_unlocked_flag / corridor_entered_flag / corridor_end_flag / hold_threshold / enabled）。
- 保留五信号与发射时机；保留 _update_hold / is_holding_breath / _check_enter_moving / _handle_specials 阈值判定 / _teleport_back / _check_finite / _enter_finite / _check_end_wall / set_enabled / run_self_check 的**语义**（自检内容按新机制更新断言，见 §7）。
- 变更点：
  1. 新增 `@export var segment_width: float = 2048.0`、`@export var segment_count: int = 3`、`@export var anchor_x: float = 0.0`（0=运行时取 stop_center_x）。
  2. `_ready` 增 `_build_segments()`：程序化创建 segment_count 段 CorridorSegment（均挂到 corridor_container 下），初始排布覆盖 [anchor_x - segment_width, anchor_x + (segment_count-1)*segment_width]（保证屏幕上至少 1 段、回跳后无缝）；墙/地面视觉与特异点内容由 t4/t5 通过装饰 API 挂到段上。
  3. `_apply_wall_offset()` 改为：对每段 `seg.advance(_travel_dist - _last_applied_travel)` 增量驱动（新机制），并保留对 corridor_container 兜底平移（当 segments 为空时回退老行为，保证 headless 兼容）。
  4. 新增稳定 API 供 t4/t5（不改变既有信号）：`func get_segments() -> Array[CorridorSegment]`、`func decorate_segment(seg: CorridorSegment) -> void`（**本任务只留调用点/空实现**，内容由 t5 在 SpecialPointLayer 侧实现，t6 接线时按 §6 组装）、`func get_anchor_x() -> float`。
  5. `_build_specials` / `_get_or_build_special` / `_build_certificate_wall` 等：**本任务保留原实现不动**（t5 迁移到 SpecialPointLayer 后由 t6 决定删除时机；过渡期两套并存但只启用一套，避免双倍特异点）。

### 3.4 t3 验收
- **B1 修复验收（硬性）**：travel 从 0 推进至 10×segment_width（≥20480px），全程任意帧视口范围内至少一段可见；连续 60s（move_speed=340）无露黑、无接缝跳变。
- headless 运行 c3_level.tscn -- --phase=7：无脚本错误；Corridor 创建 3 段且首段覆盖屏幕中心。
- 模拟 travel 推进 10×segment_width：任意时刻存在至少一段与视口 [anchor_x-960, anchor_x+960] 相交（无限不露黑）。
- advance() 回跳断言：连续 1000 帧单调左移后，每段 global_position.x 与 anchor 的偏差始终在 (-segment_width, segment_width) 内。
- 既有自检（enter_moving / wall_offset / teleport / pass_special / finite / three_special）保持 PASS（断言适配新机制后）。

---

## 4. t5 契约：特异点与屏息判定层（engineer3）

### 4.1 交付物
- 新增 `scripts/c3/corridor/SpecialPointLayer.gd`（class_name SpecialPointLayer）：三特异点内容构建 + 挂段 + 屏息判定参数 + 装饰接口实现。
- 不改 Corridor.gd（判定逻辑经 Corridor 既有 API 读回）；不改 c3_level.tscn。

### 4.2 SpecialPointLayer.gd 契约
```gdscript
class_name SpecialPointLayer
extends Node2D
## 三特异点层：内容随墙段移动；屏息判定与传送仍由 Corridor 触发（本层只负责内容与装饰）

@export var corridor_path: NodePath                 # 指向 Corridor 节点
@export var hold_threshold: float = 0.5            # 屏息判定阈值（D-R6，与 BreathSystem 参数独立）

var _corridor: Node = null
var _specials: Array[Node2D] = []

func _ready() -> void:
    _corridor = get_node_or_null(corridor_path)

## t6 接线：Corridor.decorate_segment 调用本函数（每段一次）
func decorate(seg: Node2D) -> void:
    pass  # 按段距锚点的相位在段上放置奖状/书/文本占位（随机种子可导出）
```
规则：
- 三特异点内容规格不变：① 贴满墙奖状（4×3 白色/浅黄奖状块，Polygon2D）② 地上书山（6 本书占位块，三色）③ 墙上悬浮 Label「提升一分，干掉千人」（font_size 34）。
- 载体方式（修 B6）：特异点内容挂到**墙段**上（作为段子节点，随段 fmod 回跳自动循环）；触发判定仍由 Corridor 按 travel 阈值执行——即「内容跟着段走、判定跟着 travel 走」，二者解耦后 B6 的定位漂移自然消失。
- 若保留 Corridor 内旧 _build_specials 双套并存，本层与旧实现**不得同时启用**（t6 组装时二选一，默认启用本层）。
- 屏息判定（B5/D-R6）：Corridor.is_holding_breath()（长按 ≥ hold_threshold 且 hold_breath_unlocked）继续作为唯一判定入口；hold_threshold 参数可由 t6 在场景中覆写（默认 0.5s）；BreathSystem.hold_burst_delay 不动（仍 0.5s，缺氧触发）。

### 4.3 t5 验收
- 三特异点内容与旧规格 §8.3 一致（走查节点结构）。
- 特异点内容随段回跳循环可见（travel 推进 2×segment_width 后三特异点仍按阈值节奏出现）。
- 屏息通过/未屏息传送行为与旧实现一致（复用 Corridor 自检断言）。
- hold_threshold 覆写 0.35s 后：长按 0.35s 即判屏息（判定阈值生效）；BreathSystem 缺氧仍在 0.5s 触发（参数独立验证）。

---

## 5. t4 契约：走廊视觉层（engineer2）

### 5.1 墙壁纹理滚动（修 B2，D-R3）
**本任务明确修复 B2（缺陷编号见 t1 报告：wall_mat 为 CanvasItemMaterial、Godot 4 无 texture_offset → 墙纹理从不滚动，规格「需墙壁纹理表现移动」未达成）。修复契约=墙段视觉改用 ShaderMaterial + corridor_scroll.gdshader（UV 随时间左移），scroll_speed 由 Corridor 每帧写入 move_speed；0.5s 间隔双帧截图墙面纹理位移必须 > 0；实现不满足此条即本任务 FAIL。**
- 新增 `assets/shaders/corridor_scroll.gdshader`（canvas_item）：
```gdshader
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tex : source_color;
uniform float scroll_speed = 0.0;          // px/s，由 Corridor 每帧写入
uniform float tex_scale : hint_range(0.01, 100.0) = 1.0;  // 世界像素→UV 比例

void fragment() {
    vec2 uv = UV * vec2(tex_scale, 1.0);
    uv.x -= TIME * scroll_speed / tex_scale;
    COLOR = texture(tex, uv);
}
```
- 运行时构建 ShaderMaterial（不落 .tres，避免资产 UID 冲突）：加载 corridor_scroll.gdshader + 设置 tex=corridor_wall.png（沿用 assets/ui/corridor_wall.png，J5 占位纹理不变）、scroll_speed=move_speed，赋给墙段视觉节点。
- 兼容路径：Corridor._scroll_texture 的既有 texture_offset 分支保留（ShaderMaterial 才滚动；CanvasItemMaterial 直接跳过——不再作为走廊墙材质使用）。
- 备选（若 shader 有问题）：Sprite2D + region_enabled + region_rect 逐帧平移。

### 5.2 地面段（修 B3，D-R4）
- 视觉地面并入 CorridorSegment 地面段（scroll_ratio=1.0，与墙同速）：每段一个地面条 Polygon2D（宽=segment_width，高 40，y=1008 对齐既有站立面，色/贴图沿用 corridor_wall.png 平铺）。
- 物理地面保持现有固定 CorridorFloor StaticBody2D 不动。

### 5.3 远景/中景层（修 B4，D-R2）
- 运行时构建 2 层 Parallax2D：
  - 远景 far：autoscroll=(-move_speed*0.3, 0)，repeat_size=(2048,0)，内容=深色程序化矩形条带（Polygon2D 序列，如门框/柱影节奏），从 (0,0) 起锚。
  - 中景 mid：autoscroll=(-move_speed*0.6, 0)，repeat_size=(2048,0)，内容=中等灰度柱/壁龛节奏。
- 官方坑位遵守：内容从 (0,0) 起锚、repeat_size ≥ 视口、纯视觉层不挂游戏逻辑、入树后不改层 position。

### 5.4 氛围（可选加分，复用现有组件）
- 走廊微压暗：复用场景既有 DarknessMask 低强度配置（darkness_color 极暗、alpha 低、radius 极大；参照 C3Flow LIGHT-D 写法），由 t6 在场景层接线；t4 提供配置常量即可，不新增全局节点类型。

### 5.5 t4 验收
- **B2 修复验收（硬性）**：墙纹理肉眼可辨滚动（0.5s 间隔双帧截图，墙面纹理位移 > 0）；速度≈move_speed。
- 行进 60s 无露黑/无接缝跳变（三段回跳无缝）。
- 远景/中景以 0.3/0.6 速度比滚动（读 Parallax2D 属性断言）。
- 地面视觉始终覆盖屏幕（与物理地面 y=1008 对齐）。

---

## 6. t6 组装接线清单（engineer，依赖 t3/t4/t5 完成后执行）

1. c3_level.tscn：确认 Corridor 新导出参数（segment_width/segment_count/anchor_x）按默认值生效；必要时挂 SpecialPointLayer 节点并接线 corridor_path；材质/远景层以运行时构建为主，场景改动最小化（改场景前留 .bak）。
2. 启用 SpecialPointLayer（移除/停用 Corridor 内旧 _build_specials 调用，二选一）。
3. 接线 Corridor.decorate_segment → SpecialPointLayer.decorate。
4. 视觉层注入：墙段材质（滚动 shader）+ 地面段 + Parallax2D 远景/中景 + 氛围 DarknessMask 配置。
5. 更新 Corridor.run_self_check 断言（适配新机制；自检失败点见 §7）。
6. 全量回归：--phase=1..9 自检 + 物理断言（沿用 docs/c3_gameplay_constraints.md §12 命令清单）。

---

## 7. 验收标准汇总（t7 验证直接使用）

| # | 标准 | 验证方式 | 对应缺陷 |
|---|---|---|---|
| V1 | 玩家到屏幕中心后停止移动、墙/地面/特异点向左滚动 | 窗口运行读回玩家 x 恒定 4460 + 截图 | B1 |
| V2 | 墙纹理肉眼可辨滚动（速度≈move_speed） | 间隔 0.5s 双帧截图对比 | B2 |
| V3 | 走廊无限：连续行进 60s（或 travel=10×segment_width）无露黑、无接缝跳变 | headless 推进断言 + 窗口目视 | B1/B3 |
| V4 | 3/4 屏出第一特异点、此后每 1/4 屏一个；三特异点内容=奖状墙/书山/悬浮文本（占位文案「提升一分，干掉千人」） | headless travel 推进读回阈值 + 节点结构走查 | 规格 §8.3 |
| V5 | 屏息通过续行；未屏息传送到第一特异点前 1/4（travel 回退 + 进度重置） | 沿用 Corridor 自检 teleport/pass_special 断言 | 规格 §8.3 |
| V6 | 三特异点后 1/4 有限化；尽头 item 两段 E 不变 | 沿用自检 finite + C3Flow 既有断言 | 规格 §9 |
| V7 | 五信号/旗标时序与 C3Flow 兼容（corridor_entered / corridor_end） | C3Flow 既有物理断言 | 兼容性 |
| V8 | 红线：main.tscn 未改；project.godot 仅既有 [input] breathe；不新增 autoload；新增/改动脚本留 .bak；:= 推断禁令 0 命中 | git diff + Select-String（沿用 §12 命令） | 铁律 |
| V9 | 视觉分层：远景 0.3 / 中景 0.6 / 墙地面 1.0 速度比 | 读 Parallax2D 属性 + 截图 | B4 |

补充验证命令（t7 增补，原有 §12 命令全部保留）：
```powershell
Select-String -Path F:\Godot\Spine\Spine\scripts\c3\corridor\*.gd -Pattern 'fmod\('   # 禁止（须 fposmod）
Select-String -Path F:\Godot\Spine\Spine\scripts\c3\corridor\*.gd -Pattern ':= *(clamp|move_toward|lerp|min|max|smoothstep)'   # 无输出
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/c3_level.tscn -- --phase=7 --self-check
#   → exit 0 且含 corridor SELF-CHECK PASS；新增断言：段覆盖/回跳有界/60s 不露黑
```

---

## 8. 红线、许可与来源

- 铁律沿用 c3_gameplay_constraints.md §11：不动 main.tscn；不新增 autoload；本地提交不 push；改前留 .bak；白模零真实美术。
- 许可：Galawana 教程代码已等价重写（不逐字复制，博客未声明许可）；Casual Run（GPLv3）与 SirNeirda（NOASSERTION）仅借鉴思想、禁止复制代码；Godot 官方文档 MIT 可引用。
- 本规格为走廊重做的实施规格，是 docs/c3_gameplay_constraints.md §8/§9 的细化与缺陷修复方案；若与权威文档冲突，以权威文档为准并上报 captain。

---

## 9. 变更记录（中文倒序）

- 集成闭环（本回合，captain/t9）：走廊重做三模块（CorridorSegment 段循环/CorridorVisualLayer 视觉/ SpecialPointLayer 特异点）+ CorridorAssembly 组装 + CorridorCamera 相机组件全部实现；评审链 t8 pass（移动/视觉/屏息/组装/白模 5 项全 PASS，MCP 真实行走独立复核）；B2 视觉门禁截图 45.6%；修复既有断链 bug（C3Flow.on_corridor_end_confirmed 信号参数）。影响：走廊模块整体替换（Corridor.gd 段管理改造 + 新目录 corridor_visual/corridor_specials/camera）；回滚要点：git revert 本提交链（或还原 Corridor.gd.bak 旧实现+删除新组件目录）。验证：--phase=1..9 全 PASS、三 runner 49 项、MCP 全流程真实行走 E×2→卧室重显 (4820,956)。

- v1.1（本回合，researcher/t2，captain 修订要求）：① 按 captain 指示把 t1 调研报告移入仓库 docs/corridor_reuse_report.md 并更新本文引用；② B1 修复契约显式写入 t3 契约（§3.3 修复契约语句 + §3.4 硬性验收）；③ B2 修复契约显式写入 t4 契约（§5.1 修复契约语句 + §5.5 硬性验收）。影响：t3/t4 实现与 t7 验证以 v1.1 为准；回滚要点：还原文档到 v1.0 即回退。

- v1.0（本回合，researcher/t2）：初稿——基于 t1 调研（四来源）定案 D-R1..D-R6（段循环/Parallax2D 远景/滚动 shader/物理地面不动/运行时构建并行安全/屏息判定口径）；给出 t3/t4/t5 模块契约与 t6 组装清单、验收表 V1-V9。影响：t3/t4/t5 实现与 t7 验证按本文执行；回滚要点：本文为约束文档，不涉及工程回滚；若某决策被推翻，按条改对应契约即可。