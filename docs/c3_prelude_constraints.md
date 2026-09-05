# C3 前置 5 项：约束文档与验收契约

> 依据：用户 C3 前置 5 项规格（团队任务 t1 描述 ①–⑤）+ 仓库既有约束（docs/c3_floor_constraints.md / docs/item_constraints.md / docs/resource_integration_spec.md）。

> 本文是 C3 前置 5 项的**唯一权威约束**：实现（t2）、验证（t3）、评审（t4）均以本文为准。**硬约定：实现代码产出前先出本文档。**

> **铁律**：不动 scenes/main.tscn（含 player.tscn / project.godot）；调试/验收用场景参数；本地提交、不 push（push 需用户确认）。

> **设计权铁律**：本文只收录用户已明确的 5 项设计，不新增玩法/操作/剧情。凡冒「实现禁区」的条目实现中出现即判 FAIL。


---

## 1. 用户规格原文（5 项前置，必须全部覆盖，不得增删设计）

1. **E 提示**：角色靠近可交互 item 时，头顶显示键盘风格「E」（资产 Kenney Input Prompts，已实测可下载，CC0）。
2. **item 状态机扩展**：附加状态 + 仅指定游戏进程后开启交互 + 特定节点靠近强制触发。需修订旧 item_constraints.md 禁区（UI 提示、item 接全局进程、改 StoryMonitor/GameState——用户新规格授权）。
3. **可配置光影遮罩**：只留出想要的场景；评估 CanvasModulate+Light2D 与挖孔 shader 两方案并定案。
4. **可复用特效组件库**：底色粒子爆炸/震撼、全屏撼动=相机 shake+房间边沿粒子、部分撼动=item 局部；全部参数化快速复用。
5. **卧室通用 room 白模**：与厨房/现有 room 同级结构。
6. **可交互状态标记（ItemMarker 黄色星星）**：item 可交互时显示黄色星星；同房间可远程显示（不要求靠近）；作为单独模块可复用（契约见 §15）。

---
## 2. 工程事实与现有骨架盘点

- 仓库根 `F:\Godot\Spine`；工程根 `F:\Godot\Spine\Spine`（res:// 即此目录）；引擎 Godot 4.7.2（`F:\Godot\godot\godot.exe`，已验证存在）。
- **输入集**（project.godot `[input]`）：move_left / move_right / interact / dialogue_t / dialogue_y。**本模块不新增/删除输入**（E 提示只是视觉显示既有 interact 键，不改造输入映射）。
- **autoload**（project.godot `[autoload]`）：GameState / StoryMonitor / DialogueManager。
- **两套既有可交互体系**（互不继承、并行，本模块必须明确与之关系，见 §10）：
  - **Item**（class_name Item, extends Area2D）：`size: Vector2`（_ready 同步子节点 CollisionShape2D 的 RectangleShape2D）、`current_state: int`、`set_state(new_state:int)`（唯一状态变更入口）、`apply_state(new_state:int)`（唯一效果出口，基类空默认）、`touched()`（E 键触发入口，子类覆写）、`call_item(new_state:int)`（外部指定目标状态，无范围判定、无输入锁）、`_sync_collision_shape()`。
  - **InteractableObject**（class_name InteractableObject, extends Area2D）：`object_id/initial_state/states`、`change_state(state)`（写 GameState.object_states）、`interact()`；LevelScene._ready 用 `find_children("*","InteractableObject")` 扫描并连 body 信号；E 键（LevelScene._unhandled_input 中 `is_action_pressed("interact")`）→ `_overlapping.front().interact()`。
- **Player**（class_name Player, CharacterBody2D）：`signal interact_pressed`；`_physics_process`/`_unhandled_input` 先查 `StoryMonitor.input_locked`（锁定时不移动/不发射）。
- **GameState**（autoload）：`object_states: Dictionary`（key=object_id, value=state）+ JSON 存档（user://savegame.json）；`set_object_state/get_object_state/save_game/load_game/state_changed`。
- **StoryMonitor**（autoload）：`trigger_table`（留空 TODO）、`triggered_ids`、`input_locked`、`lock_input/unlock_input`、`_on_state_changed`（TODO 空）。
- **LevelScene / FloorTemplate**：地图边界 map_min_x/map_max_x + 相机水平 clamp；InteractableObject 扫描；FloorTemplate 额外出生点应用、相机取景偏移、自动门接线、景深目标。c3_floor.tscn 实例化 FloorTemplate，配置三房（书房|客厅|餐厅，宽 3840，2.35:1），含墙体 WallStudyLiving/WallLivingDining、自动门 AutoDoorStudyLiving/AutoDoorLivingDining、LockedBedroomDoor（客厅中央），DepthParallax 三层视差。
- **DepthParallax**：可复用景深组件（Node2D，子节点 metadata `_depth_factor` 配深度；无房间名/关卡字面量）。这是本仓库「可复用组件」的既有范例（§8 特效库/§7 遮罩沿用该设计哲学）。
- **现状缺口（影响 §7/§8 设计）**：对 scripts/scenes/ui 全库 grep，**无任何 shader / CanvasModulate / Light2D / LightOccluder / 粒子节点**——光影遮罩与特效库为全新引入，需在「白模 Polygon2D 场景」下给出可行性依据。
- 命名/编码惯例（沿用 c3 §4.4/§4.5）：节点名 PascalCase；脚本文件名与 class_name 一致（PascalCase）；场景文件名 snake_case；私有成员 `_` 前缀；信号 snake_case；`.gd` 用 class_name。**编码红线**：禁止用 `:=` 从返回 Variant 的内建函数推断类型（clamp / move_toward / lerp / min / max / smoothstep 等），一律显式标注（如 `var x: float = clamp(...)`）。`.tscn` 导出属性写在 `script=` 之后（Godot 惯例）。改既有脚本前先留同目录 `.bak`（仓库惯例，硬约束）。
- 白模惯例：零贴图，节点形状（Polygon2D / ColorRect）占位；`Spine/shots/` 为验证截图证据目录（已在 .gitignore）。

---
## 3. 旧 item_constraints.md 禁区修订清单（逐条）

