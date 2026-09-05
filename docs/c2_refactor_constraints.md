# C2 场景重构（单背景 + ladder 四态线性流程）：约束文档与验收契约

> 依据：`docs/prompts/godot_c2_refactor_prompt.md`（2026-09-06 从 NetDrive 拉取），冲突裁决以《Spine-项目约束.md》《Spine-框架约束.md》及本文为准。
> 本 prompt **取代** `godot_c2_c4_prompt.md` 中 c2 场景全部旧设计（三区域解锁、黑暗、景深）；c4 部分不受影响。
> 本文件是本次重构的**唯一权威约束**：实现、验证、评审均以本文为准。**硬约定：代码产出前先出本文档。**

## 1. 用户规格原文（prompt §1~6 必须全部覆盖）

1. **拆除旧设计**：DepthParallax 整棵（脚本文件保留）、`zone_boundaries`、两堵区域墙（WallKitchenLiving / WallLivingStudy）、DarknessMasks、ZoneBlockers、dark_shader/dark_mat、Candle、Star、BedroomDoor + LockedBedroomDoor（含信号连接与 ext_resource）、C2Floor.gd 全部旧逻辑。
2. **单背景**：`Background`（Sprite2D，z_index=-10），texture = `res://assets/sprites/C2_background.png`，水平铺满 0~3840，垂直与地面对齐，按比例缩放不变形。
3. **curten**：`Items/Curten`，不可交互（不继承 Item、无碰撞、无高亮、不响应 E），texture = `res://assets/sprites/curten.png`，位于梯子正上方/贴窗处。
4. **ladder**：`scripts/objects/Ladder.gd`（class_name Ladder）+ `Items/Ladder`，不可交互；四态状态机由 GameState 统一监控（key `"c2_ladder"`，值 "0"~"3"，初始 "0"）；状态→贴图 0=无 / 1=ladder1.png / 2=ladder2.png / 3=ladder3.png；推进唯一入口 `advance_state()`（+1 封顶 3）；贴图唯一出口 `apply_state(state)`；读档按 GameState 重建。
5. **lego 链路**：Lego1/2/3 沿用 vanish_item 行为，**初始即可交互**（移除 star 依赖）；连锁由 C2Floor.gd 监听 `GameState.state_changed` 驱动：lego 变 "1" → ① `Ladder.advance_state()` ② 播一次 `ladder.mp3`（节点 `LadderSfx`，路径 @export；**文件暂缺，加载失败 push_warning 跳过，不得报错中断**）③ 唤起对话（MODE_INTERACTIVE），按**已消失 lego 总数**选取 c2_dialogue1/2/3.txt（与具体哪个 lego 解耦）。
6. **结局**（ladder 到 "3" 且 c2_dialogue3 播完，`DialogueManager.dialogue_finished` 触发，防重入整局一次）：① StoryMonitor.lock_input() ② curten 消失（queue_free，写 GameState 便于读档一致）③ 播 `res://assets/audio/c2开窗.mp3`（节点 `WindowSfx`，文件已存在）④ 全屏白 ColorRect（高层级 CanvasLayer）Tween alpha 0→1 历时 4.0s ⑤ 纯白保持 3s ⑥ WindowSfx.stop() + `change_scene_to_file("res://scenes/computer_screen.tscn")`。

## 2. 工程事实盘点

- 工作区 = res:// = `C:\Users\31088\Desktop\翌光计划\Spine`；引擎 `D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`（headless 读回校验等效 MCP）。
- **c2_floor.tscn 现状**（270 行）：floor_template 实例 + C2Floor.gd；DepthParallax（z=-10，三层）；Environment 含 Floor/Ceiling/WallLeft/WallRight + 两堵区域墙；ZoneBlockers×2；DarknessMasks（z=10）×2；Doors 含 LockedBedroomDoor + BedroomDoor（interactable=false，target=c2_bedroom）；Items 含 Candle(400,946) / Lego3(900,946) / Star(1700,946) / Lego2(2200,946) / Lego1(3200,946)，全部 vanish_item + item_col(120×200) + item_icon 贴图；6 条 interact_pressed 连接。地板碰撞带 y∈[988,1028]。
- **FloorTemplate 空安全**：`_setup_parallax` 用 get_node_or_null、`_connect_auto_doors` 用 find_children——拆 DepthParallax/Doors 不报错。
- **素材**：C2_background.png 1280×422；curten.png 1280×422；ladder1/2/3.png 1011×1024；`c2开窗.mp3` 已存在；`ladder.mp3` **不存在**（用户后续自补）。c2_dialogue1/2/3.txt 已存在（3/3/1 行，非空，沿用不覆盖）。
- **StoryMonitor**：`lock_input()` / `unlock_input()`；**DialogueManager**：`dialogue_finished` 信号、MODE_INTERACTIVE=0；**GameState**：状态为字符串、`state_changed(object_id, new_state)`。
- Lego 交互链路先例 = c4 waste（C4Floor.gd 计数模式）；VanishItem 自身负责隐藏与读档恢复。

