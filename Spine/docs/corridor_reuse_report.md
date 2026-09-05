# 无限走廊重做：现成方法调研与复用方案报告

> 调研员：researcher（spine-corridor-rework 团队）
> 范围：只读调研（web 抓取 + 本地代码通读），不改任何工程文件。工程根 F:\Godot\Spine\Spine（Godot 4.7.2，2D，视口 1920×1240）。

---

## 0. TL;DR 结论（供 captain / t2 规格直接采用）

1. **官方机制首选**：Godot 4.7 中 ParallaxBackground.scroll_offset 手动驱动 + ParallaxLayer.motion_mirroring 是官方为「无相机滚动/世界移动」场景保留的标准无限滚动方案；更新替代品 Parallax2D（repeat_size + autoscroll）已内置「无限重复」。二者均适配本项目「角色固定在屏幕中心、世界沿 -x 移动」的形态。
2. **Galawana 教程方案**（自研 parallax_layer：克隆两份贴图 + fmod 回跳）与官方 mirroring 原理同源，代码约 40 行、无弃用 API、可把「相机 delta」直接换成「走廊行进距离」，是与现有 Corridor.gd 衔接最平滑的移植路径。
3. **Casual Run Arcade 模板**：Godot 3.5 / 3D / **GPLv3**，代码不可直接移植（许可+版本双重障碍），仅借鉴「路段循环回收」思想。
4. **SirNeirda 无限世界**：3D C# 地形，仓库**未声明许可（NOASSERTION）**，仅借鉴「围绕玩家生成/回收 chunk + LOD」思想。
5. **推荐组合**（详见 §7）：
   - 视觉无限滚动：**方案 B（Galawana 移植，墙段克隆+fmod 回跳）为主推**——特异点需挂在墙层上与墙同坐标系联动，官方 Parallax 层是纯渲染层不宜挂游戏逻辑；纯背景层可加官方 Parallax2D.repeat_size 一行配置。
   - 墙纹理滚动：现 c3_level.tscn 用 CanvasItemMaterial（无 texture_offset，代码注释已自认滚不动）→ 改 **ShaderMaterial + canvas_item UV 偏移 shader**，复用现有 _scroll_texture 调用点。
   - 特异点/屏息判定：**保留现有 Corridor.gd 的 travel 阈值状态机不动**（逻辑本身正确），只替换「墙怎么画/怎么无限」的渲染层。
   - 视觉层：按 Galawana 比例表加 2-3 层景深（0.02/0.30/0.60/1.00），走廊微压暗氛围复用现有 DarknessMask。

---

## 1. 本地现状诊断（已通读代码，bug 根因定位）

已读：scripts/c3/corridor/Corridor.gd（432 行）、scripts/components/DepthParallax.gd、scripts/c3/breath/BreathSystem.gd、scripts/c3/flow/C3Flow.gd、scripts/player/Player.gd、scenes/c3_level.tscn、scenes/c3_floor.tscn、project.godot、docs/c3_gameplay_constraints.md（§8 走廊契约）。

### 1.1 现状机制（Corridor.gd）
- 玩家 x 到达 stop_center_x(4460) → 切 MODE_MOVING：每帧把玩家 x 钉死在 4460，_container.position.x = _start_local_x - _travel_dist 整体左移走廊节点。
- 特异点按 _travel_dist 阈值触发（first 1020 / span 340 / count 3），屏息判定 = 长按 breathe ≥ 0.5s 且 hold_breath_unlocked。
- 有限化 = travel ≥ first + 3*span → MODE_FINITE → 玩家向右走到 end_wall_x。

### 1.2 已定位 bug/缺陷根因（对应「现状 bug 多、视觉不足、墙壁移动未达预期」）