> 下列「旧禁区」来自 docs/item_constraints.md §3（item 模块的 out-of-scope）。本 C3 前置模块是**新模块**，以 §4 的 In/Out of scope 为最终边界；本表仅说明「哪些旧禁区被用户新规格授权解除」。结论：REVISED=授权解除，REMAINS=保持禁用。
> **注**：item_constraints.md §8 曾明确「item 不写 GameState、不触发剧情」，该 §8 文案在本规格后**过时**（进程旗标读取已授权）；实现时如需更新该文档以保持库内一致，属允许的文档修缮（不属本模块改动边界，但建议随 t2 更新）。

| 旧禁区（item_constraints.md §3，出现即 FAIL） | 修订结论 | 修订依据 / 新约束 |
|---|---|---|
| 无 UI 提示 | **REVISED** | 本模块新增 **E 提示**（UI 提示）——仅在 item 靠近时显示键盘风「E」。仍不新增玩法/操作（纯视觉提示）。 |
| item 状态不写 GameState、不参与存档 | **REVISED（部分）** | item 现需**读取**全局进程状态作交互 gate（§6.1）。item **仍不写** GameState.`object_states`（那是 InteractableObject 的存档），仅依赖新增的 `process_flags` 读取做门控。 |
| 不改 GameState.gd / StoryMonitor.gd / 其他既有脚本 | **REVISED** | GameState 需新增 `process_flags` 读写（§6.1）。**StoryMonitor 本阶段保持不改**（gate 由 item 直接读 GameState，不走 StoryMonitor.`trigger_table`；其 `trigger_table` 仍留空）。 |
| 不改 project.godot（输入集保持三项） | **REVISED（部分）→ 结论：project.godot 不改** | **`[input]` 不改**（E 提示是视觉）。**`[autoload]` 不改**：进程状态源采用「扩展既有 GameState autoload」，特效库采用组件式（§8.4），均不新增 autoload。故本模块 **project.godot 保持不动**。 |
| 不改 main.tscn / main_scene.tscn / level_scene.tscn / player.tscn | **REMAINS** | 铁律不动 main.tscn；其余保持不动。E 提示经 item 自身 Area2D `body_entered/body_exited` 驱动，**不依赖 Player / LevelScene 改动**。player.tscn 不改。 |
| 不改 InteractableObject.gd | **REMAINS** | 两体系并行；本模块不触碰 InteractableObject.gd（E 提示组件是通过「挂载到其场景」复用，而非改其脚本）。 |
| 无新输入/新操作/新玩法 | **REMAINS** | 5 项均为既有要素的参数化/视觉化扩展，不新增输入、操作、玩法设计。 |
| 无外部资产 | **REVISED** | E 提示使用 Kenney Input Prompts（CC0，已实测可下载）。需落盘 assets/ + CREDITS.md 许可台账（§5.4）。 |
| 无音效/真实美术/文案内容 | **部分 REVISED** | 引入 Kenney 按键图标（真实资产，CC0）+ 白模 Polygon2D 占位。文案内容本模块仅 UI 提示 / 交互辅助类（可空或极简）；**音效不在本模块范围**（特效库为粒子+shake，不含音频）。 |
| push | **REMAINS** | 本地提交、不 push（push 需用户确认）。 |

---
## 4. 模块边界

**In scope（实现任务 t2 的改动范围；本文档只定义、不改动）**

- 新增：`scripts/components/InteractHint.gd`、`scripts/components/DarknessMask.gd`（+`scripts/components/darkness_mask.gdshader`）、`scripts/components/ScreenShake.gd`、`scripts/components/ItemShake.gd`、`scripts/components/ParticleBurst.gd`、`scripts/components/ItemMarker.gd`、`scripts/components/RoomTable.gd`；
- 修改（扩展，非重写）：`scripts/objects/item.gd`（gate / 附加状态 / force-trigger）+ 同目录 `item.gd.bak`；`scripts/autoload/GameState.gd`（process_flags）+ 同目录 `GameState.gd.bak`；
- 新增（实现任务内）：`scenes/` 下各演示/白模场景（E 提示演示、光影遮罩演示、特效演示、`room_bedroom_whitemodel.tscn`）；
- 新增：`assets/ui/` Kenney 按键图标（+`*.import`）、`docs/CREDITS.md`（许可台账）；
- 证据（不随模块提交）：`Spine/shots/*`（.gitignore）。

**Out of scope / 实现禁区（违反即 FAIL）**

- 不动 `scenes/main.tscn`（铁律）、`main_scene.tscn`、`player.tscn`、`project.godot`；
- 不改 `InteractableObject.gd` / `LevelScene.gd` / `StoryMonitor.gd` / `DepthParallax.gd` / `AutoDoor.gd` / `LockedBedroomDoor.gd` / `FloorTemplate.gd` / `MainScene.gd` / `DialogueBox.gd`（既有脚本本模块不动）；
- 不新增/删除输入映射（`[input]` 不变）；不新增 autoload（`[autoload]` 不变）；
- item 状态**不写 GameState.`object_states`**、不调用 `InteractableObject.change_state()`、不触发既有 InteractableObject 链路（两体系并行，§10）；
- 不新增玩法/操作/剧情；无音效；无真实美术（Kenney 按键图标除外，属授权资产）；
- push（本地提交、不 push）。

---
## 5. ① E 提示契约

### 5.1 目标
角色靠近可交互 item 时，item 头顶显示键盘风「E」；离开即隐藏。纯视觉提示，不新增操作。

### 5.2 信号流（item 驱动，零 Player / LevelScene 改动）
item 与 InteractableObject 均为 Area2D，天然带 `body_entered`/`body_exited`：

```
Player 进入 item 的 CollisionShape2D → item.body_entered(player) → InteractHint.show_hint()
Player 离开 item 的 CollisionShape2D → item.body_exited(player)  → InteractHint.hide_hint()
```

- 触发源：item 自身 Area2D 的 `body_entered`/`body_exited`，判定 `body is Player`（class_name Player 已存在）。
- 监听方：`InteractHint` 组件（挂为 item 子节点）。
- **可复用性**：InteractHint 挂到 **Item 或 InteractableObject** 皆可（二者皆 Area2D、皆可判 `body is Player`）——E 提示对两套体系通用。

