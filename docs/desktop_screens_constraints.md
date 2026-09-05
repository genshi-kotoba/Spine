# 电脑桌面二级界面（mailbox 重构 + work_screen 新增）：约束文档与验收契约

> 依据：`docs/prompts/godot_desktop_screens_prompt.md`（2026-09-06 从 NetDrive 拉取）；冲突裁决以《Spine-项目约束.md》《Spine-框架约束.md》及本文为准。
> 本文件是本模块的**唯一权威约束**。**硬约定：代码产出前先出本文档。**

## 1. 用户规格原文（prompt §1~7 必须全覆盖）

1. **computer_screen**：删 SettingIcon（脚本文件保留）；WorkIcon 取消直接跳场景，改发信号 `open_work`（仿 MailIcon.open_mailbox）；ComputerScreen 管理 work 弹层，开/关逻辑与 mailbox 一致（打开 lock_input、closed 后 unlock），**弹层互斥**（开一个前关另一个，prompt 默认）。
2. **MailWorkManager**（Autoload）：texts/ 文本中枢；监听 GameState.state_changed 每次重查完整条件；解锁规则：`c2_curten=="1"` → 追加 mail2 + work 升 2；c4_waste1~12 全 "1" → 追加 mail4 + work 升 4；持久化 `desktop_mails_unlocked`（"1,2,4" 式）与 `desktop_work_version`（初始 "1"）；接口 get_unlocked_mails/get_mail_text/get_work_version/get_work_text + 信号 mails_changed/work_version_changed；只升不降、幂等。
3. **mailbox_screen 重构**：Panel 尺寸 = mailbox.png 原始像素（491×483，不缩放）；右上角 TextureButton close_button.png 原尺寸；DragBar 拖拽整窗且 clamp 不出屏幕；ScrollContainer+RichTextLabel 滚轮滑动；pre/next 在文本框上方（左 ◀ 右 ▶），越界时重显当前邮件（走刷新动画，不循环）；初始显示列表第一封；**四段刷新**：盖板高度 1/2、1/6、1/6、1/6，揭开间隔 0.2s/0.1s/0.1s，动画期间忽略 pre/next。
4. **work_screen 新增**：同骨架（CanvasLayer+Dim+Panel+背景+右上角关闭）；无 pre/next；文本框同款；打开载入当前版本、监听 work_version_changed 即时替换；「工作」按钮在文本框下方。
5. **链接序列**：记录版本 v → lock_input → 0.4s 渐黑 → 等 1s → 正中显示 link{v}.txt 第一行（加粗斜体）→ 等 2s → 第二行 0.4s 淡入 → 等 3s → 切场景（1→c2_floor、2→c3_level、3→c4_floor、4→按钮 disabled 待补充）；防重入；切场景前无需解锁输入（文档注明即本条）。
6. **文本约定**：按行读 UTF-8；邮件/work 显示全文；link 只取前两行（空行忽略）；缺失 push_error + 显示 `[文本缺失: xxx.txt]` 不崩溃。

## 2. 工程事实盘点

- 工作区 = res:// = `C:\Users\31088\Desktop\翌光计划\Spine`；headless 读回校验等效 MCP。
- **素材核对（硬性约束 §5）**：`mailbox.png` ✓ 491×483（uid db7jj85rx5xwq）；`close_button.png` ✓ 25×24（uid dxe4ng72mig67）；**`work_screen.png` ✗ 缺失 → 已汇报，按占位方案继续**（决策 F4）。
- **computer_screen 现状**：SettingIcon(160,310)/MailIcon(160,620)/WorkIcon(160,930) 均为 InteractableObject；MailIcon 已有 open_mailbox 信号模式；WorkIcon 现直接 change_scene_to_file(c3_level)；ComputerScreen 已有 mailbox 弹层管理（lock/unlock + closed）。
- **mailbox_screen 现状**：CanvasLayer layer=10 + Dim + Panel(1136×498 居中) + TextureRect(mailbox_screen.jpeg, expand) + ItemList + 文字 X 关闭按钮。全部重做。
- **c2_curten 状态**：v2 流程中 curten = VanishItem（state_id="c2_curten"），E 交互即写 GameState "1"——**依赖修补已天然满足，C2Floor.gd 零改动**（决策 F6）。
- **GameState**：`set_object_state` 会发 state_changed——MailWorkManager 内部写解锁状态时监听器会重入，幂等设计保证收敛（无变化不再写）。
- **c3_level.tscn 存在**（链接序列目标 ✓）。Autoload 注册格式：`Name="*res://path.gd"`。

## 3. 模块边界

**In scope**

