# C3 关卡玩法规格：约束文档与验收契约（docs/c3_gameplay_constraints.md）

> 依据：用户 C3 完整流程规格（团队任务 t5 描述 ①–⑦）+ 前置组件契约（docs/c3_prelude_constraints.md，t1 已交付）+ 仓库既有约束（docs/c3_floor_constraints.md / docs/item_constraints.md）。
> 本文是 C3 关卡玩法的**唯一权威约束**：实现（t6）、验证（t7）、评审（t8）均以本文为准。**硬约定：实现代码产出前先出本文档。**
> **铁律**：不动 scenes/main.tscn（含 project.godot）；调试/验收入口=命令行场景参数；本地提交、不 push（push 需用户确认）。
> **设计权铁律**：本文只收录用户已明确的 ①–⑦ 流程设计，不新增玩法/操作/剧情/文本。凡冒「实现禁区」的条目实现中出现即判 FAIL。

---

## 0. 结论摘要

C3 关卡是一次**线性单人流程**（书房→客厅→厨房→回书房→光影→无限走廊→走廊尽头→卧室→白屏结束），映射为一张可运行 C3 关卡场景（c3_level.tscn）+ 一个流程控制器（C3Flow.gd）+ 若干前置组件实例（InteractHint / Item gate / DarknessMask / 特效库 / 卧室 room 白模）。
流程分 9 个阶段（§3 状态机）；进程旗标（bool，GameState.process_flags）用于 item 门控与阶段衔接；呼吸机制用一个新增 BreathSystem 组件驱动气泡/缺氧，复用 DarknessMask 实现缺氧压暗。全部调试经命令行场景参数跳阶段，main.tscn 不动。

---

## 1. 用户 C3 完整流程原文（必须逐条映射，不增删设计）

① **呼吸机制**：单击空格启动一次呼吸；长按空格屏住呼吸（长按在指定流程后解锁，前期封闭）；角色身旁漂浮蓝色气泡，10 秒未按空格气泡破裂→触发缺氧（屏幕四周向中间逐渐压暗，非全黑，5 秒后压暗至仅角色周围一圈正常）；缺氧时按空格触发呼吸即解除、压暗消失、气泡恢复。
② **卧室门**：本场景默认可交互显示 E 但交互无反应（无文本，本轮不管理任何文本）；流程点名后变为交互进卧室白模。
③ **初始流程**：出生书房，书房内 item 全不触发；出书房后书房-客厅门暂时禁止自动开门（无法回书房）；客厅靠左第一处显示交互 E→得 100 分试卷（白纸占位）；进厨房（白模餐厅位，规格须注明映射）中间第二处交互→第二张 100 分试卷；此后书房门禁解除、书房 item 解禁；回书房在左、左下找第三（100 分）、第四（99 分，顺序无关）交互物→触发光影进入下一阶段。
④ **光影**：除书房外全黑；出书房门黑屏并渐变重显，角色重置书房初始位；第二次靠近门后门和墙消失，光影+粒子震撼衔接：遮罩域一边消失一边震撼粒子，露出书房-客厅墙粒子消散后出现走廊；环境压抑微压暗（不明显只渲染氛围）；此时解锁长按屏息，长按气泡直接破裂触发缺氧。
⑤ **无限走廊**：角色走到屏幕中间后不再移动角色、改为移动墙壁（需墙壁纹理表现移动）；走廊无限长；走过 3/4 屏后引入第一个特异点贴墙；此后每 1/4 像素出一个；三特异点=贴满墙奖状、地上书山、墙上悬浮文本框（占位普通文本「提升一分，干掉千人」）；每个特异点须屏息通过，未屏息则传送到第一个特异点前 1/4 位置。
⑥ **走廊尽头**：第三特异点后 1/4 取消无限走廊变有限，角色可向右走到尽头；尽头交互显示 item，按 E 状态更新（占位）再按 E 黑屏。
⑦ **卧室结局**：黑屏后重显在卧室靠左；item 交互显示 E 共 3 次；交互后面前墙面状态更新颜色渐变（占位，真实为撕墙纸展海报）；呼吸机制解除；卧室门解锁可交互；靠近门按 E 回客厅卧室门前；走到右手靠墙交互 item→白屏结束。

---
## 2. 工程事实、前置组件契约与复用清单

### 2.1 工程事实（沿用 c3_floor / prelude 结论）
- 仓库根 `F:\Godot\Spine`；工程根 `F:\Godot\Spine\Spine`（res:// 即此）；Godot 4.7.2（`F:\Godot\godot\godot.exe`）。
- 输入集（project.godot `[input]`）：move_left / move_right / interact(E) / dialogue_t / dialogue_y。
- **呼吸键（空格）与“不新增输入映射”红线的处理（定案 D8）**：呼吸机制用**空格**，而既有 `interact`(E) 是交互键，二者不可混用。**结论：新增一个输入动作 `breathe`（物理键 空格/Space），属最小输入映射扩展**，需改 project.godot `[input]`（改前先留 `project.godot.bak`）；其余输入动作不动，`[autoload]` 不变（不新增 autoload）。⚠ 这是**唯一 project.godot 变更点**；若用户确认也可让 `interact` 同时绑定 E+空格（则不改 [input]，但交互与呼吸同键易误触发，**推荐独立 breathe 键**）。
- autoload（project.godot `[autoload]`）：GameState / StoryMonitor / DialogueManager（**本模块不新增 autoload**）。
- 既有可交互体系（沿用）：Item（extends Area2D，int 状态机）/ InteractableObject（extends Area2D，写 object_states）。E 键两套并行：LevelScene 扫 InteractableObject；Player.interact_pressed → Item.touched()。
- c3_floor.tscn（书房|客厅|餐厅，宽 3840，2.35:1，FloorTemplate 参数化）：为 C3 关卡基础几何来源；**本模块流程级场景为 `scenes/c3_level.tscn`**（含 书房|客厅|餐厅[=厨房]|卧室|走廊），c3_floor.tscn 不作为运行场景（几何可并入）。