| # | 根因 | 现象 | 修复方向 |
|---|------|------|----------|
| B1 | CorridorWall Polygon2D 只有 2000px 宽（0..2000 local），整体左移无任何循环/镜像 | 行进超 2 屏后整面墙移出屏幕，露黑、无限感断裂 | 墙段克隆+fmod 回跳（§4/§7）或官方 mirroring |
| B2 | wall_mat 是 CanvasItemMaterial（c3_level.tscn:48，texture_repeat=1）；_scroll_texture() 只对 ShaderMaterial 生效（Corridor.gd:160-166 注释自认） | 墙壁纹理从不滚动，规格「需墙壁纹理表现移动」未达成 | 换 ShaderMaterial UV 偏移（§6.2）或 Sprite2D region 平移 |
| B3 | 地面视觉 CorridorFloorVisual 挂在 Corridor 下随墙左移，物理地面 CorridorFloor 是固定 StaticBody2D | 视觉地面会移出屏幕，物理/视觉分离 | 地面并入无限层；物理地面保持静态即可（角色 x 固定） |
| B4 | 走廊段视觉只有 1 张 corridor_wall.png + 纯色 Polygon2D | 「视觉不足」：无景深、无氛围、无变化 | 多层视差 + 微压暗氛围（复用 DarknessMask） |
| B5 | 屏息判定 0.5s 与 BreathSystem 缺氧触发 0.5s 同阈值（规格 §8.3 已知待确认点 J4） | 过特异点时必触发缺氧压暗，张力是否符合预期待产品确认 | t2 规格明确判定口径（本报告建议：屏息判定 0.35s、缺氧触发 0.8s 分离，避免每次过点必缺氧；若要保留张力则同值并明写） |
| B6 | _build_specials 的 base 用 _cbx（仅 _enter_moving 赋值一次），场景重进/hot-reload 时 local_x 依赖旧值 | 重进走廊特异点位置可能漂移 | 以固定基准重算，或随墙段统一管理 |

### 1.3 可保留资产（不要推倒重来）
- Corridor.gd 的状态机、特异点触发逻辑、信号接口（corridor_entered / special_point_passed / teleport_triggered / corridor_finite / end_wall_reached）与 C3Flow 全部接线可保留——重做范围 = 渲染层 + 无限机制 + 视觉层。
- BreathSystem / DarknessMask / 特效库不动；--self-check、--phase 调试入口保持。

---

## 2. 来源一：Godot 官方 ParallaxBackground / ParallaxLayer / Parallax2D（mirroring 机制，官方文档原文已抓）

来源：godotengine/godot-docs 官方 rst 源码（classes/class_parallaxlayer.rst、class_parallaxbackground.rst、class_parallax2d.rst、tutorials/2d/2d_parallax.rst，master 分支 = 4.7 文档）。

### 2.1 ParallaxLayer.motion_mirroring（官方「无限滚动」机制）
- 定义：motion_mirroring: Vector2 = (0,0) —— 「The interval, in pixels, at which the ParallaxLayer is drawn repeatedly. Useful for creating an infinitely scrolling background.」设为 0 的轴只画一次。
- 实现本质：**层最多画 2 份实例**，滚动越过一个 mirroring 区间时位置**瞬间回跳**（snap-back）形成无缝循环视觉（官方原注：Despite the name, the layer will not be mirrored, it will only be repeated）。
- 官方坑位清单（必须写进 t2 规格）：
  1. mirroring 值须按**缩放后**的实际像素计算（600px 贴图 scale 0.5 → mirroring=(300,0)）。
  2. **视口轴长 > 2×重复区间时不无限**（只画 2 份）。本项目墙段宽 2048、视口 1920：1920 < 4096，安全；层内容必须 ≥ 视口宽。
  3. **入树后改 ParallaxLayer 的 position/scale 会被忽略**；调整背景位置要用父 ParallaxBackground 的 CanvasLayer.offset。
- motion_scale：层滚动速度乘数（=深度比）；motion_offset：相对父 scroll_offset 的偏移。
- ⚠ Godot 4.x 已将 ParallaxLayer/ParallaxBackground 标记 **Deprecated**（官方原文：Deprecated: Use the Parallax2D node instead），仍可用，但新代码优先 Parallax2D。

### 2.2 ParallaxBackground.scroll_offset（本项目关键：无相机驱动的手动滚动）
官方原文：「If not used with a Camera2D, you must manually calculate the scroll_offset.」——正好是本项目形态（相机不动、世界动）。驱动方式：

