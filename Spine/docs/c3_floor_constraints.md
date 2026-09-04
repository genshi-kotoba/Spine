# C3 层关卡白模：约束文档与验收契约

> 依据：用户模块规格（团队任务 t1 描述原文 ①–⑪）+《C2-C5_游戏策划案.md》开发文档约定（「所有代码文件产出前，须先生成对应的 Markdown 约束文档」）。
> 本文件是 C3 白模模块的**唯一权威约束**：实现（t2）、验证（t3）、评审（t4）均以本文为准。
>
> **设计权铁律**：本文只收录用户已提出的规格，不添加任何新的玩法/操作设计。凡标「实现禁区」的条目，实现中出现即判 FAIL。

## 1. 用户规格原文（必须全部覆盖，不得增删设计）

1. 资产全占位符（灰盒/色块白模）。
2. 分辨率基准 1920×1080，游戏画面 16:9 电影画幅，窗口非 16:9 时保留上下黑边。（执行定案见 §7 与 §12-A3：固定窗口 1920×1240，上下各 80px 黑边为预留文案呈现区。）
3. 每层布局相同、可复用（先做 C3，模板化）。
4. 入场为三房间——书房、客厅、餐厅，均分 16:9 场景页（每房 640×1080），用墙分隔。
5. 房间之间有木门，角色通过时自动打开（触发式，无需按键）。
6. 入场位置在书房。
7. room4 卧室门在客厅中央，默认闭锁（本模块只做锁态，解锁玩法待用户设计，**禁止实现**）。
8. 整体横板，带景深增强质感——复用组件（不止 C 层用），景深主要跟随角色，鼠标移动微微触发（幅度小、导出参数可调）。
9. 基于已有状态机（GameState / StoryMonitor / InteractableObject / LevelScene / Player 骨架）。
10. 打磨手感（移动/镜头/门，参数化导出）。
11. 硬约定：代码产出前先出本文档。

## 2. 工程事实与现有骨架盘点

- 仓库根：`F:\Godot\Spine`；Godot 工程根：`F:\Godot\Spine\Spine`（res:// 即此目录）。
- 引擎：Godot 4.7（`F:\Godot\godot\godot.exe`）。
- 现有骨架（规格⑨所指，其语义与命名必须沿用）：
  - `GameState`（autoload）：对象状态字典 + JSON 存档 + `state_changed` 信号；
  - `StoryMonitor`（autoload）：`input_locked` 全局输入锁（场景输入处理必须先检查）；
  - `InteractableObject`（Area2D 基类）：`object_id` / `initial_state` / `states` / `change_state()`（写 GameState）/ `interact()`（子类覆写）；
  - `LevelScene`：节点路径 `$Player`、`$Player/Camera2D`；`map_min_x` / `map_max_x` 相机 clamp；_ready 扫描 InteractableObject 子节点接 E 键交互；输入先查 `StoryMonitor.input_locked`；
  - `Player`（CharacterBody2D）：A/D 水平移动 + 重力；物理帧先查 `input_locked`；
  - 输入集（project.godot）：`move_left`(A/←)、`move_right`(D/→)、`interact`(E)——本模块**不得新增/删除输入**；
  - `main.tscn`：空壳主场景，本模块不得改动；
  - `DialogueBox` / UI：本模块不涉及（无对话内容）。
- 命名惯例（现状归纳）：脚本文件名与 `class_name` 一致且 PascalCase（Player.gd、LevelScene.gd、InteractableObject.gd）；场景文件名 snake_case（level_scene.tscn、player.tscn）；节点名 PascalCase；私有成员 `_` 前缀；信号 snake_case。

## 3. 模块边界

**In scope（新增/修改）**