- 新增：`docs/desktop_screens_constraints.md`（本文，先于代码）
- 新增：`scripts/autoload/MailWorkManager.gd` + project.godot 注册 Autoload
- 新增：`texts/`：mail1/mail2/mail4.txt（6~10 行占位）、work1~4.txt（6~10 行占位）、link1~3.txt（≥2 行）
- 重构：`scenes/mailbox_screen.tscn` + `scripts/scenes/MailboxScreen.gd`（改前留 .bak）
- 新增：`scenes/work_screen.tscn` + `scripts/scenes/WorkScreen.gd`
- 修改：`scenes/computer_screen.tscn`（删 SettingIcon 及其 ext/sub；改前留 .bak）、`scripts/objects/WorkIcon.gd`（信号化）、`scripts/scenes/ComputerScreen.gd`（work 弹层管理 + 互斥）

**Out of scope / 禁区（违反即 FAIL）**

- 不改 SettingIcon.gd / MailIcon.gd / InteractableObject.gd / GameState.gd / StoryMonitor.gd / DialogueManager.gd / C2Floor.gd / C4Floor.gd / MainScene.gd；
- 不动 c2/c3/c4/bedroom/dialogue_test 场景；不新增输入映射；不 push；
- work4 的目标场景不自行发明（按钮禁用，待用户补充）；
- 不新建 mail3.txt（编号刻意跳号）。

## 4. API 契约

### 4.1 MailWorkManager（scripts/autoload/MailWorkManager.gd，Autoload 名 MailWorkManager）

- 信号：`mails_changed`、`work_version_changed`。
- 常量：`KEY_MAILS := "desktop_mails_unlocked"`；`KEY_WORK := "desktop_work_version"`；`C4_WASTE_IDS: Array[String]`（c4_waste1~12）；`TEXT_DIR := "res://texts/"`。
- `_ready()`：连接 `GameState.state_changed` → `_recheck()`；并立即 `_recheck()` 一次（读档补触发）。
- `_recheck()`（幂等、只升不降）：
  - 当前解锁集合 mails（解析 KEY_MAILS，空 = [1]；始终含 1）；
  - `GameState.get_object_state("c2_curten") == "1"` → mails 并入 2、work 目标版本至少 2；
  - 12 个 waste 全 "1" → 并入 4、work 目标版本至少 4；
  - 有新增 → 排序写回 KEY_MAILS（"1,2,4" 式）+ `mails_changed.emit()`；work 版本只升不降（`max(当前, 目标)`，显式类型），变化才写 KEY_WORK + `work_version_changed.emit()`。
- `get_unlocked_mails() -> Array[int]`：解析 KEY_MAILS（空 = [1]），升序。
- `get_mail_text(mail_id: int) -> String`：读 `texts/mail{id}.txt` 全文；缺失 `push_error` 并返回 `[文本缺失: mail{id}.txt]`。
- `get_work_version() -> int`：解析 KEY_WORK（空 = 1）。
- `get_work_text() -> String`：读 `texts/work{version}.txt`，缺失同上占位。

### 4.2 mailbox_screen 重构（场景 + MailboxScreen.gd）

- 结构（Panel 491×483 = mailbox.png 原尺寸，expand 关闭）：

```
MailboxScreen(CanvasLayer, layer=10)
├─ Dim(ColorRect 全屏, 半透明黑, 点击关闭)
└─ Panel(491×483, 初始屏幕居中)
   ├─ Background(TextureRect, mailbox.png, expand_mode=IGNORE, 铺满 Panel)
   ├─ DragBar(Control, 顶部 40px × 宽 451, 决策 F1；左键拖拽整窗, clamp 不出可视区)
   ├─ CloseButton(TextureButton, close_button.png 25×24 原尺寸, 右上角 (458,8))
   ├─ PreButton(Button "◀", (24,48) 48×32) / NextButton(Button "▶", (419,48) 48×32)
   ├─ TextScroll(ScrollContainer, (24,88) 443×379, 垂直滚动条可见)
   │  └─ MailText(RichTextLabel, bbcode off, 全文, scroll_active, 宽随容器)
   └─ Covers: Cover1~4(ColorRect 与文本框同区域, 高度比 1/2:1/6:1/6:1/6, 底色同文本框)
```