## 3. 模块边界

**In scope**

- 新增：`docs/c2_refactor_constraints.md`（本文，先于代码）
- 新增：`scripts/objects/Ladder.gd`
- 重写：`scripts/scenes/C2Floor.gd`（改前留 `C2Floor.gd.bak`）
- 修改：`scenes/c2_floor.tscn`（改前刷新 `c2_floor.tscn.bak`）

**Out of scope / 禁区（违反即 FAIL）**

- 不改 item.gd / vanish_item.gd / GameState.gd / StoryMonitor.gd / DialogueManager.gd / Player.gd / player.tscn / FloorTemplate.gd / LevelScene.gd / DepthParallax.gd / lockedbedroom.gd；
- 不动 c3 / c4 / bedroom / computer_screen / dialogue_test 等其他场景与脚本；`scenes/c2_bedroom.tscn` 保留不删（不再可达）；
- 不新增/删除输入映射；不改 project.godot；不 push；
- 不覆盖既有 c2_dialogue1-3.txt 内容；不新建 ladder.mp3（用户自补）。

## 4. API 契约

### 4.1 Ladder（scripts/objects/Ladder.gd）

- `class_name Ladder`、`extends Node2D`；子节点 `Sprite2D`（场景内建）。
- 常量：`STATE_KEY := "c2_ladder"`；`TEXTURES: Dictionary` = `{1: preload(ladder1.png), 2: preload(ladder2.png), 3: preload(ladder3.png)}`（资源已存在，可安全 preload）。
- `_ready()`：连接 `GameState.state_changed` → `_on_state_changed`；按 GameState 现有值 `apply_state(int(saved))`（空串按 0 处理，**不回写**，避免污染存档）。
- `advance_state()`：**推进唯一入口**。读 `GameState.get_object_state(STATE_KEY)`（空="0"）→ +1 → `min(n, 3)`（显式类型，红线）→ 到顶直接返回 → `GameState.set_object_state(STATE_KEY, str(n))`。
- `_on_state_changed(object_id, new_state)`：key 匹配 → `apply_state(int(new_state))`。
- `apply_state(state: int)`：**贴图唯一出口**。0 → `Sprite2D.texture = null`；1~3 → TEXTURES[state]。任何状态变化必须经此出口。
- 不可交互：无 touched、无高亮、无碰撞形状、不参与 E 检测。

### 4.2 C2Floor.gd（重写，extends FloorTemplate）

- 常量：`LEGO_IDS: Array[String]` = `["c2_lego1","c2_lego2","c2_lego3"]`；`DIALOGUE_PATHS: Dictionary` = `{1: c2_dialogue1, 2: c2_dialogue2, 3: c2_dialogue3}`；`ID_CURTEN := "c2_curten"`；`FLAG_ENDING := "c2_ending_done"`（process_flag，防重入 + 读档一致）。
- `@export var ladder_sfx_path: String = "res://assets/audio/ladder.mp3"`（**禁止 preload**：文件暂缺）。
- 节点引用（@onready）：`_ladder: Ladder = $Items/Ladder`、`_curten: Node2D = $Items/Curten`、`_ladder_sfx: AudioStreamPlayer = $LadderSfx`、`_window_sfx: AudioStreamPlayer = $WindowSfx`、`_fade_rect: ColorRect = $EndingLayer/FadeRect`。
- `_ready()`：`super._ready()` → 连接 `GameState.state_changed`、`DialogueManager.dialogue_finished` → `_restore_progress()`。
- `_on_state_changed(object_id, new_state)`：new_state=="1" 且 id ∈ LEGO_IDS →
  1. `_ladder.advance_state()`；
  2. `_play_ladder_sfx()`：`ResourceLoader.exists(ladder_sfx_path)` 为假 → `push_warning("[c2_floor] ladder sfx missing, skipped")` 返回；真 → load + play；
  3. `n = _lego_count()`；`DIALOGUE_PATHS.has(n)` → `DialogueManager.start_dialogue(DIALOGUE_PATHS[n], DialogueManager.MODE_INTERACTIVE)`（n>3 不触发）。
