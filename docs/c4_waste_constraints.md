# C4 楼层 waste 交互 + 分段剧情对话：约束文档与验收契约

> 依据：用户任务原文（2026-09-05）：① C4_floor 中 12 个 waste 的通用脚本，继承 item，状态机由 GameState 统一监控管理，玩家按 E 交互后消失；② C4_floor 场景脚本：玩家每交互 4 个 waste 唤起一段剧情对话（参照 godot_dialogue_prompt.md 的第一种对话 MODE_INTERACTIVE），共三段；③ 对话文本存放 dialogues/ 下 c4_dialogue1 / c4_dialogue2 / c4_dialogue3，占位生成；④ 本任务需要文档、需要约束。
> 本文件是本模块的**唯一权威约束**：实现、验证、评审均以本文为准。**硬约定：代码产出前先出本文档。**
> **设计权铁律**：本文只收录用户已提出的规格，不添加任何新玩法/操作设计。

## 1. 用户规格原文（必须全部覆盖，不得增删设计）

1. **12 个 waste 通用脚本**：一个脚本被 12 个 waste 实例共用；**继承 item 基类**；**状态机由全局脚本 GameState 统一监控管理**（状态写入 GameState，key = waste 唯一 ID）；玩家按 E 交互后该 waste **消失**。
2. **C4_floor 场景脚本**：玩家**每交互 4 个 waste** 唤起一段剧情对话；12 个 waste 对应**三段对话**（第 4 / 8 / 12 个交互完成时各一段）。
3. **对话形态**：参照 `godot_dialogue_prompt.md` 的第一种对话 = `MODE_INTERACTIVE`（锁定输入、任意键切句、1s 冷却、播完解锁；经 DialogueManager 统一入口与 FIFO 队列）。
4. **对话文本**：`dialogues/c4_dialogue1.txt`、`c4_dialogue2.txt`、`c4_dialogue3.txt`，本次先生成**占位内容**。

## 2. 工程事实与现有骨架盘点

- 工作区 = res:// = `C:\Users\31088\Desktop\翌光计划\Spine`；引擎 Godot 4.7（`D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`）。
- **Item 基类**（`scripts/objects/item.gd`，class_name Item，extends Area2D）：
  - `state_id`（@export String）：非空时 `set_state()` 写 `GameState.set_object_state(state_id, str(state))`；`_ready` 按存档恢复（不发信号）；
  - `interactable` / `set_interaction_enabled()`、`highlight_enabled` / `set_highlight()`、`gate_flag`；
  - E 键链路：Player `_unhandled_input` 发 `interact_pressed` 信号 → 场景内连接到 item 的 `touched()`；`touched()` 走 gate 检查后调 `_try_touch()`（子类覆写点）。
- **VanishItem**（`scripts/objects/vanish_item.gd`，extends item.gd）：语义与本需求完全一致——`_try_touch()` → `set_state(1)`；`apply_state(1)` = 隐藏节点 + 关闭交互。**waste 通用脚本直接继承 VanishItem**（传递继承 item，满足规格①「继承 item」），不重复造轮子。
- **GameState**：`object_states` 字典 + `state_changed(object_id, new_state)` 信号 + `process_flags` 布尔旗标字典（`set_process_flag` / `get_process_flag`，随存档持久化）。
- **DialogueManager**（Autoload）：`start_dialogue(file_path, mode)`；`MODE_INTERACTIVE=0`（锁输入+1s冷却）、`MODE_AUTO=1`、`MODE_GLITCH=2`；同一时刻一段、FIFO 队列。
- **C2Floor 先例**（`scripts/scenes/C2Floor.gd`）：场景脚本监听 `GameState.state_changed` 驱动解锁连锁；`_apply_saved_progress()` 读档重建。本模块沿用同一模式。
- **c4_floor.tscn 现状**：根节点 C4Floor 是 `floor_template.tscn` 实例（脚本 = FloorTemplate.gd）；无独立场景脚本；Doors 下 LockedBedroomDoor（用户隐藏）+ BedroomDoor（→ c4_bedroom）；Background/Rect 一体化背景（z=-10）；地板碰撞带上边缘运行时 y≈855（用户调整后的现状，白模 Visual 为 y=988 旧带）。
- 命名/红线惯例：脚本文件名 = class_name PascalCase；场景 snake_case；节点 PascalCase；私有成员 `_` 前缀；信号 snake_case；禁止 `:=` 推断 Variant 内建函数返回值（clamp/move_toward/lerp/min/max/randf_range 等）。
- 无 Godot MCP 环境，按仓库惯例以文件工具 + godot.exe headless 读回校验等效替代。

## 3. 模块边界

**In scope（新增/修改）**