### 2.2 前置组件契约（docs/c3_prelude_constraints.md 定案，直接复用；字段名以此为准）
- **GameState.process_flags**（bool）：`set_process_flag(name, value: bool)` / `get_process_flag(name) -> bool`；与 `object_states` 并存、互不读写；存档含 process_flags（向后兼容）。
- **Item**：`gate_flag: String`（gate 未满足→touched 不发 `gate_blocked` 不触发）、`set_interaction_enabled(enabled: bool)`（enabled=false 不触发）、`force_trigger_node: NodePath` + `force_trigger_state: int`（玩家进入该节点→`call_item(force_trigger_state)` 强制触发，无视 gate）、`states: Dictionary`（state:int→{position,size,color,texture}，基类 apply_state 查表）、`initial_state: int`、`interaction_available(enabled: bool)`、`gate_blocked`、`touched()`/`call_item(new_state)`（汇入 `set_state`→`apply_state`）。
- **InteractHint**：`hint_texture` / `head_offset` / `scale_factor`（改名自 spec 稿 `scale`，避 Node2D 内建 scale 遮蔽）/ `fade_duration`；`show_hint()`/`hide_hint()`/`set_visible_forced(v)`；自接线父 Area2D body_entered/body_exited（判 body is Player）。
- **DarknessMask**（方案 B 挖孔 canvas_item shader）：`center_global: Vector2`、`follow_player: bool`、`radius_inner: float`、`radius_outer: float`、`darkness_color: Color`、`softness: float`、`enabled: bool`、`layer: int`（**默认 1**——置于默认画布内容之上才能压暗并挖孔；spec 稿 -9 会因在画布之后被整块遮挡而不可用）。
- **特效库**（组件式）：`ParticleBurst`（`burst()`/`set_color(color)`/amount/color/lifetime/spread/initial_velocity/gravity/size）、`ScreenShake`（`shake(amp,dur)`/amplitude/frequency/duration/attenuation）、`ItemShake`（`shake(amp,dur)`/amplitude/duration/axis/flip_random）。
- **卧室 room 白模**：`room_bedroom_whitemodel.tscn` + `RoomBase.gd`（room_width/wall_height/stand_surface_y/floor_color/wall_color/door_pos/spawn_pos/door_enabled）。

### 2.3 本模块新增组件（t6 实现；均为脚本，不含房间名/关卡字面量，可复用）
- `scripts/c3/breath/BreathSystem.gd`（实际路径为 `scripts/c3/breath/`；呼吸机制：气泡/计时/缺氧/屏息解锁，驱动 DarknessMask 缺氧）。
- `scripts/c3/breath/Bubble.gd`（实际路径 `scripts/c3/breath/`；蓝色气泡视觉+破裂/恢复）。
- `scripts/c3/flow/C3Flow.gd`（实际路径 `scripts/c3/flow/`；流程控制器：阶段状态机 + 阶段切换 + LIGHT 序列 + 调试 phase 参数）。
- `scripts/c3/corridor/Corridor.gd`（实际路径 `scripts/c3/corridor/`；无限/有限走廊：墙壁移动/纹理滚动/特异点序列/传送）。
- `scripts/c3/flow/C3PaperItem.gd`（考卷 item 子类）、`scripts/c3/bedroom/{BedroomEnding,BedroomWallItem,BedroomDoorItem,BedroomEndItem}.gd`（卧室结局）。
## 3. 流程状态机与进程旗标

### 3.1 C3Flow 阶段（int，运行时状态，不持久化）
```
STAGE_STUDY         = 1   # 出生书房；书房 item 全不触发；呼吸激活(单击 breathe；长按封闭)
STAGE_LEAVE_STUDY   = 2   # 玩家走出书房；书房-客厅自动门锁定(无法回)；呼吸激活
STAGE_LIVING        = 3   # 客厅左第一处 E→100 分试卷
STAGE_KITCHEN       = 4   # 进厨房(白模餐厅位) 第二处 E→第二张 100 分试卷；此后书房门禁解除+书房 item 解禁
STAGE_RETURN_STUDY  = 5   # 回书房左/左下找第三(100)/第四(99,顺序无关)交互物→触发光影
STAGE_LIGHT         = 6   # ④ 光影：除书房外全黑→出书房门黑屏渐变重显(角色重置书房初始位)→二靠近门→门墙消失→粒子震撼→走廊出现；环境微压暗；解锁长按屏息
STAGE_CORRIDOR      = 7   # ⑤ 无限走廊：移动墙壁；特异点
STAGE_CORRIDOR_END  = 8   # ⑥ 第三特异点后 1/4 走廊变有限；尽头 item→按 E 状态更新→再 E 黑屏
STAGE_BEDROOM       = 9   # ⑦ 黑屏后重显卧室靠左；item×3；墙面色变；呼吸解除；卧室门解锁；按 E 回客厅卧室门前；右手靠墙 E→白屏结束
```
### 3.2 进程旗标（GameState.process_flags，全部 bool，由 C3Flow 写入；Item.gate_flag / 流程逻辑读取）
```
hold_breath_unlocked      : ④ 解锁长按屏息(长按→气泡破裂→缺氧)。之前 false。
bedroom_door_active       : ② 流程点名后卧室门可交互进卧室。此前 false。
paper_living_collected    : 客厅左第一处 100 分试卷已得。
paper_kitchen_collected   : 厨房(白模餐厅位)第二张 100 分试卷已得。
study_items_unlocked      : 书房 item 解禁(初生 false；两张 100 分试卷后 true)。
study_gate_open           : 书房门禁解除(可回书房；初生出书房后 false；两试卷后 true)。
light_phase_done          : ③ 末触发光影进入 ④(进入 STAGE_LIGHT)。
corridor_entered          : 进入无限走廊。
corridor_end              : 第三特异点后无限走廊变有限(到尽头)。
bedroom_unlocked          : ⑦ 卧室门解锁可交互。
bedroom_interactions_done : 卧室 item 3 次交互完成(呼吸解除+墙体变色铺垫)。
end_white                 : ⑦ 白屏结束。
```
### 3.3 场景结构与调试入口
`res://scenes/c3_level.tscn`（root Node2D，script=scripts/scenes/C3Flow.gd）——流程级运行场景：
```
C3Level (Node2D; C3Flow.gd)
├─ Player (instance player.tscn)
├─ Environment/ (书房|客厅|餐厅[=厨房] 几何：Floor/Ceiling/Wall*/自动门实例)
├─ Rooms/ (Bedroom = instance room_bedroom_whitemodel.tscn，靠左)
├─ Corridor (Node2D; Corridor.gd + 墙壁/纹理/特异点)
├─ Items/ (考卷 item 系列 + 卧室门 item + 走廊尽头 item + 卧室 item)   # 各带 InteractHint / gate / force_trigger
├─ Breath (BreathSystem.gd + Bubble)
├─ Effects/ (ParticleBurst / ScreenShake / ItemShake 实例)
├─ DarknessMask (DarknessMask.gd  # 缺氧/光影共用，按阶段切配置)
└─ Camera (Player/Camera2D)
```