- `_on_dialogue_finished()`：`GameState.get_object_state("c2_ladder") == "3"` 且未播结局 → `_start_ending()`。
- `_start_ending()`（防重入：入口先查/置 `FLAG_ENDING`）：
  1. `GameState.set_process_flag(FLAG_ENDING, true)`；`StoryMonitor.lock_input()`；
  2. curten：`GameState.set_object_state(ID_CURTEN, "1")` + `_curten.queue_free()`；
  3. `_window_sfx.play()`；
  4. Tween `_fade_rect.modulate.a` 0→1，4.0s；`await tween.finished`；
  5. `await get_tree().create_timer(3.0).timeout`；
  6. `_window_sfx.stop()`；`get_tree().change_scene_to_file("res://scenes/computer_screen.tscn")`。
- `_restore_progress()`（读档语义）：
  - `ID_CURTEN == "1"` → curten 直接 queue_free（结局后重进不重现）；
  - `"c2_ladder" == "3"` 且 `FLAG_ENDING` 未置 → `call_deferred("_start_ending")`（决策 D4：对话3 中途退出重进时补触发结局，防死档）；
  - lego 消失态与 ladder 贴图分别由 VanishItem / Ladder 各自 _ready 恢复，本函数不重复处理。

### 4.3 c2_floor.tscn 修改

**拆除**（与 §1.1 一一对应）：ext_resource id 3/4/5（DepthParallax.gd、locked_bedroom_door.tscn、lockedbedroom.gd）；sub_resource dark_shader、dark_mat、wall_lintel_col、blocker_col、door_col；节点 DepthParallax 整棵、Environment/WallKitchenLiving、Environment/WallLivingStudy、ZoneBlockers 整棵、DarknessMasks 整棵、Doors 整棵（含双门）、Items/Candle、Items/Star；连接 Candle/Star/BedroomDoor 三条。

**保留**：floor_template 继承结构（Environment 地面/天花/左右墙及 Visual、Player、相机 clamp）；Items/Lego1/2/3 节点与其连接；ext_resource id 1/2/6/7。

**改造 Lego1/2/3**：删除 `interactable = false`（基类默认 true，初始即可交互）；其余（position / state_id / size / 贴图）不动。

**新增**：

| 节点 | 类型 | 关键属性 |
|---|---|---|
| `Background` | Sprite2D（根直下） | z_index=-10；texture=C2_background.png；position (1920, 619.5)；scale (3, 3)（1280×422 → 3840×1266，水平铺满，垂直中心对齐游戏带 y∈[211,1028]，决策 D1） |
| `Items/Ladder` | Node2D + Ladder.gd | position (1920, 578)（决策 D2：贴图 scale 0.8 → 809×819，底边贴地板线 988，居中于原门位 x=1920，与 curten 成组） |
| `Items/Ladder/Sprite2D` | Sprite2D | scale (0.8, 0.8)；texture 初始为空（状态 0） |
| `Items/Curten` | Node2D | position (1920, 320)（决策 D3：梯子正上方贴窗处） |
| `Items/Curten/Sprite2D` | Sprite2D | texture=curten.png；scale (0.8, 0.8)（1024×338，与 ladder 同比例成组） |
| `LadderSfx` | AudioStreamPlayer（根直下） | 不设 stream（运行时按 @export 路径加载，缺失降级） |
| `WindowSfx` | AudioStreamPlayer（根直下） | stream=c2开窗.mp3 |
| `EndingLayer` | CanvasLayer | layer=30（高于 DialogueBox 的 20，盖住一切） |
| `EndingLayer/FadeRect` | ColorRect | 全屏锚点 full rect；color=白；modulate.a=0 初始；mouse_filter=ignore |

- load_steps 按最终 ext/sub 资源数更新；新增贴图/音频 ext_resource 使用 .import 中的 uid。

## 5. 信号流

```
E 键 → Player.interact_pressed ──→ LegoN.touched() → set_state(1)
  → GameState.set_object_state("c2_legoN","1") → VanishItem 隐藏（读档同）
  → state_changed ──→ C2Floor._on_state_changed
      → Ladder.advance_state() → GameState["c2_ladder"]=+1
          → state_changed ──→ Ladder._on_state_changed → apply_state → 换贴图
      → LadderSfx（缺失仅 warning）
      → DialogueManager.start_dialogue(c2_dialogue{n}, MODE_INTERACTIVE)
c2_dialogue3 播完 → dialogue_finished ──→ C2Floor._on_dialogue_finished
  → lock_input → curten 消失(写 GameState) → WindowSfx.play
  → FadeRect 4s 渐白 → 保持 3s → stop → change_scene_to_file(computer_screen)
```