```gdscript
# 每帧：走廊行进多少，背景就滚动多少（可乘层深度比）
parallax_bg.scroll_offset.x += speed * delta
```

### 2.3 Parallax2D（官方推荐替代，4.3+ 引入，4.7 可用）
关键属性（官方 class_parallax2d.rst）：
- scroll_scale: Vector2 —— 相对相机滚动的速度乘数（0=静止，1=同速，>1=更快；即深度比）。
- repeat_size: Vector2 —— **无限重复区间**：相机滚过一个 repeat_size 后位置回跳（snap-back），官方称 gives textures the illusion of repeating infinitely。
- repeat_times: int = 1 —— 重复份数（默认前后各 1 份）；zoom-out 导致内容 < 视口时提高份数。
- autoscroll: Vector2 = (0,0) —— **每帧自动滚动固定速度，无需相机**！「世界移动」形态下最省事的官方无限滚动入口。
- ignore_camera_scroll: bool —— 忽略相机位置，改用手动 scroll_offset 驱动（与 ParallaxBackground.scroll_offset 同义）。
- 教程（2d_parallax.rst）重点：**所有子纹理必须从 (0,0) 起锚**（不能居中）；repeat_size 建议 ≥ 视口大小；repeat_size/region_rect 不随 scale 变化；官方推荐 KoBeWi 的 Parallax2D Preview 插件做编辑器预览。

### 2.4 官方教程推荐比例（五层 scroll_scale）
Forest 0.7 / Hills 0.5 / Lower Clouds 0.3 / Higher Clouds 0.2 / Sky 0.1。

---

## 3. 来源二：Galawana「Build a 2D Endless Runner in Godot 4」三部曲（已取 Part 1/2 全文）

来源：galawana.com（站点有 Cloudflare 反爬，直连被验证墙拦截；经 r.jina.ai 阅读代理成功抓取全文；archive.org 无该页快照；archive.ph 限流 429）。Part 1：视差场景（2026-06-16）；Part 2：角色动画与相机锁定（2026-06-17）；Part 3 链接 404 未发布。项目参数：Godot 4.6.2、GL Compatibility、1280×720、canvas_items。

### 3.1 作者给出的「为什么不用内置 ParallaxBackground」（与本项目决策直接相关）
1. 深度比在运行时难以微调；
2. 平铺需要手动复制 sprite（内置 mirroring 需要精心准备的贴图）；
3. **没有干净的方式让其他脚本消费「相机每帧位移」这个原始量**——对跑酷（和本项目走廊）来说一切节奏都基于这个 delta。

### 3.2 其自研系统（两脚本，完整可移植）
- ParallaxController（Autoload）：每帧算相机位移，暴露 delta 公共变量（本项目注意：规格红线「本模块不新增 autoload」→ 移植时把该职责并入 Corridor.gd，用 _travel_dist 增量代替相机 delta）。
- parallax_layer.gd（@tool）：_ready 克隆贴图两份（±tile_width）→ 每帧 position += delta * ratio（仅 X 轴，Y 零化保证跳跃不颠簸）→ fmod 回跳：

```gdscript
if abs(cam_x - global_position.x) >= _tile_width:
    var offset: float = fmod(cam_x - global_position.x, _tile_width)
    global_position.x = cam_x - offset
```

- 深度比例表（可直接抄进 t2 规格做视觉层参数）：

| 层 | 比例 | 感觉 |
|---|---:|---|
| Sky | 0.02 | 极远、几乎不动 |
| Mountains | 0.15 | 远背景 |
| Hills | 0.30 | 中景 |
| Trees | 0.60 | 近景 |
| Ground | 1.00 | 与角色同步 |

- Part 2 可复用点：**WorldBoundaryShape2D** 做无限地面碰撞（零配置无限直线、无边缘缝隙问题）——本项目走廊物理地面可照搬（角色 x 固定，一条就够）；纹理 filter=Nearest（像素风贴图不糊）。相机 Y 锁定公式本项目已有 C3Flow 固定 offset，不适用跳过。