**调试入口（命令行动词参数，main.tscn 不动）**：
`F:\Godot\godot\godot.exe --path F:\Godot\Spine\Spine res://scenes/c3_level.tscn -- --phase=<1..9>`（`--` 后为 `OS.get_cmdline_user_args()` 用户参数；C3Flow._ready 读取 `--phase` 直接跳到对应阶段以验证该阶段/子流程，便于分步验收）。另支持 `--self-check`（headless 自检，见 §13）。
### 3.4 阶段切换与槽位尺寸
- 地图宽度 3840（沿用 c3_floor），站立面 y=988（碰底留 8px，F5 教训）；玩家出生 (320, 948)。
- 卧室门（客厅中央 x≈1920）复用 LockedBedroomDoor 概念；书房-客厅自动门 AutoDoorStudyLiving(1280) / 客厅-餐厅自动门 AutoDoorLivingDining(2560)。
- 餐厅（2560 区间）在本关**映射为厨房（白模餐厅位）**——**映射声明（用户口径）**：用户所称“进厨房”，实现即现有“餐厅”房间位置（白模占位），仅命名差异，无额外玩法设计。

---
## 4. ① 呼吸机制契约（BreathSystem + Bubble + 缺氧 DarknessMask）

### 4.1 目标
单击空格启动一次呼吸；长按空格屏住呼吸（长按在④解锁，前期封闭）；角色身旁漂浮蓝色气泡，10 秒未按空格气泡破裂→缺氧（屏幕四周向中间渐变压暗，非全黑，5 秒后仅角色周围一圈正常）；缺氧时按空格呼吸即解除、压暗消失、气泡恢复。

### 4.2 BreathSystem（scripts/components/BreathSystem.gd）
- `@export var bubble: NodePath`、`@export var darkness_mask: NodePath`、`@export var player: NodePath`、`@export var breathe_timeout: float = 10.0`、`@export var hypoxia_shrink_duration: float = 5.0`、`@export var hold_breath_unlocked_flag: String = "hold_breath_unlocked"`、`@export var hold_burst_delay: float = 0.5`。
- 信号：`signal breathed`、`signal bubble_broken`、`signal hypoxia_started`、`signal hypoxia_cleared`。
- `func breathe() -> void`：重置计时、恢复气泡、清除缺氧（mask.enabled=false、气泡 restore、计时归零）。由 `breathe` 输入动作（空格）触发（单击）。
- `func _process(delta)`：_countdown 递减；≤0 → `_break_bubble()`→`_start_hypoxia()`。
- `func _start_hypoxia()`：设 mask 参数（follow_player=true、center_global=player、darkness_color=非全黑、radius 由大→小）+ `hypoxia_started.emit()`。
- `func _clear_hypoxia()`：mask.enabled=false + `hypoxia_cleared.emit()`。
- 长按屏息：若 `GameState.get_process_flag(hold_breath_unlocked_flag)` 为真，对 `breathe` 长按 ≥ `hold_burst_delay` → `_break_bubble()` → `_start_hypoxia()`（气泡直接破裂触发缺氧，用户口径④）。前期（flag=false）长按无效果（保持封闭）。

### 4.3 Bubble（scripts/components/Bubble.gd，蓝色气泡）
- 视觉：Node2D + Polygon2D 圆形（或 Sprite2D 蓝圈，白模用 Polygon2D 圆近似）；`@export var radius: float = 22.0`、`@export var color: Color = Color(0.35, 0.62, 0.96, 1)`。
- 定位：跟随玩家身旁（`@export var follow_offset: Vector2 = Vector2(46, -28)`；每帧取 player.global_position + offset）。
- `func restore()`：重置可见/完整；`func pop()`：破裂（播放一小段缩放消失/粒子 `ParticleBurst` 可选，白模可仅隐藏）；`func set_air_fraction(f: float)`：随计时 0→1 压缩/变暗（可选）。
- `bubble_broken.emit` 由 BreathSystem 触发。

### 4.4 缺氧 DarknessMask 配置（复用前置 DarknessMask）
- `follow_player = true`、`center_global = player.global_position`、`darkness_color = 非全黑`（如 `Color(0.02, 0.02, 0.05, 1)` 深蓝黑，**不可纯黑**，用户口径「非全黑」）。
- 缺氧渐变：从 `radius_outer` 大（如 1200）→ 小（如 190），`radius_inner` 对应（如 1000→130），`softness` 中（如 0.35），在 `hypoxia_shrink_duration`（5s）内渐缩——5 秒后仅角色周围一圈正常（用户口径⑤）。
- `enabled=false` 或缺氧清除时完全透明（不影响正常场景）。

### 4.5 呼吸输入（空格）
- **最小输入映射扩展**：在 project.godot `[input]` 新增 `breathe`（物理键 空格/Space），改前先留 `project.godot.bak`。这是**唯一 project.godot 变更点**（D8）；`[autoload]` 不变。
- 绑定：BreathSystem 监听 `breathe` 按下（单击→`breathe()`）与长按（≥hold_burst_delay→破裂缺氧，若解锁）；`StoryMonitor.input_locked` 时**不响应**（仓库惯例，锁定时 Player 不动、呼吸暂停）。