### 5.3 UI 组件结构（InteractHint，Node2D）
```
InteractHint (Node2D; script = scripts/components/InteractHint.gd)   # 默认 visible=false
└─ Visual (Sprite2D 或 Label)    # 键盘风「E」；有 hint_texture 用 Sprite2D，否则 Label 白模占位
```

- 参数（全部 @export）：
  - `@export var hint_texture: Texture2D`：Kenney「E」图标；**空 = Label 白模占位**（显示文本 "E"，零资产）。
  - `@export var head_offset: Vector2 = Vector2(0, -70)`：头顶上方偏移（相对 item 中心，白模按 size 可调）。
  - `@export var scale_factor: float = 1.0`（命名避开 Node2D 内建 `scale` 属性，避免遮蔽 Godot 节点缩放——原稿写作 `scale`，实现更名 `scale_factor`）；`@export var fade_duration: float = 0.15`（淡入淡出；0=即时）。
- 行为：`_ready()` 取父 Area2D `owner_area`，连接 `body_entered`/`body_exited`，判 `body is Player` → `show_hint()`/`hide_hint()`。**组件自接线，零配置**（符合 DepthParallax 可复用哲学）。
- `func show_hint() -> void` / `func hide_hint() -> void`：切 visible + 可选 Tween 淡入淡出。
- 额外手动接口 `func set_visible_forced(v: bool) -> void` 供流程直接控制（如 gate 未满足时隐藏）。

### 5.4 Kenney 资产方案与许可台账要求
- 资产：Kenney **Input Prompts** pack（键帽/键盘图标，含「E」）。来源 https://kenney.nl/assets/input-prompts（已实测可下载；**CC0**）。具体 zip 下载/校验（HTTP 码/大小/魔数）由 godot-asset-sourcing 渠道矩阵执行，实现在 t2。
- 落盘：仅拷贝用到的图标到 `res://assets/ui/e_key.png`（+`e_key.png.import`）——**避免整包入库**（体积/许可清晰）。
- 许可台账：新建/更新 `docs/CREDITS.md`，记录资产名（Kenney Input Prompts）、来源 URL、许可（CC0）、作者（Kenney）、用途（C3 前置 E 提示）。CC0 免署名，但本模块统一建立台账以资可追溯（godot-asset-sourcing 规范：外部资产必核许可并联证）。
- **红线**：E 提示图标为唯一新外部资产；**不打新输入映射**（纯视觉，interact 键已存在）；`.import` 随源文件提交（仓库惯例）。

### 5.5 验收（E 提示）
- 靠近（body_entered, body is Player）→ 显示；离开（body_exited）→ 隐藏。
- InteractHint 可挂 Item 与 InteractableObject 各一（复用性，演示场景两节点验证）。
- 参数齐全（hint_texture / head_offset / scale_factor / fade_duration）；无纹理时 Label 白模仍可显示「E」。
- Kenney 资产落盘 assets/ui + `.import` + CREDITS.md。

---
## 6. ② item 状态机扩展契约

### 6.1 进程状态源设计（定案：扩展 GameState，不新增 autoload）
- **定案**：在 `GameState`（既有 autoload）新增**独立过程旗标子字典** `process_flags: Dictionary`（≠ `object_states`），提供：
  - `func set_process_flag(name: String, value: bool) -> void`：写 `process_flags[name] = value`（随后可存存档）。
  - `func get_process_flag(name: String) -> bool`：缺省 `false`。
  - `save_game()/load_game()` 增写/增读 `process_flags`（向后兼容：旧存档无该键 → 默认 `{}`）。
- **与既有 InteractableObject 链路并存关系**：`process_flags` 与 `object_states` 是两个**独立字典**，互不读写；`set_object_state/get_object_state/state_changed` 语义与存档格式不变（object_states 仍为既有 JSON 主结构，process_flags 追加为并列键）。
- **为何不新增 autoload**：规避修改 project.godot `[autoload]`；复用既有 JSON 存档；与既有全局状态同源、语义集中。
- **gate 语义**：进程旗标由 **C3 流程（阶段二）** 设置（如 `exam_completed`、`oxygen_ok`）；本模块**只定义 Item 的读取 gate 接口，不实现流程写入**（阶段二玩法规格再定旗标名/时序，见 §14-J3）。

### 6.2 Item 基类扩展（scripts/objects/item.gd 增补，改前先留 item.gd.bak）
在**不破坏**既有 Item API（TestItem 现行为不变）前提下新增：

- `@export var gate_flag: String = ""`：非空时，`touched()` 交互前先查 `GameState.get_process_flag(gate_flag)`；不满足 → **不触发**（发射 `gate_blocked` 信号，供 UI/特效/E 提示联动）。空 = 无 gate（兼容 TestItem 现行为）。
- `@export var initial_state: int = 0`：`_ready` 置 `current_state = initial_state`（现行为默认 0）。
- `@export var states: Dictionary = {}`：状态→配置表，键 int，值 `{position?: Vector2, size?: Vector2, color?: Color, texture?: String}`；基类 `apply_state(new_state:int)` **默认实现**按 `states.get(new_state, {})` 应用（如同 InteractableObject，但 int 键、仅影响本 item，**不写 GameState**）。**子类仍可覆写 `apply_state` 整段覆盖**（如 TestItem 的 Tween 到位置）。
- `signal interaction_available(enabled: bool)`：gate 满足/不满足时发射（供 E 提示 / 遮罩 / 特效联动）。
- `signal gate_blocked`：gate 未满足、交互被阻止时发射。
- `@export var force_trigger_node: NodePath` + `@export var force_trigger_state: int = -1`：
  - **强制触发**：玩家进入 `force_trigger_node`（一个定位触发区的 Node2D/Area2D）时，**无视 gate / 输入锁**，调用 `call_item(force_trigger_state)`。
  - 实现：`_ready` 解析 `get_node_or_null(force_trigger_node)`；若是 Area2D，连接其 `body_entered` 判 `body is Player` → `call_item(force_trigger_state)`。`force_trigger_state < 0` 时忽略。