- 新增：`scenes/floor_template.tscn`、`scenes/c3_floor.tscn`；
- 新增：`scripts/scenes/FloorTemplate.gd`、`scripts/objects/AutoDoor.gd`、`scripts/objects/LockedBedroomDoor.gd`、`scripts/components/DepthParallax.gd`；
- 修改（仅加参数，见 §8）：`scripts/player/Player.gd`、`scripts/scenes/LevelScene.gd`；修改前先在同目录留 `.bak`；
- `project.godot` 显示/拉伸设置（见 §7；改前必须先备份，见 §7 硬约束）；
- 占位资源（如需贴图）：`assets/placeholder/`（见 §6）。

**Out of scope / 实现禁区（违反即 FAIL）**

- 不改 `main.tscn`、`main_scene.tscn`、`level_scene.tscn` 等既有场景；
- **卧室解锁玩法**：任何解锁交互、钥匙道具、把状态从 `locked` 切走、允许进入 room4——一律禁止（规格⑦：解锁玩法待用户设计，本模块禁止实现）；
- **新能力**：跳跃、冲刺、蹲、跑等任何新操作/角色能力（输入集保持 move_left / move_right / interact 三项）；
- 真实美术、外部/网络下载资产；
- 对话/剧情内容；
- push（团队约定：本地提交、不 push）。

## 4. 场景结构与节点命名

### 4.1 场景树（C3 实例 scenes/c3_floor.tscn）

```
C3Floor (FloorTemplate.gd，实例自 floor_template.tscn)
├─ Player                    # instance player.tscn；出生点=书房（规格⑥）
│  └─ Camera2D               # 沿用 player.tscn 结构，LevelScene 置为 current
├─ Environment               # Node2D：白模灰盒（StaticBody2D 碰撞）
│  ├─ Floor / Ceiling        # 地面（y=1160 游戏区底）/ 顶面（y=80 游戏区顶）
│  ├─ WallLeft / WallRight   # 外墙 x=0 / x=1920
│  ├─ WallStudyLiving        # 书房|客厅 分隔墙（x=640，开一个门洞）
│  └─ WallLivingDining       # 客厅|餐厅 分隔墙（x=1280，开一个门洞）
├─ Doors                     # Node2D
│  ├─ AutoDoorStudyLiving    # AutoDoor.gd（书房↔客厅，规格⑤）
│  ├─ AutoDoorLivingDining   # AutoDoor.gd（客厅↔餐厅，规格⑤）
│  └─ LockedBedroomDoor      # LockedBedroomDoor.gd（客厅中央、闭锁，规格⑦）
└─ DepthParallax             # DepthParallax.gd（规格⑧，可挂任意场景）
   ├─ LayerFar               # 远层：depth_factor 最小
   ├─ LayerMid               # 中层
   └─ LayerNear              # 近层：depth_factor 最大
```

### 4.2 布局坐标（规格④）

- 窗口/取景帧：1920×1240（固定窗口，见 §7）；游戏区 1920×1080 垂直居中：y∈[80,1160]；y∈[0,80] 与 y∈[1160,1240] 为上下黑边（预留文案呈现区，本模块留空，见 §12-A3）。
- 三房均分游戏区：书房 x∈[0,640]、客厅 x∈[640,1280]、餐厅 x∈[1280,1920]，y∈[80,1160]。
- 分隔墙 x=640 与 x=1280；每堵墙一个门洞，木门置于门洞（通行高度，实现自由）。
- 地板 y=1160（游戏区底边）；顶面 y=80（游戏区顶边）。
- 出生点（规格⑥）：书房内，建议 (320, 地板站立高度)。
- 闭锁卧室门（规格⑦）：客厅中央区域，建议 x≈960、落地于地板 y=1160；位置以「客厅中央」为准，精确坐标可微调。

### 4.2b 画幅 2.35:1（2026-09-05 用户定案 · 覆盖本节与 §4.3 的数值）