### 4.6 验收（① 呼吸）
- 单击空格：计时重置、气泡恢复、缺氧清除（若在缺氧）。
- 10 秒未按空格：气泡破裂、缺氧触发、mask 渐变压暗（非全黑），5 秒后仅角色一圈正常。
- 缺氧时按空格：呼吸解除、压暗消失、气泡恢复。
- 长按屏息：④ 前无效果（封闭）；④ 后长按 ≥0.5s → 气泡直接破裂 → 缺氧。
- 全程无文本；`StoryMonitor.input_locked` 时不响应；`headless --self-check` 可验证计时/缺氧/清除（读回 PASS）。

---
## 5. ② 卧室门契约

### 5.1 目标
本场景卧室门（客厅中央 x≈1920，复用 LockedBedroomDoor 概念）：默认**可交互显示 E**（InteractHint）但**交互无反应**（无文本）；流程点名后（`bedroom_door_active=true`）变为可交互进卧室白模。本轮不管理任何文本。

### 5.2 契约
- 门节点：Area2D + InteractHint（显示 E，默认隐藏，靠近显示）；`gate_flag = "bedroom_door_active"`；`set_interaction_enabled(false)` 初生（或 gate 默认不满足）。
- 默认态：玩家靠近 → E 提示出现；按 E → `touched()` 因 gate 未满足 → 发 `gate_blocked`、无任何反应、**无文本**（用户口径「无文本，本轮不管理任何文本」）。
- 点名后态：C3Flow 在某阶段设 `bedroom_door_active=true` → 门可交互；按 E → 进入卧室白模（C3Flow 搬运到 `Rooms/Bedroom` 的卧室起点，见 §10/⑦）。
### 5.3 验收（② 卧室门）
- 靠近显示 E；默认按 E 无反应（无文本）；`bedroom_door_active=true` 后按 E 进入卧室白模。
- 无文本（不新增任何文案/对话）；InteractHint 复用前置组件。

---
## 6. ③ 初始流程与试卷契约

### 6.1 目标
出生书房→书内 item 全不触发；出书房后书房-客厅自动门禁（无法回）；客厅左第一处 E→100 分试卷；进厨房（白模餐厅位）第二处 E→第二张 100 分试卷；此后书房门禁解除、书房 item 解禁；回书房左、左下找第三（100 分）/第四（99 分，顺序无关）交互物→触发光影进入下一阶段。

### 6.2 阶段与旗标时序
```
STAGE_STUDY(1)  : study_items_unlocked=false；书房考卷 item(第三/第四) gate 不满足；呼吸激活。
出书房         : C3Flow 检测玩家离开书房 → 锁定书房-客厅自动门(study_gate_open=false) → STAGE_LEAVE_STUDY(2)。
STAGE_LIVING(3) : 客厅左第一处 PaperLiving(100) → touched → paper_living_collected=true。
STAGE_KITCHEN(4): 厨房(白模餐厅位) PaperKitchen(100) → touched → paper_kitchen_collected=true。
                : paper_living_collected && paper_kitchen_collected → study_gate_open=true, study_items_unlocked=true。
STAGE_RETURN_STUDY(5): 回书房；StudyPaperA(100,左)/StudyPaperB(99,左下) 均可(顺序无关)；二者都触发 → light_phase_done=true → STAGE_LIGHT(6)。
```

### 6.3 考卷 item（复用前置 Item 基类）
- 节点：Area2D + InteractHint（E 提示）+ `states: Dictionary`（state 0=未得/白纸；state 1=已得，白模可置为变色/隐去）。
- 导出：`paper_id: String`、`score: int`（100 或 99）、`flag: String`（对应 process flag）；`touched()` 覆写：置 `GameState.set_process_flag(flag, true)` + `set_state(1)`；随后 C3Flow 据旗标判断推进。
- 门控：StudyPaper 设 `gate_flag = "study_items_unlocked"`（未满足→gate_blocked，不发 state 变更）；PaperLiving/PaperKitchen 无 gate（进到即得）。
- 白纸占位：state 0 显示白色矩形（Polygon2D）；state 1 可置为灰/隐去（占位，无真实试卷画）。

### 6.4 书房-客厅自动门禁
- 复用 AutoDoor；新增门禁：当 `study_gate_open=false` 时，门在玩家靠近时**不自动开门**（FloorTemplate/C3Flow 读取该旗标决定是否接线或禁用 AutoDoor.open）。
- 初生出书房后同步设 `study_gate_open=false`；两试卷后设 `true`。（用户口径「暂时禁止自动开门（无法回书房）」/「书房门禁解除」。）

### 6.5 验收（③ 初始/试卷）
- 出生书房；书房考卷 item（第三/第四）在 `study_items_unlocked=false` 时按 E 无反应（gate_blocked）；初生书房内其余 item 全不触发。
- 出书房后书房-客厅自动门禁（无法回），两试卷后解除。
- 客厅左第一处 E→得 100 分试卷；厨房（白模餐厅位）第二处 E→第二张 100 分试卷。
- 两试卷后书房 item 解禁；回书房左、左下第三（100）/第四（99，顺序无关）交互物→触发光影进入下一阶段（`light_phase_done=true`）。
- 全程无文本；考卷为白纸占位。

---
## 7. ④ 光影契约（DarknessMask 序列 + 粒子震撼）

### 7.1 目标（用户原文）
除书房外全黑；出书房门黑屏并渐变重显，角色重置书房初始位；第二次靠近门后门和墙消失，光影+粒子震撼衔接：遮罩域一边消失一边震撼粒子，露出书房-客厅墙粒子消散后出现走廊；环境压抑微压暗（不明显只渲染氛围）；此时解锁长按屏息，长按气泡直接破裂触发缺氧。

### 7.2 C3Flow 光影子步骤（STAGE_LIGHT(6)，参数化时序）
```
LIGHT-A  进入光影：DarknessMask.enabled=true, follow_player=true(玩家在书房), radius 大(覆盖书房), darkness_color≈非纯黑(极暗)。 → 除书房外全黑
LIGHT-B  出书房门：DarknessMask 全黑(radius→小/全屏黑), 画面渐黑 → 重置玩家到书房初始位(spawn_pos) → 渐显(mask 回退) 。  黑屏并渐变重显, 角色重置
LIGHT-C  第二次靠近门：门+墙(书房-客厅墙) 消失(隐藏几何) + 粒子震撼(遮罩域一侧 ParticleBurst + ScreenShake.shake()) → 露出走廊几何。  门墙消失/震撼衔接
LIGHT-C2 书房-客厅墙粒子消散后 → 走廊出现(corridor_entered=true)。
LIGHT-D  环境微压暗：DarknessMask.enabled=true(可选低强度: darkness_color 很暗/alpha 低, radius 极大)，仅渲染氛围、不明显。
LIGHT-E  hold_breath_unlocked=true（解锁长按屏息）。
```

