# 角色移动与相机模块调研报告（docs/camera_reuse_report.md）

> 调研员：researcher（spine-corridor-rework 团队，t10 产出）
> 范围：只读调研（官方文档原文抓取 + 本地代码通读 + 教程对照），为 t12「相机跟随组件（居中+边界 clamp+平滑）」提供现成方案与复用代码。

---

## 0. TL;DR 结论

1. **官方 Camera2D 内置了全部三项需求**：居中跟随（anchor_mode=ANCHOR_MODE_DRAG_CENTER=1，默认）、边界 clamp（limit_left/right/top/bottom + limit_smoothed）、平滑（position_smoothing_enabled + position_smoothing_speed）——零代码即可满足「居中+clamp+平滑」。
2. 但本项目现有语义与官方 limit 语义有细微差别：现有 LevelScene 是「相机中心 clamp 在 [min+half, max-half]」，官方是「相机可越过 limit 由 offset 推出 / 到达 limit 即停」。参数等价映射：limit_left = map_min_x + 半视口宽、limit_right = map_max_x - 半视口宽（zoom 参与换算）。
3. 本项目已有手写实现（LevelScene._update_camera：clamp + 帧率无关指数平滑），行为正确；t12 最优路径 = **把它组件化**（CameraFollow.gd，可开关），而不是推翻重写——组件化后可支持「走廊阶段停用相机跟随」等流程需求，且与现有全部关卡场景（FloorTemplate 实例）零行为差异。
4. 走廊联调关键（t12 必须注意）：主相机是 Player/Camera2D 子节点（零 clamp），但场景里存在第二个 Camera2D（c3_floor 白模内嵌，LevelScene._ready 会 make_current 抢 active）——两相机 active 竞争是隐患，t12 组件应统一收口 make_current（见 §2.4 疑点 C1）。
5. 备选：Galawana Part 2 的相机 Y 锁定公式已在本项目由 Camera2D.offset 方案等价覆盖（C3Flow CAMERA_FRAME_OFFSET / FloorTemplate camera_position_offset），无需引入逐帧修正。

---

## 1. 本地现状（已通读）

### 1.1 相机结构
- `scenes/player.tscn`：Camera2D 是 Player(CharacterBody2D) 的**子节点**，零属性配置（默认 anchor_mode=1 DRAG_CENTER、limit ±1e7、无平滑）。
- `scripts/scenes/LevelScene.gd`：`_update_camera(delta)` 每帧执行——水平跟随 + clamp：
  ```gdscript
  var half_width := get_viewport_rect().size.x * 0.5 * _camera.zoom.x
  var target_x := _player.position.x
  var clamped_x: float = clamp(target_x, map_min_x + half_width, map_max_x - half_width)
  if camera_smoothing > 0.0:
      var alpha := 1.0 - exp(-camera_smoothing * delta)
      _camera.global_position.x = lerpf(_camera.global_position.x, clamped_x, alpha)
  else:
      _camera.global_position.x = clamped_x
  ```
  评价：语义=玩家恒居屏幕中心、出界时相机停在边界；平滑=帧率无关指数衰减（正确写法，帧率无关优于朴素 lerp）。
- `scripts/scenes/FloorTemplate.gd`：`camera_position_offset` → `_camera.offset`（垂直取景偏移，2.35:1 布局）。
- `scripts/c3/flow/C3Flow.gd`：`_activate_camera()` 对主 Player 相机 make_current + offset=CAMERA_FRAME_OFFSET(0,-336.5)。
- 走廊阶段（STAGE_CORRIDOR）：Corridor.gd 把玩家 x 钉死在 stop_center_x=4460；主相机作为 Player 子节点自然居中（无 clamp 干预）；C3Flow 未在走廊阶段修改相机行为。

### 1.2 现有参数口径
| 参数 | 值 | 位置 |
|---|---|---|
| map_min_x / map_max_x | 0 / 3840（c3_floor.tscn） | LevelScene 导出 |
| camera_smoothing | 0.0（c3_floor 即时跟随）/ 6.0 默认 | LevelScene 导出 |
| camera_position_offset | (0, -336.5) | FloorTemplate 导出 |
| CAMERA_FRAME_OFFSET | (0, -336.5)（C3Flow，t34 gap①） | C3Flow 常量 |
| 视口 | 1920×1240（project.godot，canvas_items 拉伸，aspect=keep） | project.godot |