- 游戏画幅 16:9 → **2.35:1**：宽 1920 不变，游戏区高 **817**；固定窗口 1920×1240 不变；上下黑边增大为**上 211px / 下 212px**（仍为预留文案区，无场景内容）。
- 游戏区：y∈[211,1028]；三房仍均分：各 640×817；分隔墙 x=640/1280 不变。
- 地板带：y∈[988,1028]（厚 40，站立面 988，中心 1008）；顶面带：y∈[211,251]（厚 40）。
- 分隔墙门洞：开口 y∈[708,1028]（高 320）；门楣柱 y∈[211,708]（高 497，中心 459.5）。
- 自动木门：面板 20×280（组件场景不变），实例位置 y=868（开口中心）；闭锁卧室门：面板 24×340（组件场景不变），底部贴站立面 988 → 实例位置 (960,818)。
- 出生点：书房内 (320,948)（碰底 980，距站立面 988 留 8px 空隙，沿用 F5 教训）；角色站立后 y≈956。
- 相机：固定取景中心 (960,619.5)，实例 camera_position_offset=(0,-336.5)（相机语义：中心=玩家位置+offset）。
- 相机固定取景中心：(960,619.5)；DepthParallax anchor_point 实例覆盖 (960,619.5)；景深层 rect 半高 430（宽 2304 不变）。
- 不变项/禁区：project.godot 与全部 .gd 脚本逻辑零改动（仅场景实例数值）；门/锁/景深/输入/手感语义不变；无新增玩法。

### 4.3 相机行为预期（横板前提）

- LevelScene 相机 clamp：`map_min_x=0`、`map_max_x=1920`。本关地图宽 = 视口宽（1920），因此相机水平位移恒为 0（画面固定居中 x=960）。**这是预期行为，不是 bug**。
- 本关相机为全帧固定取景：镜头中心 (960, 620)，全帧 1920×1240 入镜（上下黑边必须可见）。竖直方向不随角色移动，由实例固定（实现方式自由：实例配置偏移或模板导出）。
- 模板保留横板卷动能力（`map_min_x` / `map_max_x` 导出），后续加宽楼层即可复用卷轴。
- 因此景深「主要跟随角色」必须由**角色位置**驱动（见 §5.3），不得依赖相机移动——依赖相机在本关效果恒为 0。

### 4.4 节点命名规范（与现有骨架一致）

- 节点名 PascalCase；场景文件名 snake_case；脚本文件名与 class_name 一致（PascalCase）。
- 私有成员 `_` 前缀；信号 snake_case（照 state_changed / dialogue_finished 惯例）。
- 门节点语义名：`AutoDoor<房间A><房间B>`、`LockedBedroomDoor`。

### 4.5 GDScript 编码红线（显式类型）

- **红线**：禁止用 `:=` 从返回 Variant 的内建函数推断类型，例如 `var x := clamp(...)`、`var v := move_toward(...)`（及 lerp / min / max 等同类返回 Variant 的内建函数）——此类推断会触发 `inferred-from-Variant` 警告并被当 error 拦停，导致脚本无法挂载。
- **规则**：此类声明一律显式标注类型：`var x: float = clamp(...)`、`var v: Vector2 = move_toward(...)`。
- **适用范围**：本模块全部新增/修改脚本（FloorTemplate.gd、AutoDoor.gd、LockedBedroomDoor.gd、DepthParallax.gd、Player.gd、LevelScene.gd）。
- **踩坑记录**：实现阶段已在 LevelScene.gd、DepthParallax.gd 实测触发，后续一律显式类型。
- **验证**：headless 加载命令（§11 #1/#2）与 §11 静态扫描均可暴露该问题；脚本挂载失败即违反红线。

## 5. 信号流与状态机对接（规格⑨）

### 5.1 AutoDoor（scripts/objects/AutoDoor.gd）

- 节点类型：Area2D，触发式（不占 interact 键）；门体为白模占位色块（建议暖棕灰，与墙区分），开合动画用 Tween（上滑/侧滑/旋转任选）。
- 触发流：玩家 `body_entered` → `open()`；`body_exited` → 延迟 `close_delay` 后 `close()`。
- 可选信号（供未来剧情挂钩）：`door_opened`、`door_closed`。
- 与状态机关系：木门不注册 GameState 状态（非解谜对象）；不检查 `StoryMonitor.input_locked`（纯物理触发，不引入新输入语义）；不改动 StoryMonitor/GameState 现有行为。
- 开启后门体不得阻挡玩家（移动/禁用门体碰撞）。
- 参数（规格⑩，全部 `@export`）：`trigger_margin`、`open_duration`、`close_delay`、缓动类型。