- `func set_interaction_enabled(enabled: bool) -> void`：外部门控（流程可调用）。`touched()` 前先查；`enabled=false` 时不触发。与 `gate_flag` 可并用（`enabled=false` 优先）。
- `func is_interaction_available() -> bool`：当前是否可交互（交互开关开启 AND gate 满足），供 ItemMarker 等门控联动只读读取。
- `func _try_touch() -> bool`：gate/交互开关检查**通过后**才被 `touched()` 调用；**新子类应覆写 `_try_touch()` 而非 `touched()`**（直接覆写 `touched()` 会绕过上述 gate 门控链路，如早期 TestItem）。

### 6.3 切换 / 触发路径图（扩展后）
```
E 键(interact) → Player.interact_pressed ─→ Item.touched()
                                          │ ① 输入锁（input_locked，Player 侧已挡）
                                          │ ② set_interaction_enabled(false) → 发射 interaction_available(false)，不触发
                                          │ ③ gate_flag 非空且 get_process_flag=false → 发射 gate_blocked + interaction_available(false)，不触发
                                          ▼ 通过
                          set_state(new_state)    ← 唯一状态变更入口
                                          │ current_state = new_state
                                          ▼
                          apply_state(new_state)  ← 唯一效果出口（基类查 states 表；子类可覆写）

外部程序化 ─→ call_item(new_state) ─→ set_state(new_state)   （无 gate / 无输入锁，外部显式指定目标状态）

特定节点靠近(force_trigger_node body_entered, body is Player) ─→ call_item(force_trigger_state)  ← 强制触发，无视 gate
```
（任何绕过 set_state 的直接 current_state 赋值 = FAIL。）

### 6.4 验收（item 门控/强制触发）
- `gate_flag`：process flag 未满足时 `touched()` 不改变状态（发射 `gate_blocked`）；满足后正常触发。
- `set_interaction_enabled(false)` 阻止交互；`true` 恢复。
- `force_trigger_node` 靠近时强制触发 `call_item(force_trigger_state)`（无视 gate）。
- `states` 表驱动 `apply_state`（默认实现查表）；既有 TestItem（无 gate/force_trigger/states 配置）行为不变（回归）。
- `GameState.process_flags`：set → get；set → save → load → get 往返一致；旧存档（无 process_flags 键）加载不报错。

---
## 7. ③ 可配置光影遮罩契约（两方案评估 + 定案）

### 7.1 需求
「只留出想要的场景」——把非目标区域压暗/隐藏，只让**玩家所在/想要的 scene** 可见；用于 C3 光影切换（阶段二）与聚焦。参数化、可复用、白模可用。

### 7.2 方案 A：CanvasModulate + Light2D + LightOccluder2D
- 原理：`CanvasModulate.color = 深色` 把整张画布乘暗；`PointLight2D`（需径向渐变 texture）在 light canvas layer 照亮「想要的区域」；`LightOccluder2D` 挂在障碍物上形成遮挡/挖孔。
- 优点：Godot 原生光系统；天然软边；真实遮挡（可做门缝/窗光）。
- 缺点（**白模 Polygon2D 场景下**）：需为每个遮挡体挂 `LightOccluder2D`（Polygon2D 色块需转 occluder 多边形），白模节点多（DepthParallax 三层 + 多 StaticBody2D 色块 + 门）、配置重；`PointLight2D` 内建**无软光纹理**，需一张 radial 渐变（GradientTexture2D 或外部纹理）；「只留想要的区域」= 光形状+遮挡组合，控制粒度粗、参数多；与二层视差/多白模耦合需逐层处理。**可配置性弱，不满足「快速复用」目标**。
- **白模 Polygon2D 可行性依据**：可行但**重**——逐节点挂 occluder + 每灯配纹理，维护成本高。

### 7.3 方案 B：挖孔 canvas_item shader（视口矩形遮罩）
- 原理：一个覆盖视口的 `ColorRect/Polygon2D` 挂 `ShaderMaterial`（`.gdshader`），`FRAGMENT` 中按 UV 到 `center` 的距离计算遮罩 alpha，形成「亮区（挖孔）+ 暗区（遮罩）」：
  - `uniform vec2 center;`（挖孔中心 UV；由脚本每帧传全局位置换算——跟随玩家/指定点）
  - `uniform float inner_radius;`（全亮半径）/ `uniform float outer_radius;`（全暗半径；其间软过渡）
  - `uniform vec4 darkness_color;`（遮罩颜色=黑/深色+alpha）；`uniform float softness;`（边缘软度；0=硬边）；`uniform bool enabled;`
  - `COLOR = vec4(darkness_color.rgb, darkness_color.a * mask);`；`mask = 1.0 - smoothstep(inner_radius, outer_radius, dist);` → 孔内 mask=0（透出场景），孔外 mask=1（遮罩）。
- 优点：**零遮挡几何**（不依赖每个 polygon 的 occluder）；参数集中在几个 uniform，**可配置性强**；跨纹理/纯色块通用（白模与正式场景皆用）；中心可传全局坐标（跟随玩家/相机）；**一个节点一个材质，复用性高**（封装为 DarknessMask 组件）。
- 缺点：需写 `.gdshader` + 让遮罩矩形随视口/相机走（CanvasLayer 或每帧更新全局位置）；不区分物体遮挡（只做圆形软边挖孔）；若要真实光感（窗光/色温）须升级方案 A。
- **白模 Polygon2D 场景可行性依据**：**高**。遮罩仅需一个全视口矩形 + shader，**覆盖 DepthParallax 多层、白模色块、玩家**；无需为任何白模节点加 occluder；`center` 随玩家/相机传 UV 即实现「只留玩家所在区域」。**与现白模结构零冲突**。