### 7.3 契约
- **DarknessMask 复用**：同一 `DarknessMask` 节点，按图切换配置（center/radius/darkness_color/enabled）；属前置组件，不改其脚本。
- **粒子震撼（全屏撼动=相机 shake+房间边沿粒子，前置特效库）**：在 `LIGHT-C` 用 `ScreenShake.shake(amp, dur)` + 沿书房-客厅墙边沿放置 `ParticleBurst.burst()`（`set_color` 选暖色/冷色）。
- **几何消失**：C3Flow 在 `LIGHT-C` 隐藏 书房-客厅墙(WallStudyLiving) 与 自动门(AutoDoorStudyLiving) 的视觉+碰撞，露出走廊区域；粒子消散后出现走廊几何。
- **环境微压暗**：`LIGHT-D` 用 DarknessMask 低强度（radius 极大、darkness_color 极暗、softness 大）或可选的 GlobalCanvasModulate 轻微调暗，仅氛围、不明显（用户口径「不明显只渲染氛围」）。**不新增全局节点类型；与前置 DarknessMask 方案 B 一致**（若用 GlobalCanvasModulate 需评估；默认用 DarknessMask 低强度）。
- **解锁屏息**：`LIGHT-E` 设 `hold_breath_unlocked=true`，BreathSystem 据此启用长按屏息。

### 7.4 验收（④ 光影）
- 进入光影后除书房外全黑（darkness 近黑，non-纯黑可）；出书房门黑屏并渐变重显、角色重置书房初始位。
- 第二次靠近门：门+墙消失、粒子震撼（ScreenShake+房间边沿 ParticleBurst）、遮罩域一边消失、走廊出现。
- 环境微压暗（不明显）；`hold_breath_unlocked=true`，长按屏息→气泡破裂→缺氧。
- 全程无文本；时序可参数化（`--phase=6` 直接进入验证）。

---
## 8. ⑤ 无限走廊契约（Corridor.gd）

### 8.1 目标（用户原文）
角色走到屏幕中间后不再移动角色、改为移动墙壁（需墙壁纹理表现移动）；走廊无限长；走过 3/4 屏后引入第一个特异点贴墙；此后每 1/4 像素出一个；三特异点=贴满墙奖状、地上书山、墙上悬浮文本框（占位普通文本「提升一分，干掉千人」）；每个特异点须屏息通过，未屏息则传送到第一个特异点前 1/4 位置。

### 8.2 走廊移动与原理解
- **移动墙壁**：当玩家前进至屏幕几何中心（相机 clamp 中心）后，**停止移动玩家**，改为每帧沿 -x 平移走廊子节点（墙/楼面/特异点），并让**墙壁纹理滚动**（`texture_offset.x -= speed*delta`）以表现移动（走廊墙需**平铺纹理**——新增程序化/占位纹理资产，见 §15-J5）。
- **无限长**：走廊子节点循环（或程序化生成），纹理平铺（TextureRepeat），保证视觉上可无限前进。
- **触发**：玩家在 STAGE_CORRIDOR，屏幕中心阈值 → 切入“墙壁移动”模式；其余时段正常移动。

### 8.3 特异点序列
- **引入节奏**：走过 3/4 屏 → 第一个特异点贴墙；此后每 1/4 屏 → 下一个（每 1/4 出一个）。
- **三特异点**：① 贴满墙奖状（墙面密布奖状占位块）② 地上书山（地面堆放书占位块）③ 墙上悬浮文本框（RichTextLabel/Label 占位普通文本“提升一分，干掉千人”）。
- **屏息通过**：玩家经过每个特异点区域时须处于“屏息”态（长按空格，④ 已解锁）；未屏息（未长按）→ **传送到第一个特异点前 1/4 位置**（重置玩家 x，并重置对应特异点进度）。
- **屏息与缺氧联动（设计张力，记录）**：④ 长按屏息→气泡破裂→缺氧；故走廊内“持屏息过特异点”会触发缺氧压暗，过点后可呼吸恢复——形成张力（用户口径“每个特异点须屏息通过”+“长按气泡直接破裂触发缺氧”）。**具体“屏息”判定（长按态 vs 触屏按住）与缺氧是否覆盖走廊期，作为待确认点（§15-J4）**；实现按“长按空格=屏息”为准。

### 8.4 验收（⑤ 无限走廊）
- 玩家到屏幕中心后停止移动玩家、墙/纹理向左滚动（可辨移动感）。
- 走廊无限（纹理平铺/循环）；走过 3/4 屏出第一特异点，此后每 1/4 出一个。
- 三特异点为：贴墙奖状、地上书山、墙上悬浮文本（占位“提升一分，干掉千人”）。
- 未屏息经过特异点→传送到第一特异点前 1/4；屏息通过则继续。
- 全程“无文本”豁免：文本框为占位普通文本，属该特异点占位，非叙事文本（用户已提供文案“提升一分，干掉千人”）。

---
## 9. ⑥ 走廊尽头契约

### 9.1 目标（用户原文）
第三特异点后 1/4 取消无限走廊变有限，角色可向右走到尽头；尽头交互显示 item，按 E 状态更新（占位）再按 E 黑屏。

### 9.2 契约
- **走廊变有限**：`corridor_end=true`；Corridor.gd 停止无限循环、给出有限终点（右侧尽头墙），玩家可向右移动至尽头。
- **尽头 item**：Area2D + InteractHint（E 提示）；两段式交互：
  - 第 1 次 E → `set_state(1)`（状态更新，占位：如 item 变灰/变色/位移）；`corridor_end_item_state=1`。
  - 第 2 次 E → `set_state(2)` → C3Flow 检测后触发**黑屏**（`darkness 全黑渐变`）→ `corridor_end` → 进入 ⑦ 卧室（`corridor_end_done=true`）。