## 6. 编码红线与惯例

- 禁止 `:=` 推断 Variant 内建函数返回值（min/max/clamp/move_toward/lerp/randf_range），显式标注类型。
- 命名：Ladder.gd 与 class_name 一致；节点 PascalCase；常量 SCREAMING_SNAKE_CASE；私有 `_` 前缀；信号 snake_case。
- ladder 状态只经 advance_state → GameState → apply_state 路径变更；item 脚本互不引用。
- 信号连接在代码中完成（项目约束）；既有场景内 interact_pressed 硬连线保留（测试 Demo 豁免惯例）。

## 7. 验收标准表

| # | 规格 | 验收标准 | 证据 |
|---|---|---|---|
| ① | 拆除清单 | §4.3 拆除项全部消失；场景无 DepthParallax/黑暗/区域墙/阻挡/门/candle/star | 场景走查 + 运行 |
| ② | 单背景 | Background=C2_background.png，铺满 3840，z=-10 | 运行目视 |
| ③ | curten | 初始可见、不可交互（E 无反应、无高亮） | 运行 |
| ④ | ladder 四态 | 初始无贴图；状态经 GameState 推进、贴图联动；读档重建 | 运行 + stdout |
| ⑤ | lego 链路 | lego 初始可交互；第 n 次交互 → ladder 状态 n + c2_dialogue{n}（锁输入/任意键切句/1s 冷却）；ladder.mp3 缺失仅 warning | 运行 |
| ⑥ | 结局 | dialogue3 播完 → 锁输入、curten 消失、开窗音效、4s 渐白、3s 纯白、进 computer_screen、音效停止；整局一次 | 运行 |
| ⑦ | 读档 | 第 1/2 次后重进：lego 消失、ladder 贴图、计数正确；结局后重进 curten 不现 | 存档验证 |
| ⑧ | 影响面 | 禁区文件零改动；c3/c4/dialogue_test 回归 headless 0 错误 | git diff + headless |

## 8. verify 命令清单

```powershell
# 1 红线扫描（应无输出）
Select-String -Path scripts\objects\Ladder.gd,scripts\scenes\C2Floor.gd -Pattern ':= *(clamp|move_toward|lerp|min|max|randf_range)\('
# 2 备份核对
Test-Path scenes\c2_floor.tscn.bak, scripts\scenes\C2Floor.gd.bak   # 均 True
# 3 headless 加载（均无 SCRIPT ERROR）
& 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . res://scenes/c2_floor.tscn --quit-after 3
# 4 回归：c3 / c4 / dialogue_test 同样 headless 加载
# 5 窗口运行 §7 验收清单
& 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . res://scenes/c2_floor.tscn
```

## 9. 决策记录与剩余假设

已定案：

- D1 背景 scale=3（按宽度铺满 3840），position (1920, 619.5) 垂直居中对齐游戏带；超出上下黑边区域由画幅遮罩自然裁切，不变形。
- D2 ladder 位置 (1920, 578)、贴图 scale 0.8（原门位/窗下，底边贴地板线 988）；坐标为本约定值，后续可随美术微调，不属玩法变更。
- D3 curten 位置 (1920, 320)、贴图 scale 0.8，与 ladder 同比例成组（梯子正上方贴窗处）。
- D4 对话3 播放中途退出重进：`_ready` 检测 ladder=="3" 且结局未播 → 补触发结局（防死档；prompt 只要求防重入，此为存档健壮性补充，已在文中注明）。
- D5 curten 消失写 `GameState["c2_curten"]="1"`（prompt「可选写入」采纳），读档一致。
- D6 结局触发以 prompt 默认：等 c2_dialogue3 播完（非到达状态 3 立即触发）。
- D7 EndingLayer layer=30（高于 DialogueBox 20）；FadeRect 初始 modulate.a=0、白色、mouse_filter=ignore。
- D8 c2_dialogue1-3.txt 已存在且非空（3/3/1 行），沿用不覆盖。

剩余假设：

- H1 Lego1/2/3 维持 item_icon.png 占位贴图与 120×200 检测区不变。
- H2 WindowSfx stream 在场景内直接配置（文件已存在，可安全引用）。
- H3 ladder.mp3 补入后需确认 import 正常（编辑器手动事项）。

## 10. 变更记录

- 2026-09-06 初版：c2 重构约束文档先行产出（prompt §1~6 全覆盖）。影响范围：仅新增本文档。回滚要点：删除本文件即可。
