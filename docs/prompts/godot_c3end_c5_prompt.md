# Godot C3 结局转场改造 + 新场景 C5_floor Prompt

> 将以下全文作为指令发送给目标 AI。本 prompt 是既有「代码框架」「Item 基类」「剧情对话系统」「desktop_screens」「c2/c3/c4 楼层」prompt 的延续，Item 父类、GameState 单例（state_changed 信号、process_flags）、StoryMonitor 输入锁、DialogueManager（MODE_INTERACTIVE = 0 锁输入任意键切句 / MODE_AUTO = 1、dialogue_finished 信号）、MailWorkManager 解锁中枢、floor_template 继承体系等约定继续生效。
> **冲突时以本 prompt 及《Spine-项目约束.md》《Spine-框架约束.md》为准。**

---

## 角色与任务

你是精通 Godot 4.x（GDScript 2.0）的开发工程师，通过 **Godot MCP 工具**直接操作我的 Godot 工程（项目路径 `C:\Users\31088\Desktop\翌光计划\Spine`）。本次任务两件事：

- **任务 A**：改造 C3 结局转场——玩家与 EndItem 交互触发白屏后，2 秒渐变为纯白 → 切到 computer_screen（0.5 秒淡入），并解锁 mail3 / work3。
- **任务 B**：新建场景 `c5_floor`——C5.png 单背景 + 3 个隐形触发区顺序唤起三段对话 + 七段结尾文字序列 + 游戏退出。

## 硬性约束（最高优先级）

1. 所有 `.tscn` / `.gd` / 子资源 / 文本文件的新建、修改、删除**必须通过 Godot MCP 完成**，不要只输出代码文本。
2. **文档先行**：改动任何代码/场景前，先创建两份约束文档——`docs/c3_end_transition_constraints.md`（任务 A）与 `docs/c5_floor_constraints.md`（任务 B），完整覆盖本 prompt 对应章节的全部规则（节点清单、时序参数、状态键、文件清单）；实现完成后对照文档逐条自检。
3. 严格对照《Spine-项目约束.md》《Spine-框架约束.md》及 `docs/` 下相关约束文档（desktop_screens_constraints、c4_waste_constraints、c3_gameplay_constraints 等）；冲突时以约束文档为准；不清晰先提问，不要自行假设。
4. 每个文件写入后用 MCP 读回校验，确认无误再继续。
5. **影响面控制**：任务 A 只动 `scripts/c3/flow/C3Flow.gd`、`scripts/autoload/MailWorkManager.gd`、`scripts/scenes/ComputerScreen.gd`、`scenes/computer_screen.tscn`；任务 B 只新增 `scenes/c5_floor.tscn`、`scripts/scenes/C5Floor.gd`、`scripts/components/EndingTextSequence.gd`、对话/文本文件，以及 `scripts/scenes/WorkScreen.gd` 一行链接表（第 6 节）。其余场景、脚本、自动加载、输入映射一律不改。

---

## 任务 A：C3 结局转场改造

### A1. 现状（已核实）

- `Items/EndItem`（BedroomEndItem）交互链路：touched → `end_white_requested` → `BedroomEnding._on_end_white`（须 `_sequence_done`）→ `white_screen_end_requested` → `C3Flow.on_white_screen_end()`。
- 当前 `on_white_screen_end()` 只把白屏 ColorRect 直接设为可见（无渐变）并置 `FLAG_END_WHITE` 进程旗标，**无场景切换**。
- `MailWorkManager._recheck()` 现有两个解锁条件（c2_curten→mail2/work2；c4_waste×12→mail4/work4），**无 mail3/work3 条件**；`res://texts/mail3.txt`、`res://texts/work3.txt` 已存在。

### A2. 白屏转场时序（改造 `C3Flow.on_white_screen_end()`）

1. `StoryMonitor.lock_input()`；
2. 保留 `FLAG_END_WHITE` 旗标置位（既有行为）；
3. 复用场景内既有白色 ColorRect（`white_screen_path`），用 Tween 将其 `modulate.a` 从 0 → 1，**时长 2.0 秒**（初始 alpha 须先归 0）；
4. Tween 完成后：`GameState.set_object_state("c3_end", "1")`（触发 A3 解锁）→ `StoryMonitor.unlock_input()` → `get_tree().change_scene_to_file("res://scenes/computer_screen.tscn")`；
5. 防重入：整局只触发一次（旗标或布尔守卫，写入约束文档）。

