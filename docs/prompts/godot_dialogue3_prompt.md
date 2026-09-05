# Godot 对话模式三（故障散落字幕）实现 Prompt

> 将以下全文作为指令发送给目标 AI。本 prompt 是「剧情对话系统」prompt（godot_dialogue_prompt.md）的延续，其中 DialogueManager / DialogueBox / FIFO 队列 / T·Y 测试按键等约定继续生效。冲突时以本 prompt 及《Spine-项目约束.md》《Spine-框架约束.md》为准。

---

## 角色与任务

你是精通 Godot 4.x（GDScript 2.0）的开发工程师，通过 **Godot MCP 工具**直接操作我的 Godot 工程（项目路径 `C:\Users\31088\Desktop\翌光计划\Spine`）。本次任务：**为剧情对话系统新增第三种对话模式 MODE_GLITCH（故障散落字幕），创建测试对话 `dialogues/dialogue3.txt`，按 U 唤起**。

## 硬性约束（最高优先级）

1. 所有 `.tscn` / `.gd` / `.txt` / `.gdshader` / `project.godot` 的创建与修改**必须通过 Godot MCP 完成**，不要只输出代码文本。
2. **文档先行**：产出任何代码前，先创建设计约束文档 `docs/design/dialogue3_glitch_constraints.md`（位置可按 docs/ 现有约定调整），完整覆盖本 prompt 第 1~6 节全部规则；代码完成后回读该文档逐条自检。
3. 每生成/修改一个文件，**严格对照《Spine-项目约束.md》《Spine-框架约束.md》及 docs/ 下相关约束文档逐条核对**；冲突时以约束文档为准；不清晰先提问，不要自行假设。
4. **不得改动模式一（MODE_INTERACTIVE）/ 模式二（MODE_AUTO）的既有行为**；DialogueManager 的队列语义（同一时刻一段对话、FIFO 排队）保持不变。
5. 每个文件写入后用 MCP 读回校验，确认无误再继续。

## 1. 新模式定义

- `DialogueManager` 的模式枚举追加 `MODE_GLITCH = 2`。
- **生命周期与 MODE_AUTO 完全一致**：不锁定输入、不接受任何按键切句、自动切换、结束发出 `dialogue_finished` 并驱动队列下一段。
- **唯一差异 = 显示方式**（句级位置 + 逐字散落排版 + 故障视觉），规则见第 2~5 节。

## 2. GlitchDialogueBox（新 UI，不复用底部对话框）

- 文件：`ui/glitch_dialogue_box.tscn` + `scripts/ui/GlitchDialogueBox.gd`，`extends CanvasLayer`（高 layer，盖在场景内容之上）。
- `DialogueManager._ready()` 中实例化并存为 `_glitch_box`，连接其 `dialogue_finished`；`start_dialogue` / `_begin` 按 mode 路由到对应 box（模式二走原 `_box`，模式三走 `_glitch_box`）。
- 每句话**动态生成一组逐字 `Label`**（挂在全屏 `Control` 容器下），切句/结束时统一销毁。

## 3. 逐字散落排版

- 每句话第 1 个字放在基准点 `base_pos`（由第 4 节象限规则确定）。
- 第 n+1 个字的位置：
  - `x = 前一个字 x + 单字步进`（步进取字体对该字的 `get_string_size().x`，无则退化为 `font_size`）；
  - `y = 前一个字 y + 随机偏移`，偏移量 |dy| ∈ **[10, 30] px**，方向（上/下）随机，即 `dy = ±randf_range(10.0, 30.0)`。
- **出现节奏：每显示一个字后等待 0.15 秒再生成下一个字**（用 `SceneTreeTimer` 或 `Timer` 实现），形成非整齐排版的打字机效果。
- **单句时长**：该句全部字显示完毕后**再停留 4 秒**（复用 `AUTO_LINE_SEC` 常量），随后自动切下一句；最后一句停留 4 秒后结束对话（隐藏 UI、发 `dialogue_finished`、触发队列）。若约束文档对计时起点另有定义，以约束文档为准。