- 黑屏过渡：复用 DarknessMask 全黑渐变（或独立全屏黑渐变）→ 角色搬运到卧室靠左，重显。

### 9.3 验收（⑥ 走廊尽头）
- 第三特异点后 1/4 走廊变有限（有界、有尽头墙）；玩家可走到尽头。
- 尽头 item 显示 E；按 E 状态更新（占位）；再按 E 黑屏；黑屏后进入卧室靠左。
- 全程无文本；时序/过渡可参数化。

---
## 10. ⑦ 卧室结局契约

### 10.1 目标（用户原文）
黑屏后重显在卧室靠左；item 交互显示 E 共 3 次；交互后面前墙面状态更新颜色渐变（占位，真实为撕墙纸展海报）；呼吸机制解除；卧室门解锁可交互；靠近门按 E 回客厅卧室门前；走到右手靠墙交互 item→白屏结束。

### 10.2 卧室房间（复用 room_bedroom_whitemodel.tscn）
- 实例 `Rooms/Bedroom`（RoomBase 参数化：stand_surface_y=988、spawn_pos=靠左、door_enabled=true、可留 InteractHint 挂点）。
- 黑屏后玩家重显在**卧室靠左**（C3Flow 搬运到卧室 spawn_pos）。

### 10.3 卧室交互序列（C3Flow 驱动）
```
BED-A  面前墙 item：InteractHint 显示 E；touched 第1次 → set_state(1)(墙色渐变) , 第2次 → set_state(2), 第3次 → set_state(3)。  item 交互显示 E 共 3 次；每交互一次墙色更新(占位渐变)
BED-B  3 次后：breath_disabled=true(呼吸机制解除, BreathSystem 停止/暂停) ；bedroom_unlocked=true(卧室门解锁可交互)。  呼吸解除+卧室门解锁
BED-C  卧室门(卧室内地板门/回客厅门) 可交互：靠近按 E → C3Flow 把玩家带回客厅卧室门前(重置位置)。  靠近门按 E 回客厅
BED-D  右手靠墙 item：InteractHint 显示 E；touched → end_white=true → 白屏结束(全屏白渐变) → 流程结束。  右手靠墙 E→白屏结束
```

### 10.4 契约
- 墙面 item：Area2D + InteractHint；`states: Dictionary` state 0/1/2/3（0=原墙纸，1/2/3=渐变占位色，真实为撕墙纸展海报——白模用颜色渐变占位）；`touched()` 每次 `set_state(current_state+1)`（封顶 3）。
- 呼吸解除：C3Flow 设 `breath_disabled=true`，BreathSystem 停止计时/缺氧（可加 `func set_enabled(enabled)`，本规格扩展 BreathSystem 提供该接口）。
- 卧室门（回客厅）：Area2D + InteractHint；`gate_flag=`bedroom_unlocked``；E 后 C3Flow 把玩家放到客厅卧室门前（x≈1920 附近）。
- 右手靠墙 item：Area2D + InteractHint；`touched()` → `end_white=true` → C3Flow 触发白屏结束（全屏白渐变 + 流程结束/可退出）。

### 10.5 验收（⑦ 卧室结局）
- 黑屏后重显卧室靠左；面前 item 显示 E，交互共 3 次，每次墙色渐变更新。
- 3 次后呼吸机制解除（不再缺氧）；卧室门解锁。
- 靠近门按 E 回客厅卧室门前；右手靠墙 item 按 E → 白屏结束。
- 全程无文本（白屏结束为视觉终态，非文本）。

---
## 11. 约束、编码红线与前置组件接入

### 11.1 铁律与边界
- **不动 `scenes/main.tscn`**；**`project.godot [autoload]` 不改**（不新增 autoload）；唯一 project.godot 变更点 = `[input]` 新增 `breathe`（空格）+ 先留 `project.godot.bak`。
- 调试/验收入口 = **命令行场景参数**（`-- --phase=<1..9>` / `--self-check`），main.tscn 不加载 C3 关卡。
- 本地提交、不 push（push 需用户确认）。

### 11.2 前置组件接入清单（复用 docs/c3_prelude_constraints.md 的组件，不改其脚本逻辑）
- **InteractHint**（参数名 `scale_factor`（避内建 scale）、`hint_texture/head_offset/fade_duration`）：挂到考卷 item / 卧室门 / 走廊尽头 item / 卧室面前墙 item / 右手靠墙 item —— 靠近显示 E。
- **Item 门控**：考卷（StudyPaper gate_flag=`study_items_unlocked`）、卧室门（gate_flag=`bedroom_door_active`/`bedroom_unlocked`）、走廊尽头 item（两段式）、卧室 item（三态）；均复用前置 Item 基类（gate_flag / states / touched / call_item / set_interaction_enabled）。
- **DarknessMask**：缺氧（follow_player、非全黑、半径渐缩）+ 光影（除书房外全黑、黑屏渐变、环境微压暗）+ 走廊尽头黑屏 —— 同一组件不同配置。
- **特效库**：ParticleBurst / ScreenShake / ItemShake（光影粒子震撼、房间边沿粒子、item 局部震）。
- **卧室 room 白模**：`room_bedroom_whitemodel.tscn` 实例为 ⑦ 卧室结局。

### 11.3 GDScript 编码红线（沿用 c3 §4.5）
- 禁止 `:=` 从返回 Variant 的内建函数推断类型（clamp / move_toward / lerp / min / max / smoothstep 等），一律显式标注（如 `var x: float = clamp(...)`）。
- .tscn 导出属性写在 `script=` 之后；场景文件名 snake_case；节点名 PascalCase；私有成员 `_` 前缀；信号 snake_case；脚本文件名=class_name（PascalCase）。
- 新增/改动脚本：先留同目录 `.bak`（改既有脚本/场景前备份；本模块主要新增 C3Flow/BreathSystem/Bubble/Corridor 与考卷子类）。
- 白模零真实美术（走廊纹理为程序化/占位；奖状/书山/文本框为占位块；墙色为占位渐变）。

---
## 12. T6 verify 命令清单（实现 t6 / 验证 t7 直接使用）