### 5.2 LockedBedroomDoor（scripts/objects/LockedBedroomDoor.gd）

- 继承 `InteractableObject`：进入 LevelScene 的 E 键扫描与 GameState 存档链路（规格⑨）。
- 配置（写在 c3_floor.tscn）：`object_id="c3_bedroom_door"`、`initial_state="locked"`、`states` 仅含 locked（如 `{"locked": {}}`）。
- `interact()` 必须为空实现（可留注释「禁止解锁玩法：解锁待用户设计」）——不得调用 `change_state()`、不得修改 `current_state`、不得打开门体。
- 物理阻挡：门体/门框挂 StaticBody2D 碰撞——玩家不可穿过、不可进入 room4。
- **闭锁语义 = 锁态 + 物理阻挡 + E 键无效果，三者同时成立**；缺少任一即 FAIL。
- 视觉与普通木门可区分（建议深灰 + 醒目标记色块），供验证目视判断。
- 存档行为：进入场景即经 InteractableObject._ready 既有链路写入 `"c3_bedroom_door"="locked"`，无需新代码。

### 5.3 DepthParallax（scripts/components/DepthParallax.gd）——独立可复用组件

- 定位：独立可复用组件（规格⑧「不止 C 层用」），可挂到任意场景。
- 结构：`extends Node2D`；子节点为景深层（数量/命名自由），每层配置 `depth_factor`。
- 主要跟随角色（规格⑧）：每帧按 `target` 节点 `global_position` 相对 `anchor_point` 的位移 × 各层 depth_factor 平移该层；远景 |factor| 小、近景 |factor| 大。
- 鼠标微触发（规格⑧）：附加偏移 =（视口鼠标位置 − 视口中心）× `mouse_influence` × 层 depth_factor；幅度小；`mouse_influence` 为 `@export`（=0 即完全关闭鼠标视差）。
- 平滑：层偏移经平滑插值（`smoothing` 参数），避免抖动。
- 导出参数：`target_path`(NodePath，默认空、由实例场景配置)、`anchor_point`(Vector2，建议游戏区中心 (960,620))、`mouse_influence`(float，建议 8.0)、`smoothing`(float，建议 5.0)、`enabled`(bool)。
- 硬约束：组件脚本与模板中不得出现 C3 专属字面量（书房/客厅/餐厅/room4 等）；不得依赖相机移动（见 §4.3）。

### 5.4 FloorTemplate（scripts/scenes/FloorTemplate.gd + scenes/floor_template.tscn）

- `extends LevelScene`：沿用 `$Player`、`$Player/Camera2D`、`map_min_x`/`map_max_x`、input_locked 检查、InteractableObject 扫描与 E 键交互（规格⑨）。
- 模板职责：Player 挂点、Environment/Doors/DepthParallax 容器、出生点应用、自动门触发接线（_ready 扫描 AutoDoor 子节点绑定玩家 body 信号，与 LevelScene 扫描 InteractableObject 同风格）。
- 复用性硬约束（规格③）：模板场景/脚本不含 C3 专属内容；房间名称/数量/尺寸/出生点/闭锁门位置全部由实例场景 `c3_floor.tscn` 经导出配置（或实例化房间段）提供。**判定标准：复制 c3_floor.tscn 改名并改配置即可得到下一层（C2/C4/C5 白模），无需改模板脚本。**
- `scenes/c3_floor.tscn` = floor_template.tscn 实例 + 本关配置（三房 640×1080、出生书房、闭锁门客厅中央）。

## 6. 资源路径规范（规格①）