### 3.3 移植要点（本项目形态差异）
本项目「角色不动、世界动」：把 ParallaxController.delta 换成 Corridor._travel_dist 每帧增量；「相机位置」换成「屏幕中心 x 4460」。fmod 回跳目标点从「相机 x」换成「屏幕中心 x」，其余逻辑原样。

---

## 4. 来源三：Casual Run Arcade（Godot Asset Library #3722）

来源：godotengine.org asset-library API JSON + GitHub 仓库文件树 + Road#1.gd / Background.gd 原文。

- 元数据：title=「Casual Run Arcade Project - Endless Runner Base Game」，作者 Rahmid，版本 1.3，**Godot 3.5**，GLES2，**cost=GPLv3**，community 支持，下载=GitHub zip（Rahmid93421/Godot-Open-Source-3d-Project---Casual-Run-Arcade @ 489f017）。
- 实际形态：**3D 跑道**项目（Road#1.gd 用 Vector3/translation；Hit the road Jack 场景）。核心机制：StaticBody 路段 + _refreshRoad() 在路段被越过时**移除并重新随机生成**路内内容（房子/金币/障碍），即「路段循环回收」。
- 复用价值与限制：
  - ✅ 可借鉴：**墙段循环回收模式**——走廊前进时，越过屏幕左缘的墙段回收并移到最右、重新装饰（特异点/奖状分布），内存与节点数有界。
  - ❌ 不可直接搬：3.5 语法（export onready var、instance()）与 4.7 不兼容；3D 内容与本项目 2D 无关；**GPLv3 传染许可**——本项目未声明 GPL，直接抄代码会引入许可污染，**只允许借鉴思路、禁止复制代码**。

---

## 5. 来源四：SirNeirda/godot_procedural_infinite_world

来源：GitHub README + API（70 stars，2026-08-31 更新，Godot 4.6 兼容，C#）。

- 内容：3D 程序化无限地形——Simplex 噪声 chunk 生成、地形 LOD、可调视野、**围绕玩家生成/清理**、昼夜循环、水体 shader、TPS 演示。
- 复用价值与限制：
  - ✅ 可借鉴：**「围绕关注点生成/回收」的空间管理**（对应走廊：围绕屏幕中心管理墙段，屏幕外的段回收/前移）、LOD 思想（远层低细节）。
  - ❌ 不适用直接复用：C#（本项目 GDScript）、3D 地形与 2D 走廊形态无关、**仓库未声明许可（license=NOASSERTION）**——只能借鉴思路，不搬代码。

---

## 6. 可复用代码片段（已重写为可直接落地的等价实现）

### 6.1 墙段无限循环（Galawana 模式移植，方案 B，主推）

```gdscript
# corridor_segment.gd — 挂在每段墙/地面视觉段上（或由 Corridor.gd 集中管理）
## 段宽必须 ≥ 视口宽（本项目视口 1920，段宽建议 2048 或贴图宽整数倍）
class_name CorridorSegment
extends Node2D

@export var segment_width: float = 2048.0   # 段宽（像素）
@export var scroll_ratio: float = 1.0       # 深度比：墙=1.0、近景>1、远景<1

var _anchor_x: float = 0.0                  # 回跳锚点（世界 x，通常是屏幕中心）

func setup(anchor_world_x: float) -> void:
    _anchor_x = anchor_world_x

## 每帧由 Corridor 调用：travel_delta = 本帧行进距离（move_speed * delta）
func advance(travel_delta: float) -> void:
    position.x -= travel_delta * scroll_ratio
    # fmod 回跳：离开锚点超过一个段宽 → 前跳一个段宽（Galawana snap-back）
    var off: float = fposmod(_anchor_x - global_position.x, segment_width)
    global_position.x = _anchor_x - off
```

关键参数：fposmod（正余数）避免负坐标抖动；anchor 用屏幕中心 x（4460）而不是相机位置；每个段可挂多个子节点（墙 Polygon2D、奖状、书山、地面条）。

### 6.2 墙壁纹理真正滚动（修 B2：CanvasItemMaterial → ShaderMaterial）

