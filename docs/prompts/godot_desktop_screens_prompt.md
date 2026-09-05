# Godot 电脑桌面二级界面重构 Prompt（mailbox_screen 改造 + work_screen 新增）

> 将以下全文作为指令发送给目标 AI。本 prompt 是既有「代码框架」「Item 基类」「剧情对话系统」「c2 场景重构」prompt 的延续，InteractableObject（interact / 信号）、GameState 单例（state_changed、状态为字符串、save/load）、StoryMonitor 输入锁、MainScene 纯点击交互约定继续生效。冲突时以本 prompt 及《Spine-项目约束.md》《Spine-框架约束.md》为准。

---

## 角色与任务

你是精通 Godot 4.x（GDScript 2.0）的开发工程师，通过 **Godot MCP 工具**直接操作我的 Godot 工程（项目路径 `C:\Users\31088\Desktop\翌光计划\Spine`）。本次任务：**重构电脑桌面二级界面**——改造 `mailbox_screen`、新增 `work_screen`、新建全局文本管理脚本，并接入邮件/工作文本的解锁流程。

## 硬性约束（最高优先级）

1. 所有 `.tscn` / `.gd` / `.txt` 的创建与修改**必须通过 Godot MCP 完成**，不要只输出代码文本。
2. **文档先行**：改动任何代码/场景前，先创建约束文档 `docs/desktop_screens_constraints.md`，完整覆盖本 prompt 第 1~7 节规则；实现完成后对照该文档逐条自检。
3. 严格对照《Spine-项目约束.md》《Spine-框架约束.md》及 `docs/` 下相关约束文档；冲突时以约束文档为准；不清晰先提问，不要自行假设。
4. 每个文件写入后用 MCP 读回校验，确认无误再继续。
5. **素材核对**：开始前先列出 `assets/sprites/` 确认 `mailbox.png`、`close_button.png`、`work_screen.png` 是否存在；**缺失立即汇报**，并用占位方案（纯色 TextureRect + 导出变量留路径）继续，不得中断整体流程。

## 1. computer_screen 场景改动

- **删除 SettingIcon**：移除 `SettingIcon` 节点及其 ext_resource、`setting_shape` 子资源；`scripts/objects/SettingIcon.gd` 文件保留不删。
- **WorkIcon 改造**（`scripts/objects/WorkIcon.gd`）：**取消点击直接跳场景**，改为发出信号 `open_work`（仿照 `MailIcon.open_mailbox` 模式），由 `ComputerScreen.gd` 监听并打开 work_screen 弹层（第 4 节）。
- `ComputerScreen.gd`：新增 `_work_screen` 实例管理，打开/关闭逻辑与 mailbox 完全一致（打开时 `StoryMonitor.lock_input()`，`closed` 信号后 `unlock_input()`；同类弹层同一时刻只允许一个；mailbox 与 work_screen 可同时各自一个或互斥——以约束文档为准，默认互斥：打开一个前关闭另一个）。

## 2. 全局管理脚本 MailWorkManager（Autoload）

- 新建 `scripts/autoload/MailWorkManager.gd`，注册 Autoload 名 `MailWorkManager`。**邮件与 work 文本的统一数据中枢**。
- **文本目录**：新建 `texts/` 目录，文件清单（全部当前缺失，由你创建 UTF-8 中文占位内容）：
  - `mail1.txt` / `mail2.txt` / `mail4.txt`（邮件正文，各 6~10 行占位；**无 mail3，编号刻意跳号**）
  - `work1.txt` / `work2.txt` / `work3.txt` / `work4.txt`（工作文本，各 6~10 行占位）
  - `link1.txt` / `link2.txt` / `link3.txt`（各 ≥2 行：第一行标题、第二行正文）
- **监听 `GameState.state_changed`**，解锁规则：

| 触发条件（GameState） | 结果 |
|---|---|
| `"c2_curten"` 变为 `"1"`（c2_floor 窗帘消失） | 邮件列表追加 mail2；work 版本升为 2（载入 work2.txt 替换 work_screen 文本框内容） |
| `"c4_waste1"` ~ `"c4_waste12"` **全部**为 `"1"`（c4_floor 12 个 waste 全部已交互消失） | 邮件列表追加 mail4；work 版本升为 4（载入 work4.txt 替换） |

  - 每次 state_changed 到达时重查一次完整条件（不只信单条事件），保证读档后补触发正确。
  - **依赖修补**：c2 重构若未将 curten 消失写入 GameState，本次一并修改 `C2Floor.gd`：curten 消失时 `GameState.set_object_state("c2_curten", "1")`，读档恢复时按该状态隐藏 curten。