- 首选零贴图：白模几何一律用节点形状（Polygon2D / ColorRect / Line2D 等），不进导入管线。
- 确需贴图时（如门体纹理）：白模占位 PNG 放 `assets/placeholder/`，snake_case 命名、文件名带内容与尺寸（如 `wall_gray_64x1080.png`）；禁止外部/网络素材、禁止真实美术；正式资产未来同名覆盖替换。
- 新脚本目录：`scripts/components/`（跨场景可复用组件，本模块 DepthParallax.gd）。
- 交付物路径汇总：
  - `docs/c3_floor_constraints.md`（本文档，先于代码）
  - `scenes/floor_template.tscn`、`scenes/c3_floor.tscn`
  - `scripts/scenes/FloorTemplate.gd`、`scripts/objects/AutoDoor.gd`、`scripts/objects/LockedBedroomDoor.gd`、`scripts/components/DepthParallax.gd`
  - （可选）`assets/placeholder/**`

## 7. project.godot 改动清单（规格②；改前必须先备份）

**硬约束**：改 project.godot 前先把 `Spine/project.godot` 复制为 `Spine/project.godot.bak`（同目录）；`.bak` 随本模块提交、保留不删；回滚 = 用 `.bak` 覆盖还原。修改既有核心脚本（Player.gd / LevelScene.gd）同样先留 `.bak`。

| 键 | 值 | 目的 |
|---|---|---|
| `display/window/size/viewport_width` | 1920 | 取景帧宽（= 窗口宽） |
| `display/window/size/viewport_height` | 1240 | 取景帧高（= 窗口高） |
| `display/window/size/window_width_override` | 1920 | 固定窗口 1920×1240 |
| `display/window/size/window_height_override` | 1240 | 固定窗口 1920×1240 |
| `display/window/size/resizable` | false | 固定窗口化，禁止缩放 |
| `display/window/stretch/mode` | `canvas_items` | 保底：窗口尺寸异常时内容等比缩放 |
| `display/window/stretch/aspect` | `keep` | 保底：异常尺寸下不变形 |
| `rendering/environment/defaults/default_clear_color` | `Color(0, 0, 0, 1)` | 黑边纯黑（黑边区=清屏色，无场景内容） |

黑边语义（用户定案，见 §12-A3；替代原「窗口缩放副产品」方案）：

- 固定窗口 1920×1240、不可缩放（用户屏幕 2560×1440，窗口内布局完整）。
- 游戏区 1920×1080 垂直居中：y∈[80,1160]；上下各 80px 纯黑边（y∈[0,80]、y∈[1160,1240]）。
- 黑边 = 窗口内**预留文案呈现区**：本模块不实现任何文案内容，只留空（清屏色黑、无场景内容）；黑边区为窗口内 UI 可绘制区域，未来文案层（CanvasLayer）可直接覆盖绘制——本模块不得用场景内容占用或遮挡该区域。
- 保底规则：stretch canvas_items + aspect keep 仅用于异常窗口尺寸下保持内容不变形；常规运行窗口=视口=1:1，无缩放。

## 8. 手感打磨参数表（规格⑩；全部 @export，禁止新增操作）

| 对象 | 参数 | 建议默认 | 说明 |
|---|---|---|---|
| Player.gd（修改，仅加参数） | `move_speed` | 200（保留） | 已有 |
|  | `acceleration` | 1200 | 新增：水平加速（px/s²） |
|  | `ground_friction` | 1600 | 新增：地面减速（px/s²），无输入时减速至 0 |
|  | `gravity` | 980（保留） | 已有 |
| LevelScene.gd / FloorTemplate.gd（修改，仅加参数） | `camera_smoothing` | 6.0 | 相机位置平滑插值系数；0=即时（现状）；不得破坏 clamp 语义与 map_min_x/map_max_x |
| AutoDoor.gd | `trigger_margin` | 40 | 触发区超出门洞的宽度（px） |
|  | `open_duration` | 0.35 | 开门动画时长（s） |
|  | `close_delay` | 0.8 | 离开后延迟关门（s） |
|  | 缓动类型 | EASE_OUT / QUART（建议） | 门体动效 |
| DepthParallax.gd | `mouse_influence` | 8.0 | 鼠标微触发幅度（px，小幅度）；0=关闭 |
|  | `smoothing` | 5.0 | 层偏移平滑 |