### 1.3 疑点（t12 需排查，本报告标注而非断言）
- **C1 双相机 active 竞争**：c3_level.tscn 中存在两个 enabled Camera2D——主 `Player/Camera2D` 与白模 `WhiteModel/Player/Camera2D`（LevelScene._ready 会对其 make_current）。_ready 按树序父先子后：C3Flow（root）先 make_current 主相机，随后 WhiteModel(LevelScene) 的 _ready 又 make_current 白模相机，理论上**白模相机可能抢走 active**。若成立，画面将固定不动；但既有物理断言与 t34/t36 修复记录表明取景基本正常——可能因后续某处 make_current 兜底。t12 组件应统一收口相机归属，消除双相机歧义。
- **C2 走廊阶段相机语义**：走廊阶段玩家被钉死在 4460 而 c3_floor 的 map_max_x=3840 只作用于白模内嵌相机路径；主相机无 clamp，恰好正确。若 t12 组件把主相机也纳入 clamp，**必须**在走廊阶段停用组件或把 clamp 范围扩展到走廊（否则相机会把玩家钳出屏幕中心，直接破坏走廊机制）。

---

## 2. 来源一：官方 Camera2D（已抓官方文档原文，godot-docs master = 4.7 文档）

### 2.1 内置能力清单（与 t12 需求逐项对照）
| t12 需求 | 官方属性 | 官方原文要点 |
|---|---|---|
| 居中 | anchor_mode = 1（ANCHOR_MODE_DRAG_CENTER，引擎头文件确认：FIXED_TOP_LEFT=0 / DRAG_CENTER=1，默认 DRAG_CENTER） | 相机锚点=拖拽中心 |
| 边界 clamp | limit_left/right/top/bottom（默认 ±10000000）+ limit_enabled=true + limit_smoothed | The camera stops moving when reaching this value, but offset can push the view past the limit |
| 平滑 | position_smoothing_enabled=true + position_smoothing_speed（默认 5.0 px/s） | The camera's view smoothly moves towards its target position at position_smoothing_speed |
| 边界平滑停止 | limit_smoothed=true（无 position_smoothing_enabled 时无效） | the camera smoothly stops when reaches its limits |
| 即时到位 | reset_smoothing() | To immediately update the camera's position to be within limits without smoothing… invoke reset_smoothing() |
| 取景偏移 | offset（可越界） | Useful for looking around or camera shake animations. The offsetted camera can go past the limits |
| 死区拖拽 | drag_horizontal/vertical_enabled + drag_*_margin（默认 0.2）+ drag_*_offset | If true, the camera only moves when reaching the drag margins |
| 实际屏幕中心 | get_screen_center_position() | global_position 不代表实际屏幕位置（平滑/limit 会偏移），需用此 API 读真实值 |
| 更新时序 | process_callback（PHYSICS=0 / IDLE=1，默认 IDLE） | 相机跟随用物理帧可避免抖动 |

### 2.2 官方内置方案的等价参数映射（零代码路径）
本项目现有语义「玩家恒居中、相机中心 ∈ [min+half, max-half]」→ 官方配置等价：
```text
Camera2D (Player 子节点)
  anchor_mode                = 1 (DRAG_CENTER)
  limit_enabled              = true
  limit_left                 = map_min_x + half_viewport   # 0 + 960 = 960
  limit_right                = map_max_x - half_viewport   # 3840 - 960 = 2880
  limit_top / limit_bottom   = 视口需求（本项目仅水平跟随，不动）
  position_smoothing_enabled = camera_smoothing > 0
  position_smoothing_speed   = 像素/秒（与现有指数平滑非同一单位，需换算试调，见 §5）
  limit_smoothed             = true（与 position_smoothing 配合，边界平滑停止）
```
注意：官方 position_smoothing_speed 是「像素/秒」线性逼近，与现有「1-exp(-k·dt)」指数衰减手感不同（指数=先快后慢；官方=近似线性跟随）。两者都可接受，但**手感有差异**——若要保持现有手感，保留手写平滑（§4 组件方案）；若接受官方手感，用官方内置。

### 2.3 官方教程引用
- class_camera2d 官方 Tutorials 栏：2D Platformer Demo（https://godotengine.org/asset-library/asset/2727，官方示例库 godotengine/godot-demo-projects 2d/platformer）。其 game.gd 仅管暂停/全屏，相机在 Player 子节点场景内配置——即官方 demo 同样采用「Camera2D 挂 Player + 属性配置」零脚本路线。