- **持久化**（写入 GameState，读档恢复）：
  - `"desktop_mails_unlocked"`：已解锁邮件编号的有序列表，如 `"1"` → `"1,2"` → `"1,2,4"`；
  - `"desktop_work_version"`：当前 work 版本号字符串 `"1"`/`"2"`/`"3"`/`"4"`，初始 `"1"`。
- **对外接口**：
  - `get_unlocked_mails() -> Array[int]`（有序，如 `[1, 2, 4]`）
  - `get_mail_text(mail_id: int) -> String`（读 `texts/mail{id}.txt` 全文）
  - `get_work_version() -> int`、`get_work_text() -> String`
  - 信号 `mails_changed`、`work_version_changed`（弹层打开期间解锁也能即时刷新）。
- 版本升级幂等：重复触发不重复追加、不降版本（只升不降）。

## 3. mailbox_screen 改造（`scenes/mailbox_screen.tscn` + `MailboxScreen.gd`）

保持 `CanvasLayer`（layer 高层级）+ Dim 遮罩结构，Panel 内部全部重做：

- **背景**：`TextureRect` texture 换为 `res://assets/sprites/mailbox.png`；**Panel 尺寸 = mailbox.png 原始像素尺寸**（`expand_mode` 关闭、不缩放图片），图片天然铺满 Panel。整窗初始居中屏幕。
- **close_button**：Panel **右上角**，`TextureButton`，texture = `res://assets/sprites/close_button.png`，**按图片原始尺寸**（不缩放）；点击 = 关闭当前 mailbox_screen（发 `closed` + `queue_free`，沿用现有 close() 语义）。旧 `CloseButton`（文字 X）与旧 `MailList` 节点删除。
- **拖拽移动**：Panel 上部设拖拽条区域（`DragBar`，高度写入约束文档，建议 40px 或按 mailbox.png 顶部留白定）；鼠标左键按住 DragBar 拖动整窗，**clamp 保证窗口任何部分不超出屏幕可视区域**（`get_viewport().get_visible_rect()`）。
- **邮件文本框**：`ScrollContainer` + `RichTextLabel`（`scroll_active` 开启、垂直滚动条可见），支持**滚轮上下滑动**；位置占 Panel 主体区域。
- **pre_button / next_button**：文本框**上方**左右各一个按钮（左 = pre_button、右 = next_button，text 可用 `◀` / `▶` 或见约束文档）：
  - 点击切换到**已解锁邮件列表**中的上一封 / 下一封；
  - **已无上一封/下一封时：切换为当前邮件**（即重显当前邮件，同样走第 3.1 节刷新动画），不循环跳变。
- **初始载入**：打开弹层时显示邮件列表第一封（初始即 mail1）。

### 3.1 老式电脑刷新显示效果（打开弹层与 pre/next 切换均触发）

- 将文本框显示区域**从上到下分为四部分**：第一部分占**上半画面（1/2）**，剩余三部分**平分下半画面**（各 1/6）。
- 推荐实现：4 块与文本框底色一致的 `ColorRect` 盖板（Cover1~Cover4）分别盖住四个区域，文本一次性填充后被完全遮盖；随后按序隐藏盖板。
- 时序：Cover1 揭开 → **等 0.2s** → Cover2 揭开 → **等 0.1s** → Cover3 揭开 → **等 0.1s** → Cover4 揭开。形成逐段刷新的老式显示器效果。
- 动画期间忽略 pre/next 重复点击（防叠动画），动画结束恢复。

## 4. work_screen 新增（`scenes/work_screen.tscn` + `scripts/scenes/WorkScreen.gd`）

