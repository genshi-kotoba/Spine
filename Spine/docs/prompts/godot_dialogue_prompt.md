# Godot 剧情对话系统实现 Prompt

> 将以下全文作为指令发送给目标 AI。本 prompt 是既有「代码框架」prompt 的延续，框架中的 GameState / lock_input / unlock_input 约定继续生效。**注意：本 prompt 对对话系统的定义优先于框架 prompt 中 StoryMonitor 的"类型二对话"描述，两处冲突时以本 prompt 为准。**

---

## 角色与任务

你是精通 Godot 4.x（GDScript 2.0）的开发工程师，通过 **Godot MCP 工具**直接操作我的 Godot 工程。本次任务：**实现剧情对话系统，并接入两个测试对话**。

## 硬性约束（最高优先级）

1. 所有 `.tscn` / `.gd` / `.txt` 的创建与修改**必须通过 Godot MCP 完成**，不要只输出代码文本。
2. 每生成/修改一个文件，**严格对照我提供的《约束文档》逐条核对**；冲突时以约束文档为准；不清晰先提问，不要自行假设。
3. 每个文件写入后用 MCP 读回校验，确认无误再继续。

## 1. 对话管理器 `DialogueManager`（Autoload 单例）

- 文件：`autoload/dialogue_manager.gd`，注册为 Autoload。
- 对外接口：
  - `start_dialogue(file_path: String, mode: int)` —— 请求开始一段对话。
  - 信号 `dialogue_started`、`dialogue_finished`。
- **队列机制**：同一时刻只允许一段对话进行。若前一段对话未结束就收到新的 `start_dialogue` 请求，**新对话进入队列等待**，当前对话结束后自动按 FIFO 顺序开始队列中的下一段。
- 对话模式枚举：`MODE_INTERACTIVE = 0`（按键切换）、`MODE_AUTO = 1`（自动切换）。

## 2. 对话 UI

- 文件：`ui/dialogue_box.tscn` + `ui/dialogue_box.gd`（若框架阶段已建，在其上修改）。
- 结构：`CanvasLayer`（高层级，保证盖在所有场景内容之上）+ 文本控件（`Label` 或 `RichTextLabel`）。
- **文本位置：画面左右居中，距画面下边缘 100px**。用锚点/容器布局实现，分辨率变化时仍保持该相对位置。
- 无对话时隐藏；对话开始显示、结束隐藏。

## 3. 对话文本文件

- 目录：`dialogues/`。
- 由你创建两个测试文件 `dialogues/dialogue1.txt`、`dialogues/dialogue2.txt`，内容随意（各 4~6 句短句即可，UTF-8 中文）。
- **读取规则**：按行读取，**每遇到换行分割为一句话**，忽略空行；整段对话 = 有序句子数组。

## 4. 两种对话模式

### 模式一：MODE_INTERACTIVE（按键切换）—— 对话1用此模式

- 对话期间**玩家不能进行除"切换下一句"以外的任何操作**：调用框架的 `lock_input()` 锁定全部游戏输入，对话结束后 `unlock_input()`。
- **按下任意按键 → 切换到下一句**。
- **冷却限制**：每次成功切换一句话后，**需等待 1 秒**才接受下一次切换输入；冷却期内的按键被忽略。
- 当前已是最后一句时再按任意键 → **结束对话**（隐藏 UI、解锁输入、发出 `dialogue_finished`、触发队列下一段）。
- 对话 UI 自身的按键监听使用 `_unhandled_input` 并 `get_viewport().set_input_as_handled()`，防止按键穿透到游戏场景。

### 模式二：MODE_AUTO（自动切换）—— 对话2用此模式

- 对话期间**玩家可以正常操作**（不锁定输入）。
- **不接受任何按键切换**；每句话显示 **4 秒后自动切换到下一句**。
- 最后一句显示 4 秒后自动结束对话（隐藏 UI、发出 `dialogue_finished`、触发队列下一段）。
- 用 `SceneTreeTimer` 或 `Timer` 节点实现计时。

## 5. 测试触发

在测试场景（沿用框架关卡场景或新建 `scenes/dialogue_test.tscn`，以《约束文档》为准）中接入：

| 按键 | 行为 |
|---|---|
| **T** | `DialogueManager.start_dialogue("res://dialogues/dialogue1.txt", MODE_INTERACTIVE)` |
| **Y** | `DialogueManager.start_dialogue("res://dialogues/dialogue2.txt", MODE_AUTO)` |

- 测试按键监听只在对话未激活时生效；对话激活期间 T/Y 不重复触发（模式一锁输入天然满足；模式二期间按 T/Y 应进入队列而非打断）。
- T/Y 需注册输入映射或直接用 keycode 判断，按《约束文档》定。

## 交付与验证

1. 文件清单：`autoload/dialogue_manager.gd`、`ui/dialogue_box.tscn/.gd`、`dialogues/dialogue1.txt`、`dialogues/dialogue2.txt`、测试场景改动。
2. 每个文件 MCP 读回校验 + 对照约束文档自检。
3. 运行验证清单（全部可演示）：
   - 按 T → 对话1出现，文本左右居中、距下边缘 100px；
   - 对话1期间玩家移动/交互输入全部无效；按任意键切下一句；快速连按时 1 秒冷却生效；切完最后一句对话结束、操作恢复；
   - 按 Y → 对话2出现；期间玩家可正常操作；按键不能切句；每句 4 秒自动切换；播完自动结束；
   - 对话1进行中按 Y（或对话2进行中按 T）→ 第二段对话排队，前一段结束后自动开始，不重叠、不丢失。
4. 列出需要我在编辑器手动配置的事项（输入映射等）。