```gdshader
// corridor_scroll.gdshader — canvas_item shader，UV 沿 x 平移实现平铺纹理滚动
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D tex : source_color;
uniform float scroll_speed = 0.0;          // px/s，由 Corridor 每帧写入
uniform float tex_scale : hint_range(0.01, 100.0) = 1.0;  // 世界像素→UV 比例

void fragment() {
    // 用累计时间滚动：速度恒定即可；如需与 travel 精确同步改用 uniform offset
    vec2 uv = UV * vec2(tex_scale, 1.0);
    uv.x -= TIME * scroll_speed / tex_scale;
    COLOR = texture(tex, uv);
}
```

Corridor.gd 侧（复用现有 _scroll_texture 调用点，只需把 c3_level.tscn 的 wall_mat 换成 ShaderMaterial + 此 shader）：

```gdscript
func _scroll_texture(delta: float) -> void:
    if _wall_mat is ShaderMaterial:
        # 已有 texture_offset uniform 的老路径保留（向后兼容）
        var sm := _wall_mat as ShaderMaterial
        var cur: Variant = sm.get_shader_parameter("texture_offset")
        if cur is Vector2:
            sm.set_shader_parameter("texture_offset", (cur as Vector2) - Vector2(move_speed * delta, 0.0))
        # 新路径：写 scroll_speed（shader 用 TIME 自滚动，不依赖逐帧 offset）
        sm.set_shader_parameter("scroll_speed", move_speed)
```

更简单替代：改用 Sprite2D + region_enabled + region_rect 逐帧平移（CanvasItem 层面重复平铺，无需 shader）。

### 6.3 官方 Parallax2D 一行式无限滚动（方案 A，纯背景层最省事）

```gdscript
# 背景/远景层：不挂游戏逻辑，仅视觉。4.7 原生支持。
@onready var far_parallax: Parallax2D = $ParallaxFar
func _ready() -> void:
    # 内容 Sprite2D 必须从 (0,0) 起锚；repeat_size = 单张贴图实际像素（含缩放）
    far_parallax.repeat_size = Vector2(2048, 0)
    far_parallax.autoscroll = Vector2(-move_speed * 0.3, 0)   # 每帧自动滚，0.3=深度比
```

注意：Parallax2D 子节点内容会参与渲染重复，但**不要把特异点等游戏逻辑节点挂进去**（自动重复与位置管理是渲染层行为）。

### 6.4 官方 ParallaxBackground + ParallaxLayer.motion_mirroring（方案 A 旧版，文档弃用但可用）

```gdscript
# 每帧手动驱动（无相机滚动的官方支持场景）
func _process(delta: float) -> void:
    $ParallaxBackground.scroll_offset.x += move_speed * delta
```

```text
ParallaxBackground (layer=-100)
├─ ParallaxLayer (motion_mirroring = Vector2(2048, 0), motion_scale = Vector2(0.3, 1))  ← 远景
├─ ParallaxLayer (motion_mirroring = Vector2(2048, 0), motion_scale = Vector2(0.6, 1))  ← 中景
└─ ParallaxLayer (motion_mirroring = Vector2(2048, 0), motion_scale = Vector2(1.0, 1))  ← 墙层（近）
```

坑：层内容须 ≥ 视口宽且从 (0,0) 起锚；入树后别改层 position。

### 6.5 墙段对象池（Casual Run 思想移植，可选方案 C）

```gdscript
# 三段墙循环：段过屏幕左缘 → 回收移到最右（+3*段宽），重新装饰（特异点）
func _recycle_segments() -> void:
    for seg in _segments:                       # 3 段，每段 2048
        if seg.global_position.x + segment_width < _camera_left_edge:
            seg.position.x += segment_width * _segments.size()
            _decorate(seg)                      # 重新随机放奖状/书/文本
```

---

## 7. 方案对比与推荐组合