- 行为约束：移动仍只有 A/D；速度经加减速逼近 `move_speed`（替代当前瞬时赋值，改善手感）；镜头在本关恒固定取景于 (960,620)（§4.3），`camera_smoothing` 为后续加宽楼层服务。
- 参数默认值为工程建议，可编辑器调整；实现必须 `@export`，评审检查导出性。

## 9. 运行 / 验证入口（不改 main.tscn 空壳）

- `main.tscn` 保持空壳主场景原样（工程启动仍进空壳，符合现状）。
- C3 关直接以场景参数运行（编辑器 F6 亦可）：

```powershell
F:\Godot\godot\godot.exe --path F:\Godot\Spine\Spine res://scenes/c3_floor.tscn
```

- 截图证据目录：`Spine/shots/`（验证任务 t3 产出，≥3 张：全景布局（含上下黑边）、门开启前后、卧室门闭锁）。截图仅作证据、不随模块提交——由集成任务（t5）把 `Spine/shots/` 加入 .gitignore。

## 10. 白模验收标准（对照规格 ①–⑪）

| # | 规格 | 验收标准 | 证据方式 |
|---|---|---|---|
| ① | 全占位符 | 场景无真实美术/外部资产；白模为灰盒/色块（允许少量区分色：墙/地板、木门暖棕灰、闭锁门深灰+标记） | git 文件清单 + 目视截图 |
| ② | 16:9 黑边 | 窗口固定 1920×1240 且不可缩放；游戏区 1920×1080 垂直居中（y∈[80,1160]）；上下各 80px 纯黑预留区（无场景内容、无文案）；project.godot 设置符合 §7 | 1920×1240 运行截图 + project.godot 检查 |
| ③ | 模板化复用 | 模板场景/脚本无 C3 字面量；房间配置数据驱动；复制改配置可做下一层 | Select-String 扫描 + 结构走查 |
| ④ | 三房均分 | 书房/客厅/餐厅各 640×1080（游戏区 y∈[80,1160]）；分隔墙 x=640、x=1280；墙体有碰撞 | 全景截图 + 场景树检查 |
| ⑤ | 木门自动开 | 走近即开（无按键）；开启后可穿过；离开后自动关 | 门开启前后截图对比 + 运行试玩 |
| ⑥ | 出生书房 | Player 出生点 x∈[0,640]（书房） | 入场帧截图 |
| ⑦ | 卧室门闭锁 | 门在客厅中央；E 键无效果；玩家不可穿过；GameState 存 locked；代码无解锁/change_state | 截图 + 交互尝试 + 代码扫描 |
| ⑧ | 景深 | 组件独立可复用；角色移动时层位移按 depth_factor 分级（近大远小）；鼠标移动微幅附加偏移；mouse_influence 导出且 =0 可关闭 | 不同位置/鼠标位置截图对比 + 代码检查 |
| ⑨ | 沿用骨架 | 既有 autoload/脚本语义未破坏；$Player、$Player/Camera2D 路径成立；headless 加载 0 错误 | headless 命令 + diff 走查 |
| ⑩ | 手感参数化 | §8 参数全部 @export；无新输入/新能力 | 代码检查 + 试玩无卡死 |
| ⑪ | 文档先行 | 本文档先于实现代码进入 git | git log --follow 验证 |

## 11. verify 命令清单（实现 t2 与验证 t3 直接使用）

