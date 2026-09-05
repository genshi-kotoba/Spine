# 对话模式三 MODE_GLITCH（故障散落字幕）：约束文档与验收契约

> 依据：`docs/prompts/godot_dialogue3_prompt.md` 第 1~6 节全部规则 + 《Spine-项目约束.md》《Spine-框架约束.md》+ 仓库既有约定（item_constraints.md / c3_floor_constraints.md 确立的工程规范）。
> 本文件是 MODE_GLITCH 模块的**唯一权威约束**：实现、验证、评审均以本文为准。**硬约定：代码产出前先出本文档。**
> **设计权铁律**：本文只收录 prompt 已提出的规格，不添加任何新玩法/操作设计。凡标「实现禁区」的条目，实现中出现即判 FAIL。

## 1. 用户规格原文（必须全部覆盖，不得增删设计）

1. `DialogueManager` 模式枚举追加 `MODE_GLITCH = 2`；生命周期与 MODE_AUTO 完全一致（不锁定输入、不接受按键切句、自动切换、结束发 `dialogue_finished` 并驱动队列）；唯一差异 = 显示方式。
2. 新 UI `GlitchDialogueBox`（`ui/glitch_dialogue_box.tscn` + `scripts/ui/GlitchDialogueBox.gd`，extends CanvasLayer，高 layer）；不复用底部对话框；`DialogueManager._ready()` 实例化存 `_glitch_box` 并连接其 `dialogue_finished`；`start_dialogue`/`_begin` 按 mode 路由（模式二→`_box`，模式三→`_glitch_box`）；每句动态生成逐字 Label，切句/结束统一销毁。
3. 逐字散落排版：第 1 字放基准点 `base_pos`；第 n+1 字 x = 前字 x + 步进（`get_string_size().x`，无则退化 `font_size`），y = 前字 y + `±randf_range(10.0, 30.0)`；每字间隔 0.15s；单句全部字显示完再停留 `AUTO_LINE_SEC`（4s）后切下一句；最后一句停留 4s 后结束。
4. 象限规则：以 `get_viewport().get_visible_rect()` 中心十字分四象限；第 1 句随机；第 2 句排除第 1 句；第 n 句（n≥3）排除前两句，从剩余两个象限随机；`base_pos` 取象限中心；预估整行宽度，右端超屏则左移 clamp。
5. 故障视觉：`assets/shaders/glitch_char.gdshader`（canvas_item），水平切片错位 + RGB 通道分离 + 随机闪烁，强度/频率导出 uniform；每字共享 ShaderMaterial；每字随机旋转 ±5°、缩放 0.9~1.1；脚本侧每字每 0.05s 做 ±2px 位置抖动（叠加偏移，不破坏散落基准坐标）。
6. 测试：`dialogues/dialogue3.txt`（4~6 句 UTF-8 中文，每句 ≤12 字）；`project.godot` 输入映射追加 `dialogue_u`（U 键，写法同 dialogue_t/y）；`DialogueTest.gd` 追加 U 分支，守卫逻辑同 T/Y（input_locked 不生效、激活期入队、`set_input_as_handled()`）。

## 2. 工程事实与现有骨架盘点

- 工作区 = res:// = `C:\Users\31088\Desktop\翌光计划\Spine`；引擎 Godot 4.7（`D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`）。
- 无 Godot MCP 可用时，按仓库惯例以文件工具 + godot.exe headless 读回校验等效替代（item_constraints.md §1-④ 先例）。
- `DialogueManager`（Autoload）：enum 匿名（MODE_INTERACTIVE=0 / MODE_AUTO=1）；`_box: DialogueBox`；`_active` + `_queue: Array[Dictionary]` FIFO；`_begin` 读文件 → `_box.show_dialogue(lines, mode)`；`_on_box_finished` 驱动队列。
- `DialogueBox`（CanvasLayer，layer=20）：`dialogue_finished` 信号；`AUTO_LINE_SEC = 4.0` 常量；RichTextLabel 用 SystemFont（Microsoft YaHei 等 CJK 字体栈）。
- `DialogueTest`（Node2D，class_name DialogueTest）：`_unhandled_input` 先查 `StoryMonitor.input_locked`；`event.is_action_pressed("dialogue_t"/"dialogue_y")` 分支 + `set_input_as_handled()`。
- `project.godot` 输入集现状：move_left / move_right / interact / dialogue_t / dialogue_y / breathe。**本模块只追加 `dialogue_u`，不改不删既有项**。
- 命名惯例：场景文件名 snake_case；脚本文件名 = class_name PascalCase；节点名 PascalCase；私有成员 `_` 前缀；信号 snake_case。
- 窗口固定 1920×1240，游戏区 y∈[211,1028]（上下黑边为预留文案区）；GlitchDialogueBox 为 CanvasLayer 屏幕空间，字幕可落在全窗口任意象限（含黑边区，不遮挡判定由象限中心 + clamp 保证）。