| 维度 | A. 官方 Parallax（Parallax2D.repeat_size 或 Background+mirroring） | B. Galawana 自研移植（克隆+fmod） | C. Casual Run 墙段回收池 |
|---|---|---|---|
| 无限滚动 | ✅ 官方机制，1 行 autoscroll | ✅ 40 行自管 | ✅ 自管 |
| 与特异点联动 | ❌ Parallax 层不适合挂游戏逻辑 | ✅ 特异点=墙段子节点，随段移动 | ✅ 回收时重新装饰 |
| 改动衔接 | 中（新增层节点，Corridor 保留 travel 逻辑） | **最顺**（只替换墙渲染 + 加段） | 大（重写墙管理） |
| 弃用/兼容 | Parallax2D 无弃用；ParallaxLayer 已弃用 | 无弃用 API，纯 Node2D | 无 |
| 纹理滚动 | 需另配 shader（同 B2 修复） | 同左 | 同左 |
| 风险 | 官方坑（起锚/尺寸）多，需按清单配置 | 自维护平铺，逻辑透明 | 接缝/装饰随机化要自己写 |

**推荐（t2 规格建议）**：
1. **墙层 + 地面 + 特异点载体：方案 B**（Galawana 移植）。理由：特异点必须与墙同坐标系移动，官方 Parallax 层是纯渲染层，挂逻辑节点会与自动重复冲突；B 与现有 Corridor.gd 的 position 运算完全同构，_apply_wall_offset 换成段 advance() 即可，改动面最小。
2. **远景/氛围层（可选加分项）：方案 A 的 Parallax2D.repeat_size + autoscroll**，纯视觉，一行配置。
3. **墙纹理滚动：6.2 的 ShaderMaterial UV 滚动**（修 B2，这是规格验收「需墙壁纹理表现移动」的硬要求）。
4. **物理地面**：走廊段改为一条 WorldBoundaryShape2D（Galawana Part2 做法）或保持现固定 StaticBody2D（角色 x 固定，已足够）；视觉地面并入方案 B 的地面段。
5. **视觉升级清单**（对应「视觉不足」）：至少 3 层（远景 0.3 / 中景 0.6 / 墙 1.0）+ 墙纹理滚动 + 走廊微压暗氛围（复用现有 DarknessMask 低强度配置，C3Flow 已有 LIGHT-D 类似写法）+ 可选墙饰（奖状/书/文本随段随机化）。
6. **B5 建议**：屏息判定阈值（如 0.35s）与 BreathSystem 缺氧触发阈值（0.5s）分离为两个参数，避免「每次屏息过点必缺氧」；若产品就是要这个张力（规格 §8.3 J4 原口径），则保持 0.5s 同值并在 t2 明写。

---

## 8. 许可与来源风险

| 来源 | 许可 | 处置 |
|---|---|---|
| Godot 官方文档/教程 | MIT（godot-docs） | 可直接引用/改写 |
| Galawana 教程 | 博客未声明许可 | 已做等价重写（6.1/6.2），不逐字复制其教程代码 |
| Casual Run Arcade | **GPLv3** | **禁止复制代码**，仅借鉴路段回收思想（§4/6.5） |
| SirNeirda 无限世界 | **NOASSERTION（未声明）** | 仅借鉴生成/回收思想，不搬代码 |

抓取证据（供复现）：galawana.com 直连被 Cloudflare 验证墙拦截 → 经 https://r.jina.ai/<url> 阅读代理成功取全文；archive.org 无该页快照；archive.ph 限流 429。官方文档经 raw.githubusercontent.com/godotengine/godot-docs master 分支 rst 源码直取。

---

## 9. 给 t2 规格（走廊重做规格）的落点建议

1. 保留：Corridor.gd 状态机/信号/屏息判定/特异点阈值/有限化/调试入口/自检框架；C3Flow 全部接线。
2. 替换：墙渲染 → 3 段 CorridorSegment（2048px）+ fmod 回跳；wall_mat → ShaderMaterial 滚动 shader。
3. 新增：远景/中景 Parallax2D 层（可选）+ 墙段随机装饰接口 _decorate(seg)。
4. 参数表：segment_width=2048、depth_ratios={far:0.3, mid:0.6, wall:1.0, ground:1.0}、texture scroll=move_speed、hold 判定/缺氧阈值分离参数。
5. 验收要点：行进 60s 无露黑/无接缝跳变；纹理可辨滚动；特异点随墙移动且触发距离不变；三特异点内容按段装饰。