---

## 3. 来源二：Galawana「Build a 2D Endless Runner in Godot 4 — Part 2」（t1 已抓全文，此处相机要点）

- **相机是 Player 子节点**（与本地一致），靠子节点关系自动水平跟随；垂直用公式锁定：
  ```gdscript
  # 目标：相机世界 Y 恒定 = CAMERA_LOCK_Y（跳跃不颠簸背景）
  $Camera2D.position.y = CAMERA_LOCK_Y - global_position.y
  ```
  推导：camera_world_y = player.y + camera.position.y ≡ LOCK_Y → camera.position.y = LOCK_Y - player.y。
- **本项目已有等价替代**：Camera2D.offset（C3Flow CAMERA_FRAME_OFFSET / FloorTemplate camera_position_offset）一次性固定垂直取景，玩家不跳（本项目无跳跃），因此**无需**引入该逐帧修正。
- 附注：Part 2 的地面用 WorldBoundaryShape2D（无限平面），已在 t1/t2 走廊规格中引用。

---

## 4. 来源三：其他现成实现（快速对照）

- **官方 2D Platformer Demo**（godot-demo-projects/2d/platformer）：Camera2D 挂 Player、场景属性配置（零相机脚本）——官方推荐姿势。
- **SirNeirda / Casual Run**（t1 已评估）：3D 相机，与 2D 无关，跳过。
- **通用平台游戏相机模式**（行业共识，对照 Godot 内置即实现）：① 恒居中（无死区）② 居中+死区拖拽（drag_*）③ look-ahead（预瞄，官方无内置，需手写）。本项目现状=①，t12 需求=①，drag 模式=② 属可选体验升级（引入需产品确认，默认不做）。

---

## 5. 方案对比与推荐

| 维度 | A. 官方内置（零代码） | B. 组件化手写（推荐） | C. drag 死区模式 | D. Galawana Y 锁定 |
|---|---|---|---|---|
| 实现量 | 场景属性配置（limit/smoothing） | 新增 CameraFollow.gd（约 50 行） | 场景属性（drag_*） | 每物理帧一行 |
| 与现有手感一致性 | 不同（线性逼近 vs 指数衰减） | **完全一致**（搬现有代码） | 改变（玩家离开中心区才拖） | 一致（本项目无跳跃，等效 offset） |
| 可开关（走廊阶段停用） | 需另写开关（enabled） | 内置 set_enabled | 同左 | 不适用 |
| 双相机收口（C1 疑点） | 不解决 | **可统一收口 make_current** | 不解决 | 不解决 |
| 帧率无关平滑 | 官方为 px/s 线性 | 指数衰减（现实现） | 官方内置 | — |
| 风险 | limit 语义与现 clamp 略不同；offset 可越界 | 自维护（但代码已存在且验证过） | 体验变更需产品确认 | 已由 offset 覆盖 |

**推荐：方案 B（组件化手写）为主，方案 A 为备选/参数对照。** 理由：
1. 现有 LevelScene._update_camera 逻辑已在三关验证（行为正确、帧率无关），组件化=平移代码+补开关，零行为风险；
2. t12 需求「居中+边界 clamp+平滑」与现有实现逐字对应；
3. 走廊/卧室阶段需要停用或重定向相机（C2），手写组件天然支持 set_enabled(false)；
4. C1 双相机疑点需要统一收口，组件可顺带持有 make_current 职责；
5. 若追求「零代码官方姿势」，按 §2.2 参数映射表配置即可（标注手感差异）。

---

## 6. 可复用代码片段（t12 直接落地）