```powershell
# 1 工程整体 headless 加载（退出码 0，无脚本/场景错误）
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine --quit-after 3

# 2 C3 关 headless 加载（退出码 0，无脚本报错）
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/c3_floor.tscn --quit-after 3

# 3 窗口运行 + 黑边验证（固定 1920×1240：上下各 80px 纯黑预留区、游戏区 y∈[80,1160] 垂直居中、窗口不可缩放）
F:\Godot\godot\godot.exe --path F:\Godot\Spine\Spine res://scenes/c3_floor.tscn

# 4 保底规则核对（可选：强行指定窗口尺寸时，canvas_items+keep 应保持内容不变形并留边，仅验证保底设置生效）
F:\Godot\godot\godot.exe --path F:\Godot\Spine\Spine res://scenes/c3_floor.tscn --resolution 1600x1200

# 5 常规运行截图取证（全景布局（含上下黑边）/ 门开启前后 / 卧室门闭锁 → Spine/shots/）
F:\Godot\godot\godot.exe --path F:\Godot\Spine\Spine res://scenes/c3_floor.tscn

# 6 备份与 git 卫生
Test-Path F:\Godot\Spine\Spine\project.godot.bak   # 应为 True（改设置前先备份）
git -C F:\Godot\Spine status --porcelain            # 实现提交后应为空
git -C F:\Godot\Spine log --oneline -3              # 本地提交、英文信息、无 push

# 7 禁区静态扫描（评审使用）
Select-String -Path F:\Godot\Spine\Spine\scripts\objects\LockedBedroomDoor.gd -Pattern 'change_state|unlock|open\('
#   → 不得出现状态切换/解锁/开门调用（interact 空实现；注释文字不计）
Select-String -Path F:\Godot\Spine\Spine\scripts\scenes\FloorTemplate.gd -Pattern '书房|客厅|餐厅|room4|study|living|dining'
#   → 模板不得含 C3 专属字面量（规格③）
Select-String -Path F:\Godot\Spine\Spine\scripts\components\DepthParallax.gd -Pattern 'C3|书房|客厅|餐厅'
#   → 景深组件不得引用 C3 内容（规格⑧复用性）
Select-String -Path F:\Godot\Spine\Spine\scripts\scenes\FloorTemplate.gd,F:\Godot\Spine\Spine\scripts\objects\AutoDoor.gd,F:\Godot\Spine\Spine\scripts\objects\LockedBedroomDoor.gd,F:\Godot\Spine\Spine\scripts\components\DepthParallax.gd,F:\Godot\Spine\Spine\scripts\player\Player.gd,F:\Godot\Spine\Spine\scripts\scenes\LevelScene.gd -Pattern ':= *(clamp|move_toward|lerp|min|max)\('
#   → 显式类型红线（§4.5）：不得从 Variant 内建函数做 := 推断

# 8 文档先行验证（规格⑪）
git -C F:\Godot\Spine log --oneline --follow -- Spine/docs/c3_floor_constraints.md
git -C F:\Godot\Spine log --oneline --follow -- Spine/scenes/c3_floor.tscn
#   → 文档的首次提交不得晚于实现代码的首次提交
```

## 12. 决策记录与剩余假设

已定案（用户拍板，实现按此执行，不得偏离）：

- A1 房间顺序 书房|客厅|餐厅；闭锁卧室门位于客厅中央区域（x≈960）——已确认，按 §4.2 执行。
- A2 木门「离开后自动关」（close_delay 可调、0=立即关）——已确认，按 §5.1 执行。
- A3 黑边定案（替代原「窗口缩放副产品」方案）：**固定窗口化、比例固定**；窗口 1920×1240（用户屏幕 2560×1440）；游戏区 1920×1080 垂直居中（y∈[80,1160]）；上下各 80px 黑边；黑边为窗口内**预留文案呈现区**——本模块不实现文案内容，只预留留空。原 A3「更宽窗口=左右黑边」的论述已废弃。

剩余假设（评审/集成前显式确认）：

- A4 门洞位置（墙中部、通行高度）、门开合方式（滑/转）为实现自由，验收只看「三房均分 + 墙分隔 + 门连通 + 书房出生 + 客厅中央闭锁门」。
- A5 本模块不规定美术/音效/文案（白模不含内容资产）。
