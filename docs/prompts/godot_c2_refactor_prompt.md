# Godot c2 场景重构 Prompt（单背景 + ladder 状态机线性流程）

> 将以下全文作为指令发送给目标 AI。本 prompt 是既有「代码框架」「Item 基类」「剧情对话系统」prompt 的延续，Item 父类（state_id / set_state / apply_state / set_interaction_enabled / 高亮）、GameState 单例（state_changed 信号、状态为字符串）、StoryMonitor 输入锁、DialogueManager（MODE_INTERACTIVE = 0 / MODE_AUTO = 1、队列、dialogue_finished 信号）约定继续生效。
> **本 prompt 取代 `godot_c2_c4_prompt.md` 中 c2 场景的全部旧设计（三区域解锁、黑暗、景深）；c4 部分不受影响，继续有效。冲突时以本 prompt 及《Spine-项目约束.md》《Spine-框架约束.md》为准。**

---

## 角色与任务

你是精通 Godot 4.x（GDScript 2.0）的开发工程师，通过 **Godot MCP 工具**直接操作我的 Godot 工程（项目路径 `C:\Users\31088\Desktop\翌光计划\Spine`）。本次任务：**重构 c2 场景**（`scenes/c2_floor.tscn` + `scripts/scenes/C2Floor.gd`），废弃旧的三区域解锁流程，改为 **ladder 四态状态机驱动的线性流程 + 白屏转场结局**。

## 硬性约束（最高优先级）

1. 所有 `.tscn` / `.gd` / 子资源的新建、修改、删除**必须通过 Godot MCP 完成**，不要只输出代码文本。
2. **文档先行**：改动任何代码/场景前，先创建约束文档 `docs/c2_refactor_constraints.md`，完整覆盖本 prompt 第 1~6 节规则（节点增删清单、状态机定义、交互链路、结局时序）；实现完成后对照该文档逐条自检。
3. 严格对照《Spine-项目约束.md》《Spine-框架约束.md》及 `docs/` 下相关约束文档；冲突时以约束文档为准；不清晰先提问，不要自行假设。
4. 每个文件写入后用 MCP 读回校验，确认无误再继续。
5. **影响面控制**：只动 c2 相关文件；c3 / c4 / bedroom / computer_screen / dialogue_test 等其他场景与脚本一律不改。`scenes/c2_bedroom.tscn` 文件保留（不再可达，不删）。

## 1. 拆除清单（旧设计移除）

在 `c2_floor.tscn` 与 `C2Floor.gd` 中移除以下内容：

| 拆除项 | 具体节点/代码 |
|---|---|
| Depth Parallax 景深 | `DepthParallax` 节点及三个子层 `LayerFar` / `LayerMid` / `LayerNear` 整棵删除；解除 `scripts/components/DepthParallax.gd` 的 ext_resource 引用（**脚本文件本身保留不删**） |
| 房屋三区域划分 | `zone_boundaries` 导出变量；`Environment/WallKitchenLiving`、`Environment/WallLivingStudy` 两个墙体（含碰撞与 Visual） |
| 黑暗设计 | `DarknessMasks`（`MaskLiving` / `MaskStudy`）整棵删除；`dark_shader` / `dark_mat` 子资源删除；`ZoneBlockers`（`BlockerLiving` / `BlockerStudy`）整棵删除 |
| candle / star | `Items/Candle`、`Items/Star` 节点及其 `interact_pressed` 信号连接 |
| bedroomdoor 交互 | `Doors/BedroomDoor` 与 `Doors/LockedBedroomDoor` 节点及其信号连接、ext_resource 引用整项移除（门不再出现、不可交互） |
| 旧场景逻辑 | `C2Floor.gd` 中 `_layout_zones` / `_unlock_living` / `_unlock_study` / `_check_door_unlock` / `ID_CANDLE` / `ID_STAR` 等全部旧逻辑 |

**保留不动**：`floor_template.tscn` 继承结构（地面 / 天花 / 左右边界墙 / 玩家生成 / 摄像机 clamp 参数 `map_min_x=0, map_max_x=3840`）、`Items/Lego1`、`Items/Lego2`、`Items/Lego3` 节点（改造见第 5 节）。

## 2. 背景

- 删除景深后，改为**单张静态背景**：新建 `Sprite2D`（节点名 `Background`，`z_index = -10`），texture = `res://assets/sprites/C2_background.png`。
- 水平铺满整张地图（x: 0 ~ 3840），垂直与地面/天花对齐；按素材实际宽高比缩放，不变形。具体锚定坐标写入约束文档。

## 3. 新对象 curten（窗帘）

- 新建节点 `Items/Curten`：**不可交互**（不继承 Item、无碰撞、无高亮、不响应 E），用 `Sprite2D`（或 `Node2D` + `Sprite2D`）即可。
- texture = `res://assets/sprites/curten.png`。
- 位置：梯子（第 4 节）正上方/贴窗处，与 ladder 视觉成组；具体坐标写入约束文档。

## 4. 新对象 ladder（梯子，四态状态机）

- 新建 `scripts/objects/Ladder.gd`（`class_name Ladder`）+ 场景节点 `Items/Ladder`。**不可交互**（无 touched、无高亮、不响应 E、不参与交互检测）。
- 状态机共 **4 个状态**，由 **GameState 统一监控管理**：key = `"c2_ladder"`，值为字符串 `"0"` / `"1"` / `"2"` / `"3"`，初始 `"0"`。