### 6.1 CameraFollow.gd（方案 B，等价现有实现 + 开关）
```gdscript
class_name CameraFollow
extends Node2D
## 相机跟随组件：居中 + 边界 clamp + 帧率无关指数平滑（等价 LevelScene._update_camera，可开关）

@export var enabled: bool = true
@export var target: NodePath                 # 跟随目标（Player）
@export var camera: NodePath                 # Camera2D 路径（通常 Player/Camera2D）
@export var map_min_x: float = 0.0
@export var map_max_x: float = 1920.0
@export var smoothing: float = 6.0           # 指数平滑系数；0=即时
@export var follow_y: bool = false           # 本项目仅水平跟随

var _target: Node2D = null
var _camera: Camera2D = null

func _ready() -> void:
    if target != NodePath():
        _target = get_node_or_null(target) as Node2D
    if camera != NodePath():
        _camera = get_node_or_null(camera) as Camera2D
    if _camera != null:
        _camera.make_current()               # 统一收口双相机竞争（C1）

func _process(delta: float) -> void:
    if not enabled or _target == null or _camera == null:
        return
    var half_width: float = get_viewport_rect().size.x * 0.5 * _camera.zoom.x
    var target_x: float = _target.position.x
    var clamped_x: float = clamp(target_x, map_min_x + half_width, map_max_x - half_width)
    if smoothing > 0.0:
        var alpha: float = 1.0 - exp(-smoothing * delta)
        _camera.global_position.x = lerpf(_camera.global_position.x, clamped_x, alpha)
    else:
        _camera.global_position.x = clamped_x

func set_enabled(value: bool) -> void:
    enabled = value
```

### 6.2 官方内置参数对照（方案 A，备选）
```gdscript
# 零代码配置（或运行时代码注入）：
func configure_camera(cam: Camera2D, min_x: float, max_x: float, smooth_px_per_sec: float) -> void:
    cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
    cam.limit_left = int(min_x + get_viewport_rect().size.x * 0.5)
    cam.limit_right = int(max_x - get_viewport_rect().size.x * 0.5)
    cam.limit_smoothed = true
    cam.position_smoothing_enabled = smooth_px_per_sec > 0.0
    cam.position_smoothing_speed = smooth_px_per_sec
```

### 6.3 走廊/卧室阶段接入约定（C2）
```gdscript
# C3Flow（或 t6 组装）：进入走廊阶段停用跟随（玩家被 Corridor 钉死，相机随 Player 子节点自然居中）
func _on_stage_changed(s: int) -> void:
    if s == STAGE_CORRIDOR or s == STAGE_CORRIDOR_END:
        _camera_follow.set_enabled(false)
    else:
        _camera_follow.set_enabled(true)
```

---

## 7. t12 验收要点建议（供 captain/评审参考）

- V1 居中：玩家移动时屏幕中心 x 跟踪玩家 x（读 get_screen_center_position() 断言；注意用该 API 而非 global_position——官方语义）。
- V2 clamp：玩家走到 0 与 3840 边界，相机中心停于 960 / 2880，画面不越界。
- V3 平滑：smoothing>0 时相机 x 平滑逼近（两帧差单调递减）；smoothing=0 时即时。
- V4 帧率无关：以 60fps 与 30fps（engine.time_scale 或 physics 步进）跑同距离，最终相机位置一致（指数衰减数学保证）。
- V5 开关：set_enabled(false) 后相机不被组件改写（走廊阶段玩家钉死 4460 时屏幕中心=4460）。
- V6 双相机收口：场景运行后 get_viewport().get_camera_2d() 恒为主 Player/Camera2D（C1 关闭）。
- V7 兼容：c3_floor.tscn 既有关卡相机行为与改动前逐帧一致（截图对比）。

---

## 8. 来源与许可

| 来源 | 许可 | 处置 |
|---|---|---|
| Godot 官方文档（godot-docs master rst/xml、引擎头文件 camera_2d.h） | MIT | 可直接引用 |
| 官方 2D Platformer Demo（godot-demo-projects） | MIT | 可参考结构 |
| Galawana 教程 Part 2 | 博客未声明许可 | 等价重写，不逐字复制 |

抓取证据：官方文档经 raw.githubusercontent.com 直取（class_camera2d.rst / Camera2D.xml / camera_2d.h / godot-demo-projects 2d/platformer）。

---

## 9. 变更记录（中文倒序）

- v1.0（本回合，researcher/t10）：初稿——官方 Camera2D 内置能力对照表（limit/smoothing/drag/anchor_mode/offset/reset_smoothing）、与现有 LevelScene 语义的参数等价映射、方案对比（推荐组件化方案 B + 官方内置备选 A）、可复用代码（CameraFollow.gd / configure_camera / 走廊停用约定）、疑点 C1（双相机 active 竞争）/C2（走廊 clamp 冲突）、t12 验收建议 V1-V7。影响：t12 实现与 t13 评审参考；回滚要点：本文为调研文档，不涉及工程回滚。