### A3. mail3 / work3 解锁（改造 `MailWorkManager._recheck()`）

- 新增条件三，与既有两条件同构：`GameState.get_object_state("c3_end") == "1"` → mails 追加 `3`、`target_work = max(target_work, 3)`。
- 幂等、只升不降、无变化不写回的既有设计不得破坏。

### A4. computer_screen 淡入（0.5 秒）

- `scenes/computer_screen.tscn` 新增全屏白色 `ColorRect`（独立顶层 `CanvasLayer`，layer 高于一切现有层，mouse_filter = IGNORE），初始 `modulate.a = 1`；
- `ComputerScreen._ready()` 中 Tween 该 ColorRect alpha 1 → 0，**时长 0.5 秒**，完成后隐藏；
- 从其他入口（开始界面等）进入 computer_screen 时该淡入同样播放，视为统一行为，写入约束文档。

---

## 任务 B：新场景 c5_floor

### B1. 场景骨架（与 C2 / C4 同法）

- 新建 `scenes/c5_floor.tscn`：**继承 `scenes/floor_template.tscn`**，挂新脚本 `scripts/scenes/C5Floor.gd`（`class_name C5Floor extends FloorTemplate`）。
- 地面 / 天花 / 左右边界墙碰撞结构与 c4_floor 一致（高度 817、地板 y≈1008 体系）；`camera_position_offset = Vector2(0, -336.5)`、`camera_smoothing = 0.0` 与 c4 相同。
- **背景**：`Background/Rect`（Polygon2D + texture + uv=素材原生尺寸），与 C2/C4 做法相同——**按 C5.png 原始宽高比等比拉伸，不变形**：高度对齐楼层体系（1280），宽度 = 1280 × 素材宽高比；`map_max_x` = 实际背景宽度。素材实测尺寸与推导数值全部写入 `docs/c5_floor_constraints.md`。
- **素材关卡**：`res://assets/sprites/C5.png` **当前不存在**。若接线时仍缺失，**停止该节并报告，不要自行生成/寻找替代图**；我补图后再继续。约束文档中先按「高度 1280、宽度按实测比例」的规则占位。
- 出生点：`player_spawn_position` 参照 c4（Vector2(320, 956)），按最终地图宽度微调，写入文档。

### B2. 三个隐形触发区（tr1 / tr2 / tr3）

- 场景内新建 `Triggers` 节点，下挂 `Trigger1` / `Trigger2` / `Trigger3`：各为 **Area2D + CollisionShape2D（RectangleShape2D），只有碰撞形状，无任何视觉、不继承 Item、无高亮、不响应 E**。
- 三个触发区沿地图横向依次排布（等间距、宽度/坐标写入约束文档），宽度足以被玩家穿过触发。
- `body_entered`（仅认 Player）→ **首次进入**时唤起一次剧情对话：`DialogueManager.start_dialogue(path, DialogueManager.MODE_INTERACTIVE)`（模式一：锁输入、任意键切句）。
- 对话文本与触发区一一对应、**按编号顺序**：
  - Trigger1 → `res://dialogues/tr1.txt`
  - Trigger2 → `res://dialogues/tr2.txt`
  - Trigger3 → `res://dialogues/tr3.txt`
- 每个触发区**整局只触发一次**：已播标记写 `GameState.process_flags`（键 `c5_tr1_shown` / `c5_tr2_shown` / `c5_tr3_shown`），触发后停用自身 monitoring。
- 三个对话文件**当前不存在**：校验后创建占位——每份 4~6 句 UTF-8 中文短句（一行一句，与既有对话文件格式一致），并在交付报告中标注「占位文本，待我替换」。

### B3. 结尾文字序列（核心演出）

**触发**：tr1 / tr2 / tr3 三段对话**全部播放完毕**（监听 `DialogueManager.dialogue_finished`，三个已播旗标齐；防重入，整局一次）后：

1. `StoryMonitor.lock_input()`；
2. 全屏黑色 `ColorRect`（独立高层 `CanvasLayer`）`modulate.a` 0 → 1，**2.0 秒**渐变为纯黑；
3. 黑屏保持后进入文字序列（新建组件 `scripts/components/EndingTextSequence.gd`，CanvasLayer 形式内嵌于 c5_floor，黑底之上）：