### 7.4 定案
**采用方案 B（挖孔 canvas_item shader）**，封装为 `DarknessMask` 组件：
- `scripts/components/DarknessMask.gd`（Node2D，内部一个全视口 `ColorRect` 挂 `ShaderMaterial`（`scripts/components/darkness_mask.gdshader`）+ 可选 `CanvasLayer`）。
- 导出参数：`center_global: Vector2`（挖孔中心全局坐标，默认跟随玩家/可手指定）、`follow_player: bool = true`、`radius_inner: float`、`radius_outer: float`、`darkness_color: Color`、`softness: float`、`enabled: bool`、`layer: int`（CanvasLayer 层级，**默认 1**——置于默认画布内容之上，遮罩才能压暗场景并挖孔显示；原稿写作 -9 因处于默认画布之后会整块被遮挡而不可用，实现更改为 1；如需置于特效之前/之后可再调）。
- 复用：一个 DarknessMask 挂到任意 LevelScene/FloorTemplate 即启用；参数可**运行时改**（供 C3「光影切换」：切换 center/radius/颜色/开合）。可通过组 `fx_darkness` 或信号由流程控制。
- 说明：方案 A 记为「真实光感后期升级路径」，本阶段不采用。

### 7.5 验收（光影遮罩）
- DarknessMask 用**白模 Polygon2D 场景**（c3_floor 或演示场景）：headless 加载 0 错误；shader 无解析错误。
- 窗口运行：遮罩覆盖非目标区、挖孔区显示场景；`follow_player` 时「只留玩家所在区域」；参数（radius/color/softness/enabled）改动即时生效；`enabled=false` 时完全透明。
- 可行性依据：已给出上述「白模 Polygon2D」论证（§7.3）。

---
## 8. ④ 可复用特效组件库契约

### 8.1 目标
三类特效、全部参数化、可跨场景复用：
1. **底色粒子爆炸/震撼**（colored particle burst / shock）
2. **全屏撼动** = 相机 shake + 房间边沿粒子（camera shake + room-edge particles）
3. **部分撼动** = item 局部（item-local shake）

### 8.2 组件设计（scripts/components/，均不含房间/关卡字面量，同 DepthParallax 先例）
- **ParticleBurst.gd**（Node2D，内含 `GPUParticles2D` 或纯节点驱动）：
  - 导出：`amount`、`color`、`lifetime`、`spread`、`initial_velocity`、`gravity`、`size`、`emitting`；
  - `func burst() -> void`：一次性（one_shot）发射后复位/清理；`func set_color(color: Color)`。作用：底色粒子爆炸（随机方向彩点），用于「震撼/碎裂」感。
- **ScreenShake.gd**（挂为 Camera2D 子节点或独立驱动相机）：
  - 导出：`amplitude: float`（px）、`frequency`、`duration`、`attenuation`；
  - `func shake(amp: float = 0.0, dur: float = 0.0) -> void`：随机偏移 + 衰减（Tween 或 `_process`）驱动相机 offset，结束后归零。语义 = **全屏撼动**。
- **ItemShake.gd**（Node2D 子节点）：
  - 导出：`amplitude`、`duration`、`axis`（x/y/both）、`flip_random`；
  - `func shake(amp: float = 0.0, dur: float = 0.0) -> void`：仅作用于挂载节点的局部偏移/旋转，结束后归位。语义 = **部分撼动**（item 局部）。
- **复用入口**：组件挂到任意 Node2D/Area2D/Camera2D，方法触发（宿主/流程 call）+ 场景内联信号连接（item 的 `gate_blocked`/`interaction_available`、DarknessMask 切换信号 → 连到 `shake`/`burst`），脚本零耦合（同仓库惯例）。

### 8.3 全屏/部分撼动组合与触发
- **全屏撼动** = `ScreenShake.shake()`（驱动相机）+ 房间边沿 `ParticleBurst.burst()`（在房间四周放置粒子，事件时发射）——由流程/事件触发。
- **部分撼动** = `ItemShake.shake()`（item 局部）。
- 触发例（示意）：item `gate_blocked` → 小幅度 `ItemShake.shake()`；流程「空气变暗/切换」→ `ScreenShake.shake()` + 房间边沿 `burst()`。

### 8.4 触发入口与全局可及性（定案：组件式，不新增 autoload）
- **定案**：特效库为**组件式**（挂到对应节点，方法触发 + 场景内联信号连接），**不新增 `Fx` autoload**（遵循「project.godot `[autoload]` 不动」）。
- 相机全局访问：`ScreenShake` 作为 `Player/Camera2D` 或关卡根的**子节点**挂载，由触发方通过组 `fx` 查找并调用，或由 FloorTemplate 暴露 `@onready var screen_shake` 供子流程用。
- **备选（记录、不默认启用）**：若工程师确需「全局一键触发」，可新增 `Fx` autoload——需改 project.godot `[autoload]` + `project.godot.bak`；**实现前须 captain / 用户确认**（本模块不默认启用，避免触碰 project.godot 铁律面）。

### 8.5 验收（特效库）
- 三组件参数导出齐全；headless 加载含特效的演示场景 0 错误。
- 窗口运行：`burst()` 发射底色粒子；`screen_shake.shake()` 相机偏移后回位；`item_shake.shake()` 局部偏移后回位。
- 复用性：组件可挂到任意 Node2D/Area2D/Camera2D（不含房间名/关卡字面量），同 DepthParallax 先例。
- 组合：全屏撼动（screen_shake + 房间边沿 burst）与部分撼动（item_shake）可分别触发。

---
## 9. ⑤ 卧室通用 room 白模契约

### 9.1 目标
一个**通用卧室 room 白模**（单间房间单元），与既有房间/层**同级结构**，供阶段二 C3 卧室结局复用。

### 9.2 结构契约（self-contained 单间场景）
```
res://scenes/room_bedroom_whitemodel.tscn
Room (Node2D; script = scripts/scenes/RoomBase.gd，可选)
├─ Floor / Ceiling             # StaticBody2D + CollisionShape2D + Polygon2D 色块（白模零贴图）
├─ WallLeft / WallRight        # 同上（房间侧墙）
├─ Door (AutoDoor 实例，可选)   # 房间入口自动门（复用既有 AutoDoor）
└─ (可选) InteractHint / ItemShake / ParticleBurst   # 特效/交互挂点，复用既有组件
```