## 3. 模块边界

**In scope（新增/修改）**

- 新增：`docs/design/dialogue3_glitch_constraints.md`（本文档，先于代码）
- 新增：`dialogues/dialogue3.txt`
- 新增：`assets/shaders/glitch_char.gdshader`
- 新增：`scripts/ui/GlitchDialogueBox.gd`（含 .uid 伴随文件，仓库惯例）
- 新增：`ui/glitch_dialogue_box.tscn`
- 修改：`scripts/autoload/DialogueManager.gd`（追加 MODE_GLITCH + `_glitch_box` 路由；**改前留 DialogueManager.gd.bak**）
- 修改：`scripts/scenes/DialogueTest.gd`（追加 U 分支；**改前留 DialogueTest.gd.bak**）
- 修改：`project.godot`（追加 dialogue_u 输入映射；已有 project.godot.bak，改前刷新备份）

**Out of scope / 实现禁区（违反即 FAIL）**

- 改动模式一/模式二既有行为；改动 DialogueBox.gd / dialogue_box.tscn；
- 改动队列语义（同一时刻一段对话、FIFO）；
- 删除/修改既有输入映射（move_left / move_right / interact / dialogue_t / dialogue_y / breathe）；
- MODE_GLITCH 锁定输入、接受按键切句（规格：与 MODE_AUTO 一致，不锁、不接键）；
- 复用底部 DialogueBox 显示模式三内容；
- 真实美术/外部资产/音效/新玩法；
- push（本地提交、不 push——用户另行指令除外）。

## 4. API 契约

### 4.1 DialogueManager.gd（修改）

- enum 追加 `MODE_GLITCH = 2`（匿名 enum 内追加，保持 MODE_INTERACTIVE=0 / MODE_AUTO=1 数值不变）。
- `const GLITCH_BOX_SCENE := preload("res://ui/glitch_dialogue_box.tscn")`。
- `var _glitch_box: GlitchDialogueBox = null`。
- `_ready()`：实例化 `_glitch_box`，`_glitch_box.dialogue_finished.connect(_on_box_finished)`（与 `_box` 共用同一回调，队列语义不变），`add_child(_glitch_box)`。
- `_begin(file_path, mode)` 路由：`mode == MODE_GLITCH` → `_glitch_box.show_dialogue(lines)`；否则走原 `_box.show_dialogue(lines, mode)`。
- 读回打印（headless 验证用）：`_ready` 末尾 print `[dialogue_manager] glitch box ready`；`_begin` 打印 `[dialogue_manager] begin mode=N file=...`。

### 4.2 GlitchDialogueBox.gd（新增）

- `class_name GlitchDialogueBox`、`extends CanvasLayer`。
- 信号：`dialogue_finished`（DialogueManager 监听）。
- 常量：
  - `CHAR_INTERVAL_SEC := 0.15`（逐字出现节奏）
  - `AUTO_LINE_SEC := 4.0`（单句停留，复用模式二语义；类内自定义同名常量，不 import）
  - `DY_MIN := 10.0` / `DY_MAX := 30.0`（y 随机偏移幅度）
  - `JITTER_INTERVAL_SEC := 0.05` / `JITTER_PX := 2.0`（位置抖动）
  - `FONT_SIZE := 32`（单字字号；SystemFont CJK 字体栈同 DialogueBox 惯例）
- 接口：`func show_dialogue(lines: Array) -> void`、`func is_active() -> bool`。
- 结构（场景内）：CanvasLayer(layer=25) → `CharContainer`（Control，全屏 anchors_preset=15，mouse_filter=IGNORE）；逐字 Label 动态生成为 CharContainer 子节点。
- 逐字流程（每句）：
  1. 按 §5 象限规则选象限 → `base_pos` = 象限中心；预估整行宽度 = Σ 每字步进 + 抖动余量（JITTER_PX×2），右端超屏则 `base_pos.x -= 超出量`（clamp 保证整行在屏内，左端同理 clamp ≥ 0）。
  2. 逐字生成 Label：text = 单字；font = SystemFont（CJK 栈）；font_size = FONT_SIZE；挂共享 ShaderMaterial（§4.3）；随机 rotation = ±5°（`randf_range(-PI/36, PI/36)`）、scale = `randf_range(0.9, 1.1)` 均匀标量。
  3. 第 1 字 position = base_pos；第 n+1 字：x = 前字 x + 步进（前字 `font.get_string_size(前字文本, font_size=FONT_SIZE).x`，为 0 时退化 FONT_SIZE）；y = 前字 y + `randf_range(DY_MIN, DY_MAX) * (1 if randf() < 0.5 else -1)`。
  4. 每生成一字 await `create_timer(CHAR_INTERVAL_SEC).timeout` 再生成下一字。
  5. 记录每字基准坐标 `_base_positions: Array[Vector2]`；抖动协程/计时器每 JITTER_INTERVAL_SEC 把每字 position 设为 `基准 + Vector2(randf_range(-JITTER_PX, JITTER_PX), randf_range(-JITTER_PX, JITTER_PX))`（叠加偏移，不改基准）。
  6. 全句字齐后 await `create_timer(AUTO_LINE_SEC).timeout` → 销毁本句全部 Label → 下一句；末句停留后 `_finish()`：隐藏容器、发 `dialogue_finished`。
