# Godot 场景一/二详细实现 Prompt（start_screen + computer_screen）

> 将以下全文作为指令发送给目标 AI。本 prompt 是既有「代码框架」prompt 的延续，架构约定（GameState、InteractableObject、StoryMonitor 等）继续生效。

---

## 角色与任务

你是精通 Godot 4.x（GDScript 2.0）的开发工程师，通过 **Godot MCP 工具**直接操作我的 Godot 工程。本次任务：**把 assets 目录中的美术资产接入前两个场景，并编写基础交互脚本**。

## 硬性约束（最高优先级）

1. 所有 `.tscn` / `.gd` 的创建与修改**必须通过 Godot MCP 完成**，不要只输出代码文本。
2. 每生成/修改一个文件，**严格对照我提供的《约束文档》逐条核对**；约束文档与本 prompt 冲突时以约束文档为准；要求不清晰时先提问，不要自行假设。
3. **贴图资产必须使用工程中 assets 目录下已有文件**（start_button、cursor_icon、setting_icon、mail_icon、work_icon 及场景背景等）。先用 MCP 列出 assets 目录确认实际文件名与路径，再引用；**禁止用占位色块替代真实贴图**。若某资产缺失，列出来向我确认。
4. 每个文件写入后用 MCP 读回校验，确认语法与节点引用无误再继续。

## 场景一：start_screen

- 文件：`scenes/start_screen.tscn` + `scenes/start_scene.gd`（若框架阶段已建主场景，改为在其基础上修改，并同步修正引用）。
- 场景类型：固定摄像机主场景（沿用既有架构，无角色移动）。
- 内容：
  - 场景中央放置一个可交互对象 **start_button**（使用 assets 中的 start_button 贴图），继承框架中的 `InteractableObject` 基类。
  - 摄像机固定，start_button 位于画面视觉中心。
- 交互逻辑：
  - 点击 start_button → **切换场景到 computer_screen**（`get_tree().change_scene_to_file()`，路径指向场景二的 .tscn）。
  - 场景切换不属于对象状态机状态变更，直接执行跳转即可；如《约束文档》要求记录"游戏已开始"状态，则先写 GameState 再跳转。

## 场景二：computer_screen

- 文件：`scenes/computer_screen.tscn` + `scenes/computer_screen.gd`。
- 场景类型：固定摄像机主场景（纯点击交互，无角色）。
- 背景：使用 assets 中的电脑桌面背景贴图（若存在）。

### 2.1 自定义鼠标光标

- 进入本场景后，**将玩家鼠标光标替换为 assets 中的 cursor_icon**：
  - 优先方案：`Input.set_custom_mouse_cursor(cursor_texture)`，在本场景 `_ready()` 设置，`_exit_tree()` 恢复默认，避免污染其他场景。
  - 若《约束文档》指定其他实现方式，从其规定。

### 2.2 三个可交互图标

- 在场景**左侧竖直排列**三个可交互对象，均继承 `InteractableObject`，等间距布局（可用 `VBoxContainer` 或手动 position 排列，具体以《约束文档》/视觉稿为准）：

| 对象 | 贴图 | 脚本 | 点击行为 |
|---|---|---|---|
| setting_icon | assets/setting_icon | `objects/setting_icon.gd` | **空占位脚本**：继承基类即可，`interact()`/点击响应留空，附 TODO 注释 |
| mail_icon | assets/mail_icon | `objects/mail_icon.gd` | 点击后**展开二级场景 mailbox_screen**（见 2.3） |
| work_icon | assets/work_icon | `objects/work_icon.gd` | **空占位脚本**：同 setting_icon |

### 2.3 mailbox_screen（二级场景）

- 文件：`scenes/mailbox_screen.tscn` + `scenes/mailbox_screen.gd`。
- 性质：mail_icon 点击后展开的**覆盖层二级场景**，不是整场景跳转：
  - 实现为 `CanvasLayer` 弹层（或实例化子场景），打开后覆盖在 computer_screen 之上。
  - 打开期间**底层 computer_screen 的三个图标不可点击**（复用框架的 `lock_input()` 或弹层自身拦截输入）。
  - 提供**关闭方式**（关闭按钮或点击弹层外区域，按《约束文档》定），关闭后返回 computer_screen 并恢复交互。
- mailbox 内部邮件列表与邮件详情本次**只做界面骨架与占位**，邮件内容由后续剧情系统填充，脚本中留好数据接口（如 `load_mails(mail_data: Array)`）。

## 交付与验证

1. 完成后给出文件清单：每个 .tscn/.gd 的路径 + 关键节点结构 + 对外接口。
2. 提供运行验证步骤，确保以下全部可演示：
   - 启动游戏进入 start_screen → 点击 start_button → 进入 computer_screen；
   - computer_screen 中光标显示为 cursor_icon；
   - 左侧三个图标竖直排列、使用真实贴图；
   - 点击 mail_icon → mailbox_screen 弹层打开 → 底层图标不可点 → 关闭弹层后恢复；
   - 点击 setting_icon / work_icon 无报错（空占位）。
3. 列出需要我在编辑器手动处理的事项（如输入映射、贴图导入设置）。