- **参数化**（`RoomBase.gd` @export）：`room_width`、`wall_height`、`stand_surface_y`（站立面，默认 y=988，碰底留 8px，F5 教训）、`floor_color/wall_color`、`door_pos`、`spawn_pos`、`door_enabled`。
- **与现有层的关系**：现有层（c3_floor.tscn 等）把房间当「层环境的一部分」（墙体/门为 Environment/Doors 子节点，非独立房间场景）；**卧室白模升级为「整间是独立房间场景单元」**，可在任意层实例化——**「与厨房/现有 room 同级结构」＝每个房间是独立可复用场景单元**（而非硬编码进层）。
- 白模约定：零贴图，Polygon2D 色块；节点 PascalCase；含 Player 出生点（实例化层可覆盖 `spawn_pos`）；站立面 y=988 惯例；Player 出生 (x, 948)（碰底 8px）。

### 9.3 验收（卧室 room 白模）
- `room_bedroom_whitemodel.tscn` 独立加载（headless）0 错误。
- 房间尺寸/颜色/门/出生点导出可配（参数化）。
- 与现有层同级/兼容：可作为 C3 层的一个房间实例化（不依赖层内硬编码）。
- 白模零贴图；含 Player 出生点；站立面 y=988。

---
## 10. 与既有体系的关系（并行不冲突）

- **Item 体系**（E 提示/gate/强制触发/局部特效）**不继承、不触碰** `InteractableObject.gd` / `LevelScene.gd` / `StoryMonitor.gd`（除 GameState 增 `process_flags` 外，不写 `object_states`、不掉 `InteractableObject.change_state()`）。
- **进程旗标**（GameState.`process_flags`）与 `object_states` 并存、互不读写；`StoryMonitor` 仍只监听 `state_changed`（本模块不改 StoryMonitor）。
- **E 提示**组件对 Item 与 InteractableObject 通用（两者皆 Area2D，组件自接线 body 信号）。
- **特效组件 / 光影遮罩 / 卧室 room 白模**均为**新增可复用组件/场景**，无跨体系状态，按组件挂载复用。
- **不改动任何既有场景结构/脚本逻辑**（§4 禁区）。

---
## 11. 交付清单（实现 t2）

- `docs/c3_prelude_constraints.md`（本文档，先于实现代码）
- `scripts/components/InteractHint.gd`、`scripts/components/ScreenShake.gd`、`scripts/components/ItemShake.gd`、`scripts/components/ParticleBurst.gd`、`scripts/components/DarknessMask.gd`、`scripts/components/darkness_mask.gdshader`、`scripts/components/ItemMarker.gd`、`scripts/components/RoomTable.gd`（+`*.uid`）
- `scripts/objects/item.gd`（gate / 附加状态 / force-trigger）+ `item.gd.bak`；可选 `scripts/objects/<c3_item>.gd` 子类
- `scripts/autoload/GameState.gd`（process_flags）+ `GameState.gd.bak`
- `scenes/`：E 提示演示场景、光影遮罩演示场景、特效演示场景、`room_bedroom_whitemodel.tscn`
- `assets/ui/` Kenney「E」图标（+`*.import`）；`docs/CREDITS.md`（许可台账）
- （证据，不随模块提交）`Spine/shots/*`

---
## 12. 验收标准表 A（对照 ①–⑥）

| # | 规格 | 验收标准 | 证据方式 |
|---|---|---|---|
| ① | E 提示 | InteractHint 组件；item 靠近(body_entered)显示、离开(body_exited)隐藏；可挂 Item 与 InteractableObject；参数齐全（texture/head_offset/scale_factor/fade）；无纹理时 Label 白模可显示；Kenney 资产落盘 assets/ui + CREDITS.md | 代码走查 + headless 加载 + 窗口运行读回 + 截图 |
| ② | item 状态机扩展 | GameState.`process_flags` 读写+存档往返（向后兼容）；Item.`gate_flag` 满足/不满足分支（`gate_blocked`）；`set_interaction_enabled`；`force_trigger_node` 强制触发（无视 gate）；`states` 表驱动 apply_state；既有 TestItem 行为不变 | 代码走查 + Select-String + headless 自检 + 运行 |
| ③ | 光影遮罩 | DarknessMask（挖孔 canvas_item shader）；参数 center/radius/color/softness/enabled；白模场景加载 0 错误；`follow_player` 时「只留玩家所在区域」；方案 B 定案 + 白模可行性依据 | headless 加载 + 窗口运行截图 + 代码走查 |
| ④ | 特效库 | ParticleBurst/ScreenShake/ItemShake 组件、参数齐全、方法触发；全屏撼动=screen_shake+房间边沿burst；部分撼动=item_shake；组件可复用（无房间/关卡字面量） | headless 加载 + 窗口运行读回 + 截图 |
| ⑤ | 卧室 room 白模 | `room_bedroom_whitemodel.tscn` 独立加载 0 错误；尺寸/颜色/门/出生点可配；白模零贴图；站立面 y=988；可与现有层同级实例化 | headless 加载 + 场景树检查 + 截图 |
| ⑥ | 可交互状态标记 | ItemMarker 组件：交互可用(interaction_available/gate 满足)→显示黄色星星，不可交互隐藏；同房远程可见(不要求靠近)；独立可复用(挂 item 子节点, 参数化 color/size/room_id/room_table)；白模 Polygon2D 星形, 零外部依赖 | 代码走查 + headless 读回 + 运行 + 截图 |

---
## 13. T2 verify 命令清单（实现 t2 / 验证 t3 直接使用）