- 生命周期硬约束（与 MODE_AUTO 一致）：**不调用** `StoryMonitor.lock_input()`；**不实现** `_unhandled_input` 切句；结束必须发 `dialogue_finished` 供队列驱动。
- 计时实现：SceneTreeTimer（`get_tree().create_timer()`），切句/销毁时以 token（`_line_token: int` 自增）防止过期 timer 操作已销毁节点。
- 象限历史：`_quadrant_history: Array[int]`（只保留最近两句）；选象限：候选 = {0,1,2,3} − 历史，随机取一并记录；象限编号 0=左上 1=右上 2=左下 3=右下。
- 读回打印：
  - `_ready`：print `[glitch_box] ready`；
  - 每句开始：print `[glitch_box] line i/N quadrant=Q base=(x,y)`；
  - 结束：print `[glitch_box] finished`。
- 自检契约（`--self-check`，仅 `OS.get_cmdline_user_args()` 含该 flag 时执行）：`show_dialogue(["测试一", "测试二"])` → await 足够时长 → 断言期间发出过 quadrant 打印且历史满足「任意句与前两句不同象限」→ print `[glitch_box] SELF-CHECK PASS/FAIL ...` → `get_tree().quit()`。

### 4.3 glitch_char.gdshader（新增）

- `shader_type canvas_item;`
- uniforms（全部导出可调）：`slice_strength`（默认 4.0，水平切片错位幅度 px）、`slice_speed`（默认 8.0）、`aberration`（默认 1.5，RGB 分离 px）、`flicker_speed`（默认 20.0）、`flicker_strength`（默认 0.3，alpha 抖动幅度）。
- 实现：
  - 切片错位：按 `floor(UV.y * 24.0)` 分条，伪随机 hash(条号 + floor(TIME*slice_speed)) → 每条 UV.x 偏移 ±slice_strength/TEXTURE_PIXEL_SIZE 归一量；
  - RGB 分离：R/G/B 三次采样 texture，x 方向 ±aberration 像素偏移；
  - 闪烁：`alpha *= 1.0 - flicker_strength * (0.5 + 0.5*sin(TIME*flicker_speed + hash))`，叠加瞬时隐现（hash 阈值概率 ~2% 帧整字 alpha→0.2）。
- 每个字 Label 共用同一 ShaderMaterial 实例（脚本 _ready 创建一次）。

### 4.4 dialogue3.txt（新增）

- 4~6 句 UTF-8 中文短句，**每句 ≤12 字**；按行分句、无空行（与 DialogueManager._load_lines 规则兼容）。

### 4.5 DialogueTest.gd（修改）

- 追加分支：`event.is_action_pressed("dialogue_u")` → `DialogueManager.start_dialogue("res://dialogues/dialogue3.txt", DialogueManager.MODE_GLITCH)` + `get_viewport().set_input_as_handled()`。
- 守卫：函数入口 `StoryMonitor.input_locked` 检查已有，不另加；对话激活期按 U 由 DialogueManager 队列语义天然处理（入队不打断）。

### 4.6 project.godot（修改）

- `[input]` 追加 `dialogue_u`，写法与 dialogue_t 完全一致，`physical_keycode=85`（U）。

## 5. 信号流与路由图

```
U 键(dialogue_u) → DialogueTest._unhandled_input
  → DialogueManager.start_dialogue(dialogue3.txt, MODE_GLITCH)
	→ 空闲：_begin → _glitch_box.show_dialogue(lines)
	→ 忙碌：_queue.append (FIFO)
_glitch_box 播完 → dialogue_finished → DialogueManager._on_box_finished
  → _active=false → dialogue_finished.emit → 队列下一段 _begin（按 mode 路由 _box/_glitch_box）
```

## 6. GDScript 编码红线（沿用 c3 §4.5）

- 禁止 `:=` 推断 Variant 内建函数返回值（clamp / move_toward / lerp / min / max / randf_range 等）——一律显式标注类型。
- 场景文件名 snake_case、节点名 PascalCase、私有成员 `_` 前缀、信号 snake_case。
- 适用范围：GlitchDialogueBox.gd、DialogueManager.gd、DialogueTest.gd。