- 与改造后的 mailbox_screen **同一骨架**：`CanvasLayer` + Dim + Panel（尺寸 = `work_screen.png` 原始尺寸）+ 背景 TextureRect（`res://assets/sprites/work_screen.png`，缺失按硬性约束 §5 处理）+ 右上角 close_button（同款 TextureButton，复用逻辑可抽共享脚本或各自实现，以约束文档为准）。
- **无 pre/next 按钮、无切邮件机制**；文本框同款 `ScrollContainer` + `RichTextLabel`（滚轮滑动），**打开时载入当前版本 work 文本**（`MailWorkManager.get_work_text()`）；监听 `work_version_changed`，弹层打开期间版本升级即时替换文本。
- **「工作」按钮**：文本框**下方**，`Button`，`text = "工作"`。点击后执行第 5 节链接序列。
- 关闭语义同 mailbox（`closed` 信号 + queue_free）。

## 5. 「工作」按钮链接序列

点击「工作」时：

1. **记录当前 work 版本**（`MailWorkManager.get_work_version()`，即文本框正在显示第几版）；
2. `StoryMonitor.lock_input()`；**画面 0.4 秒内渐变为纯黑**（全屏黑色 ColorRect，高层级 CanvasLayer，Tween alpha 0→1）；
3. **等待 1 秒**；
4. 屏幕**正中居中**显示文字，内容从 `texts/link{n}.txt` 载入（n = 记录的版本）：
   - **先显示第一行**，字体**加粗 + 斜体**（`RichTextLabel` BBCode `[b][i]`）；
   - **等待 2 秒**后，在其**下方 0.4 秒内淡入**显示第二行（普通字体，alpha 0→1 Tween）；
   - **等待 3 秒**后切换场景；
5. 版本 → 文件 → 目标场景映射：

| 记录版本 | 载入文件 | 目标场景 |
|---|---|---|
| 1（work1.txt） | `texts/link1.txt` | `res://scenes/c2_floor.tscn` |
| 2（work2.txt） | `texts/link2.txt` | `res://scenes/c3_level.tscn` |
| 3（work3.txt） | `texts/link3.txt` | `res://scenes/c4_floor.tscn` |
| 4（work4.txt） | **未定义** | 默认禁用「工作」按钮（`disabled = true` + 约束文档标注待补充）；如你认为有合理行为，先向我提问再实现 |

- 全程防重入；切场景前无需解锁输入（场景销毁自然释放），但要在约束文档中注明。

## 6. 文本文件读取约定

- 按行读取 UTF-8；邮件/work 文本框显示**全文**（含换行）；link 文件**只取前两行**（第一行标题、第二行正文，空行忽略）。
- 文件缺失时 `push_error` 并显示占位文本 `[文本缺失: xxx.txt]`，不崩溃。

## 交付与验证

1. 文件清单：`docs/desktop_screens_constraints.md`、`MailWorkManager.gd`（新 + Autoload 注册）、`computer_screen.tscn` / `ComputerScreen.gd` / `WorkIcon.gd`（改）、`mailbox_screen.tscn` / `MailboxScreen.gd`（重构）、`work_screen.tscn` / `WorkScreen.gd`（新）、`C2Floor.gd`（补 curten 状态写入）、`texts/` 全部占位文本。
2. 每个文件 MCP 读回校验 + 对照约束文档自检。
3. 运行验证清单（全部可演示）：
   - computer_screen 无 setting 图标；点 mail 图标 → mailbox 弹层：mailbox.png 原尺寸铺满、右上角 close_button 可关、拖拽条可拖且拖不出屏幕；
   - 初始仅 mail1；文本框滚轮滑动正常；pre/next 在单封时重显当前邮件；四段刷新时序正确（0.2s / 0.1s / 0.1s）；
   - 点 work 图标 → work_screen 弹层：初始 work1、无 pre/next、「工作」按钮可见；
   - work1 时点「工作」→ 0.4s 渐黑 → 1s → link1 第一行加粗斜体 → 2s → 第二行 0.4s 淡入 → 3s → 进入 c2_floor；
   - c2 中完成 curten 消失 → 回电脑桌面：邮箱多出 mail2（pre/next 可切换 mail1↔mail2）、work_screen 变为 work2；「工作」→ link2 → c3_level；
   - c4 中 12 个 waste 全部交互 → 邮箱追加 mail4、work 变 work4 且「工作」按钮禁用；
   - 存档验证：解锁 mail2 后保存退出重进，邮件列表与 work 版本正确恢复；
   - 回归：dialogue_test（T/Y/U）、c2/c3/c4 既有流程不受影响。
4. 列出需要我在编辑器手动配置的事项（素材补图、Autoload 确认等）。