| 状态值 | 表现（texture） |
|---|---|
| `"0"` | 无贴图（Sprite2D.texture = null 或隐藏） |
| `"1"` | `res://assets/sprites/ladder1.png` |
| `"2"` | `res://assets/sprites/ladder2.png` |
| `"3"` | `res://assets/sprites/ladder3.png` |

- **状态推进唯一入口** `advance_state()`：读取 GameState 当前值 +1（封顶 `"3"`，已到顶则直接返回），写回 GameState。
- **贴图切换唯一出口** `apply_state(state)`：监听 `GameState.state_changed`（key 匹配时）或写状态后统一调用，状态变 → 贴图必变，不允许绕过。
- **读档恢复**：`_ready()` 按 GameState 已有状态重建贴图（例如读档为 `"2"` 则直接显示 ladder2.png）。

## 5. lego 交互链路（核心逻辑）

- `Lego1` / `Lego2` / `Lego3` 沿用 `vanish_item.gd` 行为（交互成功 → 消失，每个 lego 仅可交互一次），但**初始即为可交互**（`interactable = true`，移除旧设计中对 star 解锁的依赖）。
- 连锁反应统一由 `C2Floor.gd` **监听 `GameState.state_changed` 驱动**，item 脚本内不做互相引用。每当任一 lego 的 key 变为 `"1"`，按序执行：
  1. `Ladder.advance_state()`（状态 +1，贴图联动）；
  2. **播放一次音效 `ladder.mp3`**：场景内 `AudioStreamPlayer`（节点名 `LadderSfx`），stream 路径 `@export` 为 `res://assets/audio/ladder.mp3`；**该文件暂不存在（我后续自己补）**——stream 加载失败时必须优雅降级：`push_warning` 提示并跳过播放，**不允许报错中断流程**；
  3. **唤起一次对话**：`DialogueManager.start_dialogue(path, DialogueManager.MODE_INTERACTIVE)`（模式一：锁输入、任意键切句、1s 冷却）。对话文件按**第几次 lego 交互**选取，与具体哪个 lego 解耦：
     - 第 1 次 → `res://dialogues/c2_dialogue1.txt`
     - 第 2 次 → `res://dialogues/c2_dialogue2.txt`
     - 第 3 次 → `res://dialogues/c2_dialogue3.txt`
  - 次数判定以 GameState 中已为 `"1"` 的 lego 总数为准（读档恢复后计数仍正确）。三个对话文件已存在，校验非空即可；缺失则创建 4~6 句 UTF-8 中文占位短句。

## 6. 结局序列（ladder 达到状态 `"3"`）

**触发时点**：第 3 次 lego 交互唤起的 `c2_dialogue3` **播放完毕**后（监听 `DialogueManager.dialogue_finished`，且确认 `"c2_ladder" == "3"`）启动结局；防重入，整局只触发一次。（若希望达到状态 `"3"` 立即触发、不等对话结束，以约束文档为准并在文档中注明。）

时序：

1. `StoryMonitor.lock_input()` 锁定玩家输入；
2. **curten 消失**（`queue_free()`，可选写入 GameState 便于读档一致）；
3. **播放音效 `res://assets/audio/c2开窗.mp3`**（独立 `AudioStreamPlayer`，节点名 `WindowSfx`，文件已存在）；
4. **画面 4 秒内渐变为纯白**：全屏白色 `ColorRect`（置于高层级 `CanvasLayer`，确保盖住一切），Tween `modulate.a` 0 → 1，时长 4.0s；
5. 纯白画面**保持 3 秒**；
6. **停止音效**（`WindowSfx.stop()`）并 `get_tree().change_scene_to_file("res://scenes/computer_screen.tscn")`。

## 交付与验证

1. 文件清单：`docs/c2_refactor_constraints.md`（新）、`scenes/c2_floor.tscn`（改）、`scripts/scenes/C2Floor.gd`（重写）、`scripts/objects/Ladder.gd`（新）、对话文件校验结果。
2. 每个文件 MCP 读回校验 + 对照约束文档自检。
3. 运行验证清单（全部可演示）：
   - 初始：无景深层、无黑暗遮罩、无区域阻挡墙；背景为 C2_background.png；curten 可见；ladder 无贴图；三个 lego 均有交互提示、可交互；
   - 交互任一 lego → 该 lego 消失、ladder 变为 ladder1.png、触发音效钩子（缺文件时仅 warning）、弹出 c2_dialogue1 且锁输入、任意键切句、1s 冷却生效；
   - 第 2 次交互 → ladder2.png + c2_dialogue2；第 3 次 → ladder3.png + c2_dialogue3；
   - c2_dialogue3 播完 → curten 消失、c2开窗.mp3 响起、4 秒渐白、纯白 3 秒、进入 computer_screen 且音效停止；全程玩家无法操作；
   - 存档验证：第 1/2 次交互后保存退出重进，lego 消失状态、ladder 贴图、交互计数正确恢复；
   - 回归：c3 / c4 / bedroom / dialogue_test（T/Y/U 触发）行为不变。
4. 列出需要我在编辑器手动配置的事项（如 ladder.mp3 补入后的 import 确认）。