- 脚本：`signal closed`；成员 `_mails: Array[int]`、`_current: int`、`_animating: bool`、`_dragging: bool`、`_drag_offset: Vector2`。
- `_ready()`：连接 close/pre/next/DragBar.gui_input/Dim.gui_input/`MailWorkManager.mails_changed`；Panel 改 top-left 锚点并居中（(960-491/2, 620-483/2) = (714.5, 378.5)，取整 (714, 378)）；`_reload_mails()` → `_show_mail(0)`。
- `_reload_mails()`：`_mails = MailWorkManager.get_unlocked_mails()`；`_current` clamp 到有效范围（显式类型）。
- `_show_mail(idx: int)`：`_current = clamp(idx, 0, _mails.size()-1)`（越界 = 重显当前，不循环）；文本 = `get_mail_text(_mails[_current])` 一次性填充；`_play_refresh()`。
- `_play_refresh()`（async）：`_animating=true` → 4 盖板显示 → Cover1 隐藏 → 等 0.2s → Cover2 隐藏 → 等 0.1s → Cover3 隐藏 → 等 0.1s → Cover4 隐藏 → `_animating=false`。pre/next 在 `_animating` 时直接 return。
- pre/next：`_show_mail(_current-1)` / `_show_mail(_current+1)`（越界自然 clamp 成重显当前）。
- 拖拽：DragBar 左键按下 → `_dragging=true`、记录 `_drag_offset = _panel.position - 鼠标`；`mouse_motion` → `_panel.position = (鼠标 + _drag_offset)` 后 clamp：x∈[0, 视口宽-Panel宽]、y∈[0, 视口高-Panel高]（`get_viewport().get_visible_rect()`，显式类型）；松开 → false。
- `close()`：`closed.emit()` + `queue_free()`（沿用现语义；Dim 点击同 close）。
- `mails_changed` 期间弹层打开 → `_reload_mails()`（保持在当前索引，不强制跳新邮件）。

### 4.3 work_screen 新增（场景 + WorkScreen.gd）

- 结构同 4.2 骨架：CanvasLayer(layer=10) + Dim + Panel + Background + DragBar(40px) + CloseButton(右上) + TextScroll/WorkText + **WorkButton(Button "工作", 文本框下方居中)** + LinkLayer(CanvasLayer layer=40 内置 FadeRect 黑 + LinkTitle/LinkBody 两个 RichTextLabel 居中)。
- 占位方案（F4）：`@export var work_bg_path := "res://assets/sprites/work_screen.png"`；`_ready` 时 `ResourceLoader.exists` → 加载并按图尺寸设 Panel；**不存在 → Panel 用占位 491×483 + Background 纯色 ColorRect(0.2,0.2,0.25)**，补图后零代码改动生效（仅尺寸随图）。
- `_ready`：载入 `MailWorkManager.get_work_text()`；连接 `work_version_changed` → 重新载入文本（弹层开着也即时替换）；`WorkButton.disabled = (get_work_version() >= 4)`，并监听版本变化同步禁用态。
- 关闭语义：`closed` + queue_free（同 mailbox）；拖拽同款（各自实现，决策 F5）。
- **链接序列 `_on_work_pressed()`（async、防重入 `_link_running`）**：
  1. `v = MailWorkManager.get_work_version()`；映射表 `LINK_TARGETS: Dictionary = {1: "res://scenes/c2_floor.tscn", 2: "res://scenes/c3_level.tscn", 3: "res://scenes/c4_floor.tscn"}`；v≥4 或无映射 → return（按钮本已禁用，双保险）；
  2. `_link_running=true`；`StoryMonitor.lock_input()`；FadeRect Tween alpha 0→1 @0.4s；await；
  3. `await create_timer(1.0)`；
  4. 读 `texts/link{v}.txt` 前两行（空行忽略）：LinkTitle 显示 `[center][b][i]{行1}[/i][/b][/center]`（屏幕正中）；`await create_timer(2.0)`；LinkBody（其下方）modulate.a 0→1 @0.4s 淡入；await；`await create_timer(3.0)`；
  5. `get_tree().change_scene_to_file(LINK_TARGETS[v])`（切场景前无需解锁输入——场景销毁自然释放，按 prompt §5 注明）。

### 4.4 computer_screen 改动

- 场景：删 `SettingIcon` 节点树、ext_resource id2（SettingIcon.gd）、id6（setting_icon.png）、sub_resource setting_shape；**SettingIcon.gd 文件保留**。
- `WorkIcon.gd`：删 NEXT_SCENE 与跳场景；新增 `signal open_work`；`interact()` → `open_work.emit()`（仿 MailIcon）。
- `ComputerScreen.gd`：`const WORK_SCENE := preload("res://scenes/work_screen.tscn")`；`_work: WorkScreen = null`；`_ready` 连 `_work_icon.open_work → open_work()`；`open_work()`：已有弹层 return；**互斥（决策 F7）**：`_mailbox != null` 先 `_mailbox.close()`（unlock 随即 open 再 lock，顺序安全）；实例化挂接 closed → `_on_work_closed()`（置空 + unlock）；`open_mailbox()` 同样加互斥关 `_work`。

### 4.5 texts/ 占位文本

- mail1/mail2/mail4.txt、work1~4.txt：各 6~10 行 UTF-8 中文占位短句（深夜办公室叙事风，与 dialogue1 风格一致）；
- link1~3.txt：各 2 行（第一行标题、第二行正文）。

## 5. 信号流