## 4. 象限规则（句级显示位置）

- 以摄像机可视区域（CanvasLayer 为屏幕空间，直接取 `get_viewport().get_visible_rect()`）中心十字划分为**四个象限**：左上 / 右上 / 左下 / 右下。
- 选象限规则（维护最近两句的象限历史）：
  - 第 1 句：四个象限中随机任取；
  - 第 2 句：排除第 1 句所在象限后随机；
  - 第 n 句（n ≥ 3）：**排除前两句所在象限**，从剩余两个象限中随机。
- `base_pos` 取所选象限的中心点；生成前预估整行宽度（字数 × 步进 + 抖动余量），若右端将超出屏幕右缘，左移 `base_pos.x` 做 clamp，保证整行在屏内。
- 「显示在摄像机偏左或偏右侧」由象限选择天然满足：左象限 = 偏左，右象限 = 偏右。

## 5. 故障 / 破碎字体效果

- 新建 `assets/shaders/glitch_char.gdshader`（canvas_item 类型），每个字 Label 挂同一个 `ShaderMaterial`，实现：
  - 时间驱动的**水平切片错位**（glitch slice offset）；
  - **RGB 通道分离**（chromatic aberration）；
  - 随机**闪烁**（alpha 抖动 / 瞬时隐现）。
  - 强度与频率导出为 shader uniform 参数，便于后续调整。
- 每个字生成时赋予随机小旋转（±5°）与轻微缩放差异（0.9~1.1 倍）。
- 脚本侧每个字每 0.05 秒做一次 **±2px 位置抖动**（在排版位置基础上叠加偏移，不得破坏第 3 节的散落基准坐标）。

## 6. 测试对话与触发

- 创建 `dialogues/dialogue3.txt`：4~6 句 UTF-8 中文短句，**每句 ≤12 字**（保证散落排版不溢出屏幕），内容随意。
- `project.godot` 输入映射追加 `dialogue_u`（U 键），写法与既有 `dialogue_t` / `dialogue_y` 一致。
- `scripts/scenes/DialogueTest.gd` 追加分支：

| 按键 | 行为 |
|---|---|
| **U** | `DialogueManager.start_dialogue("res://dialogues/dialogue3.txt", DialogueManager.MODE_GLITCH)` |

- 触发守卫逻辑与 T/Y 相同：`StoryMonitor.input_locked` 时不生效；对话激活期间按 U 进入队列而非打断；触发后 `set_input_as_handled()`。

## 交付与验证

1. 文件清单：`docs/design/dialogue3_glitch_constraints.md`、`scripts/autoload/DialogueManager.gd`（改）、`ui/glitch_dialogue_box.tscn`、`scripts/ui/GlitchDialogueBox.gd`、`assets/shaders/glitch_char.gdshader`、`dialogues/dialogue3.txt`、`scripts/scenes/DialogueTest.gd`（改）、`project.godot`（改）。
2. 每个文件 MCP 读回校验 + 对照约束文档自检。
3. 运行验证清单（全部可演示）：
   - 按 U → dialogue3 出现；期间玩家可正常操作，按键不能切句；
   - 逐字以 0.15s 节奏出现，后一个字在前一个字**右侧**、上下随机偏移 **10~30px**，整句排版不整齐；
   - 逐句观察所在象限：任意一句与其**前两句**均不在同一象限，且整体呈摄像机偏左/偏右分布；
   - 所有字带故障效果（切片错位 / RGB 分离 / 闪烁 / 抖动）；
   - 播完自动结束；dialogue3 进行中按 T/Y（或 T/Y 进行中按 U）→ 正常排队，前一段结束后自动开始，不重叠、不丢失；
   - 回归验证：按 T / Y，模式一、模式二行为与改动前完全一致。
4. 列出需要我在编辑器手动配置的事项（如有）。