```powershell
# ── 步骤一 文档先行 + 静态扫描 + 备份核对 ──
git -C F:\Godot\Spine log --oneline --follow -- Spine/docs/c3_prelude_constraints.md
git -C F:\Godot\Spine log --oneline --follow -- Spine/scripts/objects/item.gd
#   → 文档首次提交必须早于实现代码首次提交
Test-Path F:\Godot\Spine\Spine\scripts\objects\item.gd.bak          # True（改 item.gd 前已备份）
Test-Path F:\Godot\Spine\Spine\scripts\autoload\GameState.gd.bak   # True（改 GameState.gd 前已备份）
Get-ChildItem F:\Godot\Spine\Spine\scripts\components\*.gd | Select-Object -ExpandProperty Name
#   → 含 InteractHint.gd / DarknessMask.gd / ScreenShake.gd / ItemShake.gd / ParticleBurst.gd
Test-Path F:\Godot\Spine\Spine\scenes\room_bedroom_whitemodel.tscn   # True

# 编码红线：禁止 := 推断 Variant 内建函数返回类型
Select-String -Path F:\Godot\Spine\Spine\scripts\components\*.gd,F:\Godot\Spine\Spine\scripts\objects\item.gd,F:\Godot\Spine\Spine\scripts\autoload\GameState.gd -Pattern ':= *(clamp|move_toward|lerp|min|max|smoothstep)'
#   → 无输出

# 禁区扫描：item 不得写 object_states / 不得触碰 InteractableObject 链路
Select-String -Path F:\Godot\Spine\Spine\scripts\objects\item.gd -Pattern 'object_states|set_object_state|change_state|InteractableObject'
#   → 无输出（并行体系；gate 只读 GameState.get_process_flag）

# 禁区扫描：StoryMonitor 保持不改（本模块不动）
Select-String -Path F:\Godot\Spine\Spine\scripts\autoload\StoryMonitor.gd -Pattern 'process_flag'
#   → 无输出

# ── 步骤二 工程整体 headless 加载 ──
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine --quit-after 3
#   → exit 0；stdout 无 SCRIPT ERROR / ERROR / Parse Error

# ── 步骤三 各演示/白模场景 headless 加载 + 自检读回 ──
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/<e_hint_demo>.tscn --quit-after 3
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/<darkness_demo>.tscn --quit-after 3
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/<fx_demo>.tscn --quit-after 3
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/room_bedroom_whitemodel.tscn --quit-after 3
#   → 各 exit 0，stdout 无脚本错误；组件含 SELF-CHECK 时看 PASS

# 资产断言：Kenney「E」图标存在 + .import 存在 + 许可台账
Test-Path F:\Godot\Spine\Spine\assets\ui\e_key.png          # True
Test-Path F:\Godot\Spine\Spine\assets\ui\e_key.png.import   # True
Test-Path F:\Godot\Spine\Spine\docs\CREDITS.md              # True
Select-String -Path F:\Godot\Spine\Spine\docs\CREDITS.md -Pattern 'Kenney|CC0'
#   → 命中

# ── 步骤四 窗口运行 + 交互读回 + 证据 + git 卫生 ──
F:\Godot\godot\godot.exe --path F:\Godot\Spine\Spine res://scenes/<fx_demo>.tscn
#   → E 提示：靠近显示/离开隐藏；gate：flag 未满足不触发、满足后触发；force-trigger：关近强制触发
#   → 光影遮罩：只留目标区域；特效：burst / screen_shake / item_shake 触发
#   → 截图证据 → Spine/shots/（.gitignore）
git -C F:\Godot\Spine diff --stat -- Spine/scenes/main.tscn Spine/scenes/player.tscn Spine/project.godot
#   → 无输出（铁律：main.tscn / player.tscn / project.godot 未改；若见 [input]/[autoload] 改动 → FAIL）
git -C F:\Godot\Spine status --porcelain   # 实现提交后应为空
git -C F:\Godot\Spine log --oneline -3     # 本地提交、英文信息、无 push
```

---
## 14. 决策记录与剩余假设

**已定案（实现按此执行，不得偏离）：**

- D1 光影遮罩 = 方案 B（挖孔 canvas_item shader，DarknessMask 组件）——理由（白模可行性/可配置性）见 §7；方案 A 记为真实光感后期升级路径。
- D2 进程状态源 = 扩展 GameState（新增 `process_flags`），不新增 autoload、不动 project.godot、不动 StoryMonitor；与 `object_states` 并存互不读写。
- D3 E 提示 = InteractHint 组件，自接线父 Area2D 的 body_entered/body_exited（判 body is Player），对 Item/InteractableObject 通用。
- D4 特效库 = 组件式（ParticleBurst/ScreenShake/ItemShake），不新增 `Fx` autoload；Fx autoload 为备选（需改 project.godot，须用户确认）。
- D5 卧室 room 白模 = 独立房间场景单元（room_bedroom_whitemodel.tscn），可复用实例化。
- D6 item 扩展 = gate_flag / initial_state / states / force_trigger_node / force_trigger_state / set_interaction_enabled / interaction_available / gate_blocked，不破坏既有 Item API（TestItem 现行为不变）。
- D7 资产 = Kenney Input Prompts（CC0）落盘 `assets/ui/e_key.png` + `docs/CREDITS.md` 许可台账。
- D8 可交互状态标记(⑥) = ItemMarker 组件，房间判定**定案 = 场景级房间区间表**（RoomTable, room_id→x 区间，见 §15.3）；与 InteractHint 靠近逻辑独立、不新增玩法；不侵入 item.gd / InteractHint.gd（只读 interaction_available）。

**剩余假设（评审/集成前显式确认；均来自仓库既有约定或规格字面，无新增玩法设计）：**

- J1 卧室 room 白模「与厨房/现有 room 同级结构」：仓库现状未见独立厨房/room 场景（grep 无 kitchen/room 场景）；本规格按「房间 = 独立可复用场景单元」理解。若用户指另一层（C1/C2）的房间结构，需按该层结构对齐。
- J2 光影遮罩「只留出想要的场景」的**具体形态**（圆形聚焦 vs 矩形房间 vs 多孔）：本规格按「圆形软边挖孔（跟随玩家/中心）」定义，参数化支持多形态；如用户有具体光影切换设计，以阶段二 C3 玩法规格为准。
- J3 「指定游戏进程」的具体旗标名/时序（如 `exam_completed` / `oxygen_ok`）需阶段二确认；本模块只定义 Item 读取 gate 接口。
- J4 特效库「震撼/爆炸」的视觉强度/颜色默认值：白模阶段用可辨参数，正式值待 C3 打磨；参数化，不锁定具体值。
- J6 可交互状态标记(⑥) 房间判定：默认 room_id 由 item.x 派生（区间表）；显式 room_id 为覆盖项；跨不连续房间/多房间边界以阶段二 C3 房间布局为准（RoomTable 按实际 x 区间配置）。
## 15. ⑥ 可交互状态标记（ItemMarker 黄色星星）契约