## 7. 验收标准表（对照规格 ①–⑥）

| # | 规格 | 验收标准 | 证据方式 |
|---|---|---|---|
| ① | MODE_GLITCH=2，生命周期同 MODE_AUTO | enum 含 MODE_GLITCH=2；GlitchDialogueBox 无 lock_input/无 _unhandled_input 切句；结束发 dialogue_finished 驱动队列 | 代码走查 + Select-String 扫描 |
| ② | GlitchDialogueBox 独立 UI | ui/glitch_dialogue_box.tscn + scripts/ui/GlitchDialogueBox.gd 存在；CanvasLayer 高 layer；DialogueManager 按 mode 路由；逐字 Label 动态生成/销毁 | 文件清单 + 代码走查 |
| ③ | 逐字散落排版 | 0.15s 逐字；后字在前字右侧（步进=get_string_size 退化 font_size）；y 偏移 ±[10,30]；字齐后停留 4s 切句 | 代码走查 + 窗口运行目视 |
| ④ | 象限规则 | 第1句随机、第2句排除前1、第n句排除前2；base_pos=象限中心；右端超屏 clamp | 运行读回 quadrant 打印 + 代码走查 |
| ⑤ | 故障视觉 | glitch_char.gdshader 存在且含切片/RGB分离/闪烁 uniform；每字旋转±5°、缩放0.9~1.1；0.05s ±2px 抖动不改基准 | 代码走查 + 窗口运行目视 |
| ⑥ | 测试接入 | dialogue3.txt 4~6句每句≤12字；project.godot 含 dialogue_u(85)；DialogueTest U 分支守卫同 T/Y | 文件检查 + headless 加载 |
| ⑦ | 文档先行 + 不破坏既有 | 本文档早于代码；模式一/二回归不变；headless 0 错误 | git log + headless 读回 |

## 8. verify 命令清单

```powershell
# 1 静态红线扫描（应无输出）
Select-String -Path scripts\ui\GlitchDialogueBox.gd,scripts\autoload\DialogueManager.gd,scripts\scenes\DialogueTest.gd -Pattern ':= *(clamp|move_toward|lerp|min|max|randf_range)\('
# 2 禁区扫描（GlitchDialogueBox 不得锁输入/接键切句）
Select-String -Path scripts\ui\GlitchDialogueBox.gd -Pattern 'lock_input|_unhandled_input'   # 应无输出
# 3 备份核对（改前已留 .bak）
Test-Path scripts\autoload\DialogueManager.gd.bak   # True
Test-Path scripts\scenes\DialogueTest.gd.bak        # True
Test-Path project.godot.bak                         # True
# 4 工程整体 headless 加载（exit 0，无 SCRIPT ERROR）
& 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --quit-after 3
# 5 测试场景 headless 加载（stdout 含 [dialogue_manager] glitch box ready 与 [glitch_box] ready）
& 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . res://scenes/dialogue_test.tscn --quit-after 3
# 6 窗口运行：dialogue_test 场景按 U 目视验证 §7 清单；T/Y 回归
& 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . res://scenes/dialogue_test.tscn
```

## 9. 决策记录与剩余假设

已定案：

- A1 路由放 DialogueManager._begin，队列回调 `_on_box_finished` 双 box 共用（队列语义零改动）。
- A2 GlitchDialogueBox layer=25（高于 DialogueBox 的 20，保证盖在场景与底部对话框之上；两 box 不会同时激活，无遮挡冲突）。
- A3 计时起点 = 该句全部字显示完毕后再停留 4s（prompt §3 原文；prompt 声明「若约束文档对计时起点另有定义，以约束文档为准」——本文确认即此定义）。
- A4 字体复用 DialogueBox 的 SystemFont CJK 字体栈；字号 FONT_SIZE=32（工程建议值，可调）。
- A5 无 Godot MCP 环境，按仓库惯例用文件工具 + headless 读回等效替代（item_constraints.md §1-④）。

剩余假设（评审/集成前显式确认）：

- H1 字幕可出现在上下黑边区（CanvasLayer 屏幕空间象限覆盖全窗口 1920×1240）；如要求限制在游戏区 y∈[211,1028] 内，后续调 visible_rect 计算即可，不改架构。
- H2 抖动/故障参数默认值为工程建议，均做成常量/uniform 可调。
- H3 dialogue3.txt 文本内容为占位文案（规格「内容随意」），正式文案后续由剧情系统替换。

## 10. 变更记录

- 2026-09-05 初版：MODE_GLITCH 约束文档先行产出。影响范围：仅新增本文档，未触碰任何代码/场景/配置。回滚要点：删除本文件即可。