```
c2 curten E → GameState["c2_curten"]="1" ─┐
c4 waste×12 → 全 "1" ─────────────────────┴→ MailWorkManager._recheck
    → desktop_mails_unlocked / desktop_work_version（只升不降）
    → mails_changed / work_version_changed → 弹层即时刷新
MailIcon 点击 → open_mailbox → ComputerScreen.open_mailbox（互斥关 work，lock_input）
WorkIcon 点击 → open_work → ComputerScreen.open_work（互斥关 mailbox，lock_input）
「工作」→ link 序列：渐黑 0.4s → 1s → link{v} 行1(粗斜) → 2s → 行2 淡入 0.4s → 3s → 切场景
```

## 6. 编码红线与惯例

- 禁止 `:=` 推断 Variant 内建函数返回值（clamp/min/max/lerp 等），显式标注类型。
- 命名 PascalCase 类 / snake_case 文件场景 / `_` 私有 / 信号 snake_case。
- 信号连接代码完成；弹层互斥只在 ComputerScreen 一处实现。

## 7. 验收标准表

| # | 规格 | 验收标准 | 证据 |
|---|---|---|---|
| ① | SettingIcon 删除 | 场景无 setting 图标与相关 ext/sub；脚本文件保留 | 场景走查 + 运行 |
| ② | mailbox 重构 | mailbox.png 原尺寸 491×483 铺满、右上原尺寸关闭钮、DragBar 可拖且不出屏、滚轮滚动 | 运行目视 |
| ③ | pre/next | 切已解锁邮件；越界重显当前（带刷新动画）；动画期间点击被忽略 | 运行 |
| ④ | 四段刷新 | 盖板 1/2+1/6×3，间隔 0.2/0.1/0.1s 逐段揭开 | 运行 |
| ⑤ | 解锁规则 | curten 消失 → mail2+work2；12 waste → mail4+work4；弹层开着也即时刷新 | 运行 + 存档 |
| ⑥ | work_screen | 打开显示当前版本；版本升级即时替换；无 pre/next | 运行 |
| ⑦ | 链接序列 | 0.4s 渐黑→1s→行1粗斜→2s→行2淡入0.4s→3s→v1/2/3 分别进 c2/c3/c4；v4 按钮禁用 | 运行 |
| ⑧ | 读档 | 解锁后重进：邮件列表与 work 版本恢复；_recheck 补触发正确 | 存档验证 |
| ⑨ | 回归 | 禁区零改动；c2/c3/c4/dialogue_test headless 0 错误 | git diff + headless |

## 8. verify 命令清单

```powershell
# 1 红线扫描（应无输出）
Select-String -Path scripts\autoload\MailWorkManager.gd,scripts\scenes\MailboxScreen.gd,scripts\scenes\WorkScreen.gd,scripts\scenes\ComputerScreen.gd,scripts\objects\WorkIcon.gd -Pattern ':= *(clamp|move_toward|lerp|min|max|randf_range)\('
# 2 Autoload 注册核对
Select-String -Path project.godot -Pattern 'MailWorkManager'
# 3 headless（均无 SCRIPT ERROR）
& 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . res://scenes/computer_screen.tscn --quit-after 3
# 4 窗口运行 §7 验收
& 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . res://scenes/computer_screen.tscn
```

## 9. 决策记录与剩余假设

已定案：

- F1 DragBar 高 40px、宽 451px（让出右上关闭钮区域）。
- F2 pre/next 文案 `◀` / `▶`，尺寸 48×32，位于文本框上方左右两端。
- F3 文本框区域 (24,88) 443×379；盖板底色 Color(0.12,0.12,0.14)（同文本框底色，老式终端风）。
- F4 work_screen.png 缺失：**占位方案** = Panel 491×483 + 纯色背景 + `@export work_bg_path`，补图后自动按图尺寸生效（已按硬性约束 §5 汇报）。
- F5 关闭钮/拖拽逻辑两个弹层各自实现（小体量，不抽象共享脚本）。
- F6 c2_curten 已由 VanishItem 写 GameState，C2Floor.gd 零改动（prompt「依赖修补」条件不满足）。
- F7 弹层互斥：开一个前关另一个（prompt 默认）。
- F8 mailbox 初始居中 (714, 378)（top-left 换算）；work 占位同。
- F9 LinkTitle 字号 32、LinkBody 24（占位审美，可随美术调）。

剩余假设：

- H1 mails_changed 时弹层保持当前索引（不自动跳新邮件）。
- H2 解锁状态写 GameState 走 set_object_state（随存档持久化），重入由幂等保证收敛。
- H3 work4 目标场景待用户补充（按钮禁用）。

## 10. 变更记录

- 2026-09-06 初版：desktop_screens 约束文档先行产出（prompt §1~7 全覆盖）。回滚要点：删除本文件即可。