**文字序列规则**：

- 共 **7 个文本文件**，按顺序：`res://dialogues/1.txt`、`2.txt`、`3.txt`、`4.txt`、`5.txt`、`6.txt`、`7.txt`。**当前均不存在**：同 B2 创建占位（每份 3~5 句 UTF-8 中文短句，一行一句），交付报告标注待替换。
- 单文件内**逐行显示**：每行为一个独立 `Label`，屏幕居中（整体垂直水平居中，多行按行堆叠成块居中）；
  - 字号 **18**，行间距 **9**（= 字号的一半）；
  - 每行**亮起效果**：`modulate.a` 0 → 1，**0.5 秒**；亮起后**保持**，随后下一行开始亮起（严格逐行串行）；
  - 白字黑底；字体用项目默认（不引入新字体资源）。
- 单文件最后一句亮起后：**整体保持 3.0 秒** → 当前全部已显示文字在 **0.5 秒**内一起变暗消失（alpha → 0）→ 开始下一个文件。
- 第 7 个文件同样保持 3.0 秒、0.5 秒全体淡出后：**游戏结束，自动退出**（`get_tree().quit()`）。
- 序列全程锁输入；不允许跳过/点击加速（本期不做）。
- 组件接口（写入约束文档）：`start(paths: Array[String])`、信号 `sequence_finished`；逐行/逐文件状态机推进用 Tween + await，不用 Timer 堆叠。

### B4. C5 入口（WorkScreen 链接表一行）

- `scripts/scenes/WorkScreen.gd` 的 `LINK_TARGETS` 增加：`4: "res://scenes/c5_floor.tscn"`，解除 v4 按钮禁用（该处注释本为「待补充」）。
- work4 解锁条件（c4 waste×12）已存在，不动；link4.txt 已存在，校验非空即可。

---

## 明确不做（本期）

- 不做 C5 的存档/读档特判（SAVE_ENABLED 现状不变；已播标记写 process_flags 即可）。
- 不做结尾文字序列的跳过、加速、回放。
- 不改 C3 既有玩法流程（试卷/呼吸/走廊/卧室/白屏前的全部逻辑原样），只改 A2 白屏之后的行为。
- 不改 c2 / c4 场景与其他弹层逻辑。
- 不引入新字体、新音频。

## 交付与验证

1. 文件清单：`docs/c3_end_transition_constraints.md`（新）、`docs/c5_floor_constraints.md`（新）、`scripts/c3/flow/C3Flow.gd`（改）、`scripts/autoload/MailWorkManager.gd`（改）、`scripts/scenes/ComputerScreen.gd`（改）、`scenes/computer_screen.tscn`（改）、`scenes/c5_floor.tscn`（新）、`scripts/scenes/C5Floor.gd`（新）、`scripts/components/EndingTextSequence.gd`（新）、`scripts/scenes/WorkScreen.gd`（改一行）、`dialogues/tr1~tr3.txt` 与 `dialogues/1~7.txt`（新建占位）。
2. 每个文件 MCP 读回校验 + 对照两份约束文档逐条自检。
3. headless 加载 c3_level、computer_screen、c5_floor 均 0 报错。
4. 运行验证清单（全部可演示）：
   - **任务 A**：C3 完成卧室流程后与 EndItem 交互 → 输入锁定、2 秒渐变白 → 进入 computer_screen（0.5 秒从白淡入）→ 打开 mailbox 可见 mail3（正文为 texts/mail3.txt）、打开 work 显示 work3.txt 且工作按钮指向 c4_floor；
   - **任务 B**：进入 c5_floor → 背景按比例铺满不变形 → 依次走过三个触发区 → 依次唤起 tr1/tr2/tr3（锁输入、任意键切句，每个仅一次）→ 三段播完 → 2 秒渐黑 → 1.txt 逐行亮起（0.5s/行、字号 18、行距 9、居中）→ 保持 3 秒 → 0.5 秒全体淡出 → 2.txt……直至 7.txt 淡出后游戏自动退出；
   - work 弹层 v4 按钮可用，链接序列后进入 c5_floor。
5. 回归：c2 / c3 / c4 既有流程、mail2/mail4 解锁、弹层互斥与调试键行为不变。
6. 交付报告中显式列出：C5.png 缺失状态与补图后的待办、10 份占位文本清单、需要我在编辑器手动确认的事项。