- 新增：`docs/c4_waste_constraints.md`（本文档，先于代码）
- 新增：`scripts/objects/waste_item.gd`（waste 通用脚本）
- 新增：`scripts/scenes/C4Floor.gd`（c4 场景脚本：计数 + 对话触发）
- 新增：`dialogues/c4_dialogue1.txt`、`c4_dialogue2.txt`、`c4_dialogue3.txt`（占位）
- 修改：`scenes/c4_floor.tscn`（根节点挂 C4Floor.gd；新增 Items 容器 + 12 个 waste 节点 + 12 条 interact_pressed 连接；**改前刷新 c4_floor.tscn.bak**）

**Out of scope / 实现禁区（违反即 FAIL）**

- 不改 item.gd / vanish_item.gd / GameState.gd / DialogueManager.gd / DialogueBox.gd / Player.gd / player.tscn / FloorTemplate.gd / LevelScene.gd；
- 不新增/删除输入映射（沿用 interact=E）；不改 project.godot；
- 不动 c4_floor.tscn 中 Background/Environment/Doors 等既有节点（只追加 Items 与根脚本）；
- 对话不写死具体文案内容（占位即可）；不实现「对话之外」的新玩法（无奖励、无解锁、无 UI 提示新增）；
- push（本地提交、不 push，用户另行指令除外）。

## 4. API 契约

### 4.1 waste 通用脚本（scripts/objects/waste_item.gd）

- `class_name WasteItem`、`extends "res://scripts/objects/vanish_item.gd"`（传递继承 item 基类）。
- 零额外逻辑：状态机 {0=在场, 1=已消失}、`_try_touch()` → set_state(1)、`apply_state(1)` = 隐藏+关交互、state_id 同步 GameState——全部复用 VanishItem。
- 文件头注释说明用途与「12 实例共用」定位。

### 4.2 场景脚本（scripts/scenes/C4Floor.gd）

- `class_name C4Floor`、`extends FloorTemplate`。
- 常量：
  - `WASTE_IDS: Array[String]` = `["c4_waste1" .. "c4_waste12"]`（与场景节点 state_id 一一对应）；
  - `THRESHOLDS: Array[int]` = `[4, 8, 12]`；
  - `DIALOGUE_PATHS: Dictionary` = `{4: "res://dialogues/c4_dialogue1.txt", 8: "res://dialogues/c4_dialogue2.txt", 12: "res://dialogues/c4_dialogue3.txt"}`；
  - `FLAG_PREFIX := "c4_dialogue_shown_"`（process_flags 键前缀，已播标记随存档持久化）。
- `_ready()`：`super._ready()` → `GameState.state_changed.connect(_on_state_changed)` → `_restore_dialogue_flags()`。
- `_on_state_changed(object_id, new_state)`：
  1. `new_state != "1"` 或 `object_id` 不在 WASTE_IDS → 返回；
  2. 计数 `n = _waste_count()`（WASTE_IDS 中 GameState 状态为 "1" 的个数）；
  3. 取当前满足的**最小未播阈值** t（n ≥ t 且 flag 未置）：置 flag → `DialogueManager.start_dialogue(DIALOGUE_PATHS[t], DialogueManager.MODE_INTERACTIVE)`；一次状态变更至多触发一段。
- `_restore_dialogue_flags()`（读档语义）：按存档中已消失 waste 数量，把已达到的阈值 flag 静默置位，**不重播**已看过的对话（决策 A3）。
- 读回打印：触发时 print `[c4_floor] waste count=N, start dialogue t`；恢复时 print `[c4_floor] restored N wastes, flags synced`。

### 4.3 对话文本（占位）

- 每个文件 4~5 行 UTF-8 中文短句（DialogueManager 按行分句、忽略空行）；占位文案（决策 A4），正式剧情后续替换。

### 4.4 c4_floor.tscn 修改

- 根节点 C4Floor 追加 `script = ExtResource(<C4Floor.gd>)`（实例根脚本覆写，FloorTemplate 行为经 super 全部保留）。
- 新增 `Items`（Node2D）容器，下挂 12 个 waste 节点：
  - 节点名 `Waste1..Waste12`（PascalCase），type=Area2D，script=waste_item.gd；
  - `size = Vector2(48, 48)`、`state_id = "c4_wasteN"`（N=1..12 与节点名尾号一致）、`highlight_enabled = true`（沿用 bedroom/c4 门的高亮惯例，靠近提示可交互）；
  - 子节点：`CollisionShape2D`（RectangleShape2D，共享 sub_resource `waste_col`，基类 _ready 同步 size）、`Visual`（Polygon2D 白模色块 48×48，颜色 Color(0.45, 0.4, 0.35)）。
- **布局**（决策 A2）：4 个/房 × 3 房，贴运行时地板线（碰撞带上边缘 y≈855），waste 中心 y=831（48 高、底贴 855）：
  - 左房 x = 240 / 520 / 800 / 1080；中房 x = 1520 / 1800 / 2080 / 2320；右房 x = 2800 / 3040 / 3280 / 3520。
- 12 条连接：`[connection signal="interact_pressed" from="Player" to="Items/WasteN" method="touched"]`（与 BedroomDoor 既有连接同写法）。