```powershell
# ── 步骤一 文档先行 + 静态扫描 + 备份核对 ──
git -C F:\Godot\Spine log --oneline --follow -- Spine/docs/c3_gameplay_constraints.md
git -C F:\Godot\Spine log --oneline --follow -- Spine/scenes/c3_level.tscn
#   → 文档首次提交不得晚于实现代码首次提交
Test-Path F:\Godot\Spine\Spine\project.godot.bak   # True（改 project.godot 前已备份）
Test-Path F:\Godot\Spine\Spine\scripts\scenes\C3Flow.gd   # True
Test-Path F:\Godot\Spine\Spine\scripts\components\BreathSystem.gd   # True
Test-Path F:\Godot\Spine\Spine\scripts\components\Bubble.gd   # True
Test-Path F:\Godot\Spine\Spine\scripts\scenes\Corridor.gd   # True
Test-Path F:\Godot\Spine\Spine\scenes\c3_level.tscn   # True

# 红线：禁止 := 推断 Variant 内建函数返回类型
Select-String -Path F:\Godot\Spine\Spine\scripts\scenes\C3Flow.gd,F:\Godot\Spine\Spine\scripts\components\BreathSystem.gd,F:\Godot\Spine\Spine\scripts\components\Bubble.gd,F:\Godot\Spine\Spine\scripts\scenes\Corridor.gd -Pattern ':= *(clamp|move_toward|lerp|min|max|smoothstep)'
#   → 无输出

# 铁律：main.tscn 未改 / [autoload] 未新增（git diff 复核，见步骤四）
# 输入：breathe(空格) 已添加（[input] 唯一变更）
Select-String -Path F:\Godot\Spine\Spine\project.godot -Pattern 'breathe'
#   → 命中（空格/Space 物理键 32）

# ── 步骤二 工程整体 headless 加载 ──
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine --quit-after 3
#   → exit 0；stdout 无 SCRIPT ERROR / ERROR / Parse Error

# ── 步骤三 各阶段 headless 加载 + 自检读回 ──
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/c3_level.tscn -- --phase=1 --self-check
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/c3_level.tscn -- --phase=3 --self-check
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/c3_level.tscn -- --phase=4 --self-check
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/c3_level.tscn -- --phase=5 --self-check
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/c3_level.tscn -- --phase=6 --self-check
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/c3_level.tscn -- --phase=7 --self-check
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/c3_level.tscn -- --phase=9 --self-check
#   → 各 exit 0，stdout 无脚本错误；含 SELF-CHECK PASS

# 资产/结构断言
Test-Path F:\Godot\Spine\Spine\assets\ui\corridor_wall.png          # True（走廊平铺纹理，程序化/占位）
Test-Path F:\Godot\Spine\Spine\assets\ui\corridor_wall.png.import   # True
Select-String -Path F:\Godot\Spine\Spine\project.godot -Pattern 'run/main_scene.*main.tscn'
#   → 命中（main.tscn 仍为主场景，未被替换）

# ── 步骤四 窗口运行 + 交互读回 + 证据 + git 卫生 ──
F:\Godot\godot\godot.exe --path F:\Godot\Spine\Spine res://scenes/c3_level.tscn
#   → ①-⑦ 依流程走：呼吸/缺氧、卧室门 E、三处考卷、光影、走廊(特异点/屏息/传送)、尽头两段 E、卧室结局(3×E/壁画/门/白屏)
#   → 截图证据（各阶段关键帧）→ Spine/shots/（.gitignore）
git -C F:\Godot\Spine diff --stat -- Spine/scenes/main.tscn
#   → 无输出（main.tscn 未改）
git -C F:\Godot\Spine diff --stat -- Spine/project.godot
#   → 仅 [input] breathe 变更（无 [autoload] 变更）
git -C F:\Godot\Spine status --porcelain   # 实现提交后应为空
git -C F:\Godot\Spine log --oneline -3     # 本地提交、英文信息、无 push
```

---
## 13. 验收标准表（逐条 ①–⑦ + 约束）

| # | 规格 | 验收标准 | 证据方式 |
|---|---|---|---|
| ① | 呼吸机制 | 单击空格呼吸(计时重置/气泡恢复/缺氧清除)；10s 未按空格→气泡破裂→缺氧(非全黑压暗,5s 后仅角色一圈正常)；缺氧按空格解除；长按屏息④前封闭/④后长按≥0.5s 气泡破裂→缺氧 | headless --self-check + 窗口运行 + 截图 |
| ② | 卧室门 | 靠近显示 E；默认按 E 无反应(无文本)；bedroom_door_active=true 后按 E 进卧室白模 | 代码走查 + 窗口运行 |
| ③ | 初始/试卷流程 | 出生书房；书房 item 全不触发；出书房后书房-客厅自动门禁(无法回)；客厅左第一处 E→100 分；厨房(白模餐厅位)第二处 E→第二张 100 分；两试卷后书房门禁解除+item 解禁；回书房左、左下第三(100)/第四(99,顺序无关)→触发光影 | headless + 窗口运行 + 截图 |
| ④ | 光影 | 进入光影除书房外全黑；出书房门黑屏渐变重显+角色重置书房初始位；第二次靠门→门+墙消失+粒子震撼(ScreenShake+房间边沿 burst)+遮罩域一边消失+走廊出现；环境微压暗(不明显)；hold_breath_unlocked=true 且长按→气泡破裂→缺氧 | headless --self-check + 窗口运行 + 截图 |
| ⑤ | 无限走廊 | 玩家到屏幕中心后停止移动玩家/墙纹理向左滚动；走廊无限；3/4 屏出第一特异点、此后每 1/4 出一个；三特异点=贴墙奖状/地上书山/墙上悬浮文本(占位“提升一分，干掉千人”)；未屏息经过→传送到第一特异点前 1/4；屏息通过则续 | headless + 窗口运行 + 截图 |
| ⑥ | 走廊尽头 | 第三特异点后 1/4 走廊变有限(有尽头)；玩家可走到尽头；尽头 item 显示 E；按 E 状态更新(占位)；再按 E 黑屏；黑屏后进入卧室靠左 | headless --self-check + 窗口运行 + 截图 |
| ⑦ | 卧室结局 | 黑屏后重显卧室靠左；面前 item 显示 E 共 3 次、每次墙色渐变更新；3 次后呼吸解除+卧室门解锁；靠近门按 E 回客厅卧室门前；右手靠墙 item 按 E→白屏结束 | headless --self-check + 窗口运行 + 截图 |
| 约束 | 铁律 | main.tscn 未改；project.godot 仅 [input] breathe 变更([autoload] 不变)；调试命令行动词参数(--phase/--self-check) | git diff + 命令输出 |
| 约束 | 编码红线 | `:=` 推断禁令(0 命中)；.tscn 导出属性在 script= 之后；命名惯例 | Select-String + 代码走查 |