> 依据：用户新规格（本模块第 6 项前置需求）：**item 可交互时显示黄色星星；在同房间里可以远程显示（不要求靠近）；作为单独模块可复用。**
> 本文为本前置模块的第 6 项需求，追加于 ①–⑤ 之后；实现（t2）、验证（t3）、评审（t4）均以本文为准。**设计权铁律：只收录上述需求，不新增玩法。**

### 15.1 用户规格原文（⑥）
1. item 可交互时显示黄色星星；
2. 在同房间里可以远程显示（不要求靠近）；
3. 作为单独模块可复用。

### 15.2 显示条件（①）
- **显示条件**：item **交互可用**时显示黄色星星；不可交互时隐藏。
  - 交互可用 = `interaction_available(enabled=true)` 或 gate 满足（前置 Item 已暴露 `interaction_available(enabled)` 信号；`gate_flag` 未满足 / `set_interaction_enabled(false)` 时满足为 false）。
  - ItemMarker 连接 item 的 `interaction_available(enabled)` 信号（**只读访问，不改 item.gd**）；enabled=true → 显示，false → 隐藏。
- **与 E 提示（InteractHint）两套独立逻辑**：InteractHint = 靠近（body_entered/body_exited, body is Player）才显示；ItemMarker = **交互可用就显示（不要求靠近）**，并支持同房间远程可见。二者独立、可并存、互不侵入。

### 15.3 同房间远程可见 + 房间判定方案定案（②）
- **定案 = 场景级房间区间表（RoomTable 节点，room_id → x 区间）**。
  - **依据**：白模三房 x 区间已给出（`[0,1280]` / `[1280,2560]` / `[2560,3840]`），与 C3 流程房间布局可直接映射；相比候选「每房加 Area2D 分区（RoomArea）」，区间表**实现简单、零额外物理/信号、可复用、与白模纯 x 分区结构一致**。
  - **升级路径**：若未来房间非矩形/非连续，再升级为 Area2D 分区（记录，不采用）。
- **判定**：`RoomTable.get_room_of(x: float) -> String`；ItemMarker **同房** = `get_room_of(player.x) == room_id`（room_id 可显式配置，或默认取 `get_room_of(item.x)` 派生）。
- **可见性管线**：`visible = interaction_available(enabled) && same_room(player, item)`。

### 15.4 组件契约（③，独立可复用，不侵入既有）
- **`scripts/components/ItemMarker.gd`**（Node2D，挂 item 子节点；参数化）：
  - `@export var star_color: Color = Color(1, 0.84, 0.18, 1)`（黄）、`@export var star_size: float = 12.0`、`@export var star_texture: Texture2D`（空 → Polygon2D 星形占位）、`@export var room_id: String = ""`（空 → 由 item.x 派生）、`@export var room_table_path: NodePath`、`@export var player_path: NodePath`、`@export var offset: Vector2 = Vector2(0, -40)`。
  - 行为：`_ready` 取 `item = get_parent()`（须为 Item），连接 `item.interaction_available`；取 player（`player_path` 或组 `player`）；取 RoomTable（`room_table_path`）。`_process` 计算 `visible = interaction_available_flag and same_room()` → 设 visible。`func set_interactable(flag: bool)`（信号回调）。
  - **不侵入** InteractHint.gd / item.gd 现有契约（item.gd 已暴露 interaction_available 只读信号；ItemMarker 只读，不写、不改二者）。
  - **fail-open 语义**：`same_room()` 在**无 RoomTable 或玩家不可得**时退化为 `true`（即仅按 `interaction_available` 显示，不因缺房间表误隐藏）。**适用前提**：仅在配置了 RoomTable（房间 x 区间）的场景才启用「异房隐藏」；未配置房间表时默认同一房间、恒显示。依赖 RoomTable 的房间判定需显式设置 `room_table_path`。
- **`scripts/components/RoomTable.gd`**（数据源，可复用，不含房间名/关卡字面量）：
  - `var rooms: Dictionary = {}`（room_id → `{x_min: float, x_max: float}`）；`func set_rooms(rooms: Dictionary)`；`func get_room_of(x: float) -> String`（含 x 的 room_id，否则 `""`）。
  - 三房 x 区间由场景配置（白模三房 [0,1280]/[1280,2560]/[2560,3840]），代码零硬编码。

### 15.5 占位资产（④）
- 默认 `Polygon2D` 五角星（零贴图、零外部依赖）；可选 `star_texture`（Kenney / 程序化，优先零外部依赖，本模块默认 Polygon2D 星形，不引入外部资产）。
- 不新增输入映射；纯视觉标记。

### 15.6 验收标准（⑤）
| # | 验收标准 | 证据方式 |
|---|---|---|
| ⑥a | item 交互可用（interaction_available(true)/gate 满足）→ 显示黄色星星；不可交互 → 隐藏 | 代码走查 + headless 读回 + 运行 |
| ⑥b | 同房远程可见：玩家与 item 同房 → 星星可见（不靠近）；异房 → 隐藏 | 运行（跨房移动读回）+ 截图 |
| ⑥c | 独立可复用：ItemMarker 挂 item 子节点即用；与 InteractHint 靠近逻辑互不冲突（两套独立） | 代码走查 + 演示场景两节点各配 |
| ⑥d | 参数化：color/size/texture/room_id/room_table_path/player_path/offset 可配 | 代码走查 |
| ⑥e | 无文本/无新输入；白模 Polygon2D 星形；零外部依赖 | headless 加载 0 错误 + 资产断言 |

### 15.7 T2 附加 verify
```powershell
Test-Path F:\Godot\Spine\Spine\scripts\components\ItemMarker.gd    # True
Test-Path F:\Godot\Spine\Spine\scripts\components\RoomTable.gd     # True
Select-String -Path F:\Godot\Spine\Spine\scripts\components\ItemMarker.gd -Pattern ':= *(clamp|move_toward|lerp|min|max|smoothstep)'
#   → 无输出（编码红线）
Select-String -Path F:\Godot\Spine\Spine\scripts\components\ItemMarker.gd -Pattern 'interaction_available'
#   → 命中（读取 item.interaction_available 信号）
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/<item_marker_demo>.tscn -- --self-check
#   → exit 0；含 ItemMarker SELF-CHECK PASS
```