## 5. 信号流

```
E 键 → Player.interact_pressed ──→ WasteN.touched()（范围内、可交互）
  → _try_touch() → set_state(1) → GameState.set_object_state("c4_wasteN","1")
    → apply_state(1)：隐藏 + 关交互（读档恢复时同样重建隐藏态）
    → state_changed 信号 ──→ C4Floor._on_state_changed
        → n = 已消失计数；n 达到 4/8/12 且对应 flag 未播
        → 置 flag + DialogueManager.start_dialogue(c4_dialogueK.txt, MODE_INTERACTIVE)
            → 锁输入、任意键切句（1s 冷却）、播完解锁、队列驱动
```

## 6. 编码红线与惯例

- 禁止 `:=` 推断 Variant 内建函数返回值；显式标注类型。
- 命名：waste_item.gd / C4Floor.gd 与 class_name 一致；节点 PascalCase；常量 SCREAMING_SNAKE_CASE；私有 `_` 前缀。
- waste 状态只经 set_state 路径变更；touched 由基类 gate 链路进入，子类不覆写 touched。

## 7. 验收标准表

| # | 规格 | 验收标准 | 证据方式 |
|---|---|---|---|
| ① | 12 waste 通用脚本 | waste_item.gd 存在、class_name WasteItem、继承 vanish_item（传递 item）；12 个实例共用同一脚本 | 代码走查 + 场景树检查 |
| ② | GameState 统一监控 | 每实例 state_id 唯一（c4_waste1..12）；交互后 GameState 对应键 = "1" | 运行读回 + 代码扫描 |
| ③ | E 交互消失 | 范围内按 E → 隐藏+关交互；范围外无效 | 窗口运行目视 |
| ④ | 每 4 个唤起对话 | 第 4/8/12 个消失后各触发一段 MODE_INTERACTIVE 对话；每段只播一次 | 窗口运行 + stdout 打印 |
| ⑤ | 对话形态 | 锁输入、任意键切句、1s 冷却、播完解锁（复用 DialogueManager/DialogueBox 现行为，零改动） | 回归运行 |
| ⑥ | 文本文件 | dialogues/c4_dialogue1-3.txt 存在、占位内容、按行分句 | 文件检查 |
| ⑦ | 读档恢复 | 中途退出重进：已消失 waste 不重现；已达阈值对话不重播 | 存档验证 |
| ⑧ | 文档先行 + 不越界 | 本文档早于代码；禁区文件零改动；headless 0 错误 | git log + headless |

## 8. verify 命令清单

```powershell
# 1 静态红线扫描（应无输出）
Select-String -Path scripts\objects\waste_item.gd,scripts\scenes\C4Floor.gd -Pattern ':= *(clamp|move_toward|lerp|min|max|randf_range)\('
# 2 禁区扫描：waste 脚本不得直接碰 GameState 写路径以外的语义（只允许继承链路）
Select-String -Path scripts\objects\waste_item.gd -Pattern 'GameState|set_object_state'   # 应无输出（全走 VanishItem 继承）
# 3 备份核对
Test-Path scenes\c4_floor.tscn.bak   # True
# 4 工程整体 headless 加载（exit 0，无 SCRIPT ERROR）
& 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --quit-after 3
# 5 c4 场景 headless 加载（exit 0，无错误）
& 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . res://scenes/c4_floor.tscn --quit-after 3
# 6 窗口运行：交互 4 个 waste → 对话1；再 4 个 → 对话2；再 4 个 → 对话3；对话中锁输入、任意键切句、播完恢复
& 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . res://scenes/c4_floor.tscn
# 7 存档验证：交互 5 个 waste 后退出重进 → 5 个保持消失、对话1不重播、stdout 含 restored 打印
```

## 9. 决策记录与剩余假设

已定案：

- A1 waste 通用脚本继承 VanishItem（与规格①行为完全一致，传递继承 item 基类）。
- A2 waste 布局 4/房 × 3 房，中心 y=831（贴运行时地板线 y≈855）；坐标为本约定值，后续可随美术微调，不属玩法变更。
- A3 读档恢复时已达阈值的对话**不重播**（flag 随存档持久化，静默补位）。
- A4 对话文本为占位文案（规格④「先生成出来占位」）。
- A5 对话触发经 DialogueManager 统一入口（沿用队列语义；若触发时已有对话在进行则自动排队，不丢失）。

剩余假设：

- H1 waste 白模色块 48×48、颜色 Color(0.45,0.4,0.35)，验收只看可辨与可交互。
- H2 highlight_enabled=true（靠近高亮提示），与 c4 BedroomDoor 惯例一致。
- H3 12 个 waste 无先后/区域解锁顺序要求（规格未提），任意顺序交互均只按总数计数。

## 10. 变更记录

- 2026-09-05 初版：c4 waste + 分段对话约束文档先行产出。影响范围：仅新增本文档。回滚要点：删除本文件即可。