---
## 14. 决策记录、剩余假设与变更记录

### 14.1 已定案（实现按此执行，不得偏离）

- D1 流程状态机：9 阶段（§3.1），C3Flow.gd 驱动；阶段为运行时状态，不持久化。
- D2 进程旗标：全 bool，GameState.process_flags，C3Flow 按阶段写入（§3.2/§3.4 时序）；与 object_states 并存互不读写。
- D3 呼吸机制：BreathSystem + Bubble 组件；缺氧用前置 DarknessMask（follow_player、非全黑、半径渐缩）。
- D4 卧室门：Area2D + InteractHint，gate_flag（bedroom_door_active / bedroom_unlocked），默认无反应（无文本）。
- D5 考卷：复用前置 Item 基类（states 表+gate_flag），白纸占位；三/四号考卷顺序无关、二者都触发→光影。
- D6 光影：DarknessMask 序列（全黑→黑屏渐变重显+重置→门墙消失+粒子震撼→微压暗）；特效库接 ScreenShake+ParticleBurst。
- D7 无限走廊：Corridor.gd（移动墙+纹理滚动、无限平铺、特异点序列、屏息判传送）；走廊墙需平铺纹理（程序化/占位）。
- D8 呼吸输入：最小输入映射扩展——project.godot `[input]` 新增 `breathe`（空格/Space），改前留 project.godot.bak；这是**唯一 project.godot 变更点**（[autoload] 不变）。**（已由 captain 批复，2026-09-05：用户「单击空格呼吸/长按屏息」规格的字面实现，非新玩法提案。）**
- D9 卧室结局：复用 room_bedroom_whitemodel.tscn（卧室靠左 spawn）；墙 face item 三态渐变；呼吸解除；卧室门回客厅；右手墙 item→白屏结束。

### 14.2 剩余假设 / 确认点（评审/集成前显式确认；含前置 J1/J3 确认）

- **J1（前置确认）卧室 room 白模「与厨房/现有 room 同级结构」**：确认——卧室 room = 独立房间场景单元（room_bedroom_whitemodel.tscn），与现有房间（书房/客厅/餐厅）**同级**（每个房间是独立可复用场景单元）；本流程中“厨房”由现有“餐厅”位置**映射**（白模餐厅位，§3.4）。
- **J3（前置确认）「指定游戏进程」具体旗标名/时序**：确认——本规格已在 §3.2 定义完整旗标集合（hold_breath_unlocked / bedroom_door_active / paper_living_collected / paper_kitchen_collected / study_items_unlocked / study_gate_open / light_phase_done / corridor_entered / corridor_end / bedroom_unlocked / bedroom_interactions_done / end_white），并由 C3Flow 在阶段切换时写入（§3.4/§6.2/§7.2/§10.3）；前置 Item.gate_flag 读取即可。
- **J4（新增）走廊“屏息”判定与缺氧覆盖**：走廊“每个特异点须屏息通过”的“屏息”取“长按空格=屏息”（④ 已解锁）；未屏息→传送到第一特异点前 1/4。是否允许缺氧状态覆盖走廊期（长按屏息触发缺氧压暗与“过点”同框）须实现时确认；若冲突，可改为“屏息=长按且未触发缺氧”判定。
- **J5（新增）走廊平铺纹理资产**：走廊墙壁需平铺纹理表现移动；来源=程序化生成（Gradient/棋盘）或占位，**不引入外部真实美术**（白模阶段）；纹理落盘 `assets/ui/corridor_wall.png` + `.import`。

### 14.3 变更记录（Chinese 倒序：变更类型 / 内容 / 影响范围 / 回滚要点）

- v1.0（2026-09-05，planner 起草）：初稿——按用户 ①–⑦ 完整流程映射 9 阶段状态机、12 个进程旗标、C3Flow/BreathSystem/Bubble/Corridor 组件契约、前置组件（InteractHint/门控/DarknessMask/特效库/卧室 room 白模）接入、D1–D9 定案、J1/J3/J4/J5 确认点。影响：C3 关卡玩法（t6 实现/t7 验证/t8 评审；本稿经 t6 拆分 t10–t13）。回滚要点：本文档为约束，不改工程文件；若某条款被推翻，按条款重写对应契约即可（无工程侧回滚）。
- D8 批复（2026-09-05，captain）：批准 project.godot `[input]` 新增 `breathe`（空格键）——用户「单击空格呼吸/长按屏息」字面实现，非新玩法；唯一 project.godot 变更点，改前留 `project.godot.bak` 的约定保持。影响：C3 实现允许改动 project.godot [input]；回滚要点：还原 project.godot [input]（删 breathe）即恢复。
- C3 实现与评审闭环（2026-09-05，团队 spine-c3-development）：前置 6 项（InteractHint/item 门控/DarknessMask/特效库/卧室 room/ItemMarker）+ C3 关卡（呼吸-气泡-缺氧/试卷流程门控/光影 LIGHT A-E/无限走廊三特异点/卧室结局）全部实现；评审三轮闭环（t18 11 findings → t21 7 findings → t23 PASS），物理运行断言（玩家站立 y≈956、卧室搬运 x≈4820、WallRight 禁用）纳入验证。影响：新增 scripts/c3/{breath,flow,corridor,bedroom}/、scenes/c3_level.tscn、assets/ui/corridor_wall.png、project.godot [input] breathe；白模 c3_floor.tscn 与 main.tscn 未动。回滚要点：git revert C3 提交链（b573097/f148a2c/2c9d2d6/f4e29ac/6dc336d 等）；删 breathe 输入即恢复 project.godot。验证：三轮评审 MCP 运行时读回 + headless --phase=1..9 全 EC=0。
