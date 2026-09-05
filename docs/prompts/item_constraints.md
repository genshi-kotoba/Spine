# item 交互模块：约束文档与验收契约

> 依据：用户模块规格（团队任务 t1 描述：① item 基类 ② test_item 子类 + 测试场景 ③ 交付清单与四步运行验证清单）+ 仓库既有约定（docs/c3_floor_constraints.md 确立的工程规范）。
> 本文件是 item 交互模块的**唯一权威约束**：实现（t2）、验证（t3）、评审（t4）均以本文为准。**硬约定：代码产出前先出本文档。**
> **设计权铁律**：本文只收录用户已提出的规格，不添加任何新玩法/操作设计。凡标「实现禁区」的条目，实现中出现即判 FAIL。

## 1. 用户规格原文（必须全部覆盖，不得增删设计）

1. item 基类 `objects/item.gd`：节点类型按规格选择（需要碰撞范围检测优先 Area2D → 本项目判定玩家范围需 Area2D）；**所有 item 必须继承该基类**；参数 `size`（Vector2，决定包含范围）、`position` 用 Node2D 原生；状态机 int（`current_state` + 状态集合，切换统一走 `apply_state()`）；方法 `touched()`（空/默认实现，子类覆写）、`call_item(new_state:int)`（外部指定目标状态，避免覆盖内建 `call()`）；内部约定 `set_state(new_state)` 统一负责状态变更 + `apply_state()`，`touched()`/`call_item()` 最终汇入该路径。
2. test_item 子类 `objects/test_item.gd` + 测试场景：状态 0=初始位置（`_ready` 记录 `initial_position`）/ 状态 1=上移 200px；切换用 Tween 0.3s（规格默认）；`touched()` 核心逻辑：E 键（input map `interact`）触发——实现二选一，规格推荐「玩家脚本发 `interact_pressed` 信号、item 监听」（低耦合）；判定玩家在 size 矩形范围内（优先 Area2D overlaps_body()，备选 Rect2.has_point）；判定成立→toggle 0↔1，不成立→无动作。
3. 交付清单与运行验证清单（四步演示）。
4. 团队目标（硬约定）：约束文档先行；测试场景；四步运行验证；无 Godot MCP，用文件工具 + godot.exe headless/运行读回校验等效替代；本地提交、不 push。

## 2. 工程事实与现有骨架盘点

- 仓库根 `F:\Godot\Spine`；工程根 `F:\Godot\Spine\Spine`（res:// 即此目录）；引擎 Godot 4.7（`F:\Godot\godot\godot.exe`，已验证存在）。
- 输入集（project.godot）：`move_left`(A/←)、`move_right`(D/→)、`interact`(E)。**本模块不得新增/删除输入**，project.godot 不改。
- 既有体系（本模块必须明确与之并行，见 §8）：
  - `InteractableObject`（Area2D 基类）：`object_id`/`initial_state`/`states`/`change_state()`（写 GameState）/`interact()`；LevelScene._ready 用 `find_children("*", "InteractableObject")` 扫描并连接 body 信号；E 键（LevelScene._unhandled_input 中 `event.is_action_pressed("interact")`）→ `_overlapping.front().interact()`。
  - `Player`（CharacterBody2D，class_name Player）：A/D 移动 + 重力；`_physics_process` 先查 `StoryMonitor.input_locked`；player.tscn 自带 CollisionShape2D(32×64)、Visual(Polygon2D)、Camera2D；无组（group）配置。
  - `StoryMonitor.input_locked`（bool，默认 false）：一切输入处理必须先检查（仓库惯例）。
  - `GameState`：对象状态字典 + JSON 存档（InteractableObject 链路专用）。
- 命名惯例（现状归纳，c3_floor_constraints.md §4.4）：节点名 PascalCase；场景文件名 snake_case（player.tscn / level_scene.tscn / c3_floor.tscn）；脚本文件名与 class_name 一致（PascalCase）；私有成员 `_` 前缀；信号 snake_case。**本模块脚本路径以用户规格为权威**（item.gd / test_item.gd），class_name 与节点名 PascalCase（假设 H1/H2）。
- Godot 4.7 API 事实：Area2D 无 `overlaps_body()`（3.x 命名），4.x 等效为 `get_overlapping_bodies()`（§7）。
- 白模惯例：零贴图，节点形状（Polygon2D / ColorRect）占位；`Spine/shots/` 为验证截图证据目录（已在 .gitignore）。

## 3. 模块边界

**In scope（实现任务 t2 的改动范围；本文档只定义、不改动）**

- 新增：`scripts/objects/item.gd`、`scripts/objects/test_item.gd`（.uid 伴随文件随实现提交，仓库现状惯例）；
- 新增：`scenes/test_item.tscn`（测试场景）；
- 修改：`scripts/player/Player.gd`（仅加 `interact_pressed` 信号 + `_unhandled_input` 发射；**改前先在同目录留 Player.gd.bak**，硬约束）；
- 证据输出：`Spine/shots/*`（已在 .gitignore，不随模块提交）。

**Out of scope / 实现禁区（违反即 FAIL）**

- 不改 project.godot（输入集保持三项）、main.tscn、main_scene.tscn、level_scene.tscn、player.tscn；
- 不改 InteractableObject.gd / LevelScene.gd / GameState.gd / StoryMonitor.gd / 其他既有脚本；
- item 状态**不写 GameState、不参与存档**（规格未要求；不扩展既有存档语义）；
- 无新输入/新操作/新玩法；无 UI 提示；无音效/真实美术/文案内容；无外部资产；
- push（团队约定：本地提交、不 push）。

## 4. 节点类型定案：Area2D（选择依据）

1. 规格①：需要碰撞范围检测优先 Area2D；本模块「判定玩家在 size 矩形范围内」即碰撞范围检测 → Area2D。
2. 规格①：position 用 Node2D 原生 → Area2D 继承 Node2D，自带 position，无需自造位置参数。
3. 仓库先例：InteractableObject 即 Area2D，检测语义一致（但 item 体系**不继承** InteractableObject，见 §8）。

## 5. API 契约

### 5.1 Item 基类（scripts/objects/item.gd）

- `class_name Item`（仓库惯例，便于类型检查）、`extends Area2D`。
- 继承约束：**后续所有 item 子类必须继承本基类**（规格①；评审扫描 extends 声明）。
- 属性：
  - `@export var size: Vector2 = Vector2(64, 64)`——决定包含范围（检测矩形）。建议默认值（假设 H3），测试场景按 §9.2 配置；基类在 `_ready` 将 size 同步到子节点 `CollisionShape2D`（RectangleShape2D）的 `shape.size`。
  - position：Node2D 原生属性，**不定义任何自定义位置参数**（规格①）。
- 状态机（int）：
  - `var current_state: int = 0`；
  - 状态集合由子类定义（本模块 TestItem 为 {0, 1}）；基类不枚举、不新增 initial_state 导出（规格未提）；
  - `apply_state(new_state: int)`：状态效果的**唯一出口**，基类空默认实现（pass），子类覆写；
  - `set_state(new_state: int)`：状态变更的**唯一入口**——`current_state = new_state` + 调 `apply_state(new_state)`；
  - 约束：`touched()`/`call_item()` 及任何子类代码**不得直接赋值 current_state**，必须汇入 set_state 路径（§5.3）。
- 方法签名（即契约）：
  - `func touched() -> void`：空/默认实现，子类覆写（E 键触发入口，规格①）。
  - `func call_item(new_state: int) -> void`：外部程序化入口；命名避开内建 `call()`（规格①）；实现 = `set_state(new_state)`；**无范围判定、无输入锁检查**（外部显式指定目标状态，规格语义）。
  - `func set_state(new_state: int) -> void`：见上。
  - `func apply_state(new_state: int) -> void`：基类 pass 默认。
- `_ready()`：把 size 同步到子节点 `CollisionShape2D`（RectangleShape2D；节点名沿用 player.tscn 惯例）；**子类覆写 `_ready` 必须先 `super._ready()`**。
- 注释沿用仓库风格（`##` 块注释；标识符与消息体英文）。

### 5.2 TestItem 子类（scripts/objects/test_item.gd）

- `class_name TestItem`（可选，推荐）、`extends "res://scripts/objects/item.gd"`（路径 extends，不依赖全局类缓存；或 `extends Item`，实现任选）。
- 状态集合：{0, 1}（int）。
  - 状态 0 = 初始位置：`var initial_position: Vector2`，`_ready` 中记录 `initial_position = position`；
  - 状态 1 = 上移 200px：目标位置 = `initial_position + Vector2(0, -200)`（Godot y 轴向下，上移为负 y）。
- `apply_state(new_state: int)` 覆写：先停止上一个 tween（避免并发冲突），再 `create_tween().tween_property(self, "position", 目标位置, 0.3)`（Tween 0.3s，规格默认）。
- `touched()` 覆写（核心逻辑，规格②）：
  1. 范围判定：玩家在 size 矩形范围内（§7，优先 `get_overlapping_bodies()`）；
  2. 判定成立 → toggle：`set_state(1 if current_state == 0 else 0)`；
  3. 判定不成立 → **无动作**（不改状态、不打印状态变化）。
- `call_item` 继承基类实现（直接 set_state，无范围判定）。
- 读回打印契约（四步验证读回所需，见 §13；消息体英文）：
  - `_ready` 末尾：print `[test_item] ready state=0 initial_position=(x,y)`；
  - `apply_state`：print `[test_item] apply_state state=N target=(x,y)`；
  - `touched`：print `[test_item] touched in_range=true/false`（成立时随后可见 apply_state 打印）；
  - 自检：print `[test_item] SELF-CHECK PASS ...` / `[test_item] SELF-CHECK FAIL ...`。
- 自检契约（`--self-check`，headless 读回校验，见 §9.3）：仅当 `OS.get_cmdline_user_args()` 含 `--self-check` 时执行：`call_item(1)` → await 0.6s（> Tween 0.3s）→ 断言 `position.y` 与 `initial_position.y - 200` 之差 < 1.0 → 打印 PASS/FAIL → `get_tree().quit()`。常规运行/游玩不受影响。

### 5.3 切换路径图（touched()/call_item() 最终汇入 set_state）

```
E 键(interact) → Player.interact_pressed ──→ TestItem.touched()
                                              │ 范围判定成立
                                              ▼
外部程序化 ──→ call_item(new_state) ──┐    toggle 0↔1
                                      ▼       ▼
                           set_state(new_state)      ← 唯一状态变更入口
                                      │ current_state = new_state
                                      ▼
                           apply_state(new_state)    ← 唯一状态效果出口
                                      │ TestItem: Tween position 0.3s
```

（任何绕过 set_state 的直接 current_state 赋值 = FAIL）

## 6. E 键触发与信号流（规格②定案：推荐项）

- **定案（规格推荐）**：「玩家脚本发 `interact_pressed` 信号、item 监听」（低耦合）。
- Player.gd 修改（**改前先留 `scripts/player/Player.gd.bak`**，同 c3 硬约束）：
  - 新增 `signal interact_pressed`（无参数；信号 snake_case 惯例）；
  - 新增 `_unhandled_input(event: InputEvent)`：先查 `StoryMonitor.input_locked`（仓库惯例，锁定时不发射）；`event.is_action_pressed("interact")` 时 `interact_pressed.emit()`（写法与 LevelScene 既有 E 键处理一致，每按一次发射一次）。
- item 监听：scenes/test_item.tscn 内联连接（连接声明在测试场景中，脚本零耦合）：
  ```
  [connection signal="interact_pressed" from="Player" to="TestItem" method="touched"]
  ```
  （编辑器「节点」面板连接等效。）
- 备选实现（规格二选一的另一项，**记录、不采用**）：item 自身 `_process` 轮询 `Input.is_action_just_pressed("interact")`——耦合更高；仅当信号方案受阻时启用，启用前须回报 captain。
- 输入锁语义：`input_locked` 时 Player 不发射信号 → touched() 不被触发；`call_item()` 是外部程序化入口，不受输入锁约束（规格③外部指定，设计如此）。

## 7. 范围判定

- **首选**：Area2D 物理重叠——`get_overlapping_bodies()`（Godot 4.7；规格所述 `overlaps_body()` 为 3.x 命名，4.x 等效即此），判定任一 body `is Player`（class_name Player 已存在）。
- **备选**（首选不可行时）：`Rect2.has_point(player.position)`，矩形 = 以 item position 为中心、size 为尺寸（`Rect2(position - size / 2.0, size)`）。
- 前提：item 必须带 `CollisionShape2D`（RectangleShape2D，size 由基类 _ready 同步，§5.1）；Area2D 保持默认 monitoring/monitorable；item（Area2D）与 Player（body）均在默认物理层 1（不改 project.godot/层配置；假设 H4，如默认层不可用则在测试场景内显式配置 layer/mask 兜底，仍不改 project.godot）。
- 行为说明：apply_state 移动的是 item 根节点，CollisionShape2D 随之移动 → 状态 1 的检测矩形即上移后的矩形（双向 toggle 演示依赖 §9.2 配置判据）。

## 8. 与既有体系的关系（并行不冲突，任务硬要求）

- item 体系**不继承 InteractableObject**、不声明 object_id、不写 GameState、不触发剧情：与既有 E 键扫描链路完全隔离。
- LevelScene 的 `find_children("*", "InteractableObject")` 按类型过滤，Item 子类不会被扫描、不会进入 `_overlapping` 列表、不会经 LevelScene 调 interact()。
- 测试场景（test_item.tscn）不含 LevelScene → 两条链路在本模块测试场景零交叉。
- 未来正式关卡中两者并存时：同一次按 E，LevelScene 会对最近重叠的 InteractableObject 调 interact()，同时 Player 发射 interact_pressed → item touched()——两体系独立、无共享状态，按设计并行（本模块不实现并存场景，仅说明关系；假设 H6）。
- 不得改动 InteractableObject.gd / LevelScene.gd / GameState.gd / StoryMonitor.gd（禁区，§3）。

## 9. 测试场景结构（scenes/test_item.tscn）

### 9.1 场景树（最小验证集，白模零贴图）

```
TestItemScene (Node2D)
├─ Player      # instance res://scenes/player.tscn（自带 Camera2D，进入场景树自动 current）
├─ Floor       # StaticBody2D + CollisionShape2D + Polygon2D 色块：顶面 y=988（仓库游戏区站立面惯例；Player 有重力，无地面会坠落，验证必需）
└─ TestItem    # Area2D，script = res://scripts/objects/test_item.gd
   ├─ CollisionShape2D   # RectangleShape2D（size 由基类 _ready 同步）
   └─ Visual             # Polygon2D 色块（白模占位；可视化尺寸实现自由）
```

- 内联连接（§6）：Player.interact_pressed → TestItem.touched。
- 只含验证所需最小节点：无 LevelScene / InteractableObject / 剧情 / UI / 音效。
- 命名：节点名 PascalCase（TestItemScene / Player / Floor / TestItem / Visual / CollisionShape2D）。

### 9.2 建议配置（数值可调，判据必须满足）

- Floor 顶面 y=988；Player 出生 (1000, 948)（碰底留 8px，c3 教训）→ 站立后 y≈956，身体 y∈[924, 988]。
- TestItem：position (1000, 940)、size (200, 480)：
  - 状态 0 矩形 x∈[900,1100]、y∈[700,1180] ⊃ 玩家站立带 y∈[924,988] ✓；
  - 状态 1（上移 200 → y=740）矩形 y∈[500,980]，仍覆盖玩家 y∈[924,988] ✓；
  - → 玩家无需移动即可演示 0↔1 **双向** toggle（规格要求 toggle 0↔1）。
- **判据（验收必须）**：状态 0 与状态 1 的检测矩形均含玩家站立带 → 双向 toggle 可演示（假设 H5）；具体坐标/尺寸可调（实现自由）。检测矩形允许局部嵌入地面（Area2D 无碰撞，不影响判定；可视化色块实现自由，验收只看位置可辨）。
- 推导备注：玩家站立带 y∈[924,988] 固定，矩形上移 200 后仍需覆盖 988 → 矩形高 ≥ 464 量级（此配置取 480）。

### 9.3 自检（--self-check）契约

- 用途：无 Godot MCP 下的 headless 读回校验（团队目标④）：无需人工按键即可验证 call_item → set_state → apply_state → Tween 全链路。
- 触发：`godot.exe --headless --path ... res://scenes/test_item.tscn -- --self-check`（`--` 之后为用户参数，`OS.get_cmdline_user_args()`）。
- 流程与退出：见 §5.2 自检契约；自检内部 `get_tree().quit()` 结束（不依赖 --quit-after；如需兜底可加 `--quit-after 600`）。
- 覆盖点：call_item 汇入 set_state、状态 1 目标位置（上移 200px）、Tween 0.3s 完成后的落点。touched() / E 键 / 范围判定由四步验证第 4 步窗口运行覆盖。

## 10. GDScript 编码红线（沿用 c3 §4.5）

- 禁止从返回 Variant 的内建函数用 `:=` 推断类型（clamp / move_toward / lerp / min / max 等）——一律显式标注（如 `var x: float = clamp(...)`）。本模块全部新增/修改脚本（item.gd、test_item.gd、Player.gd）适用。
- 场景文件名 snake_case、节点名 PascalCase、私有成员 `_` 前缀、信号 snake_case。

## 11. 交付清单

- `docs/item_constraints.md`（本文档，先于代码）
- `scripts/objects/item.gd`、`scripts/objects/test_item.gd`（含编辑器生成的 .uid 伴随文件）
- `scenes/test_item.tscn`
- `scripts/player/Player.gd`（修改：interact_pressed 信号 + _unhandled_input 发射）+ 同目录 `Player.gd.bak`
- （证据，不随模块提交）`Spine/shots/*`（已在 .gitignore）

## 12. 验收标准表（对照规格 ①–④）

| # | 规格 | 验收标准 | 证据方式 |
|---|---|---|---|
| ① | item 基类 | 类型 Area2D；size(Vector2) 决定检测矩形且 _ready 同步 CollisionShape2D；position 用 Node2D 原生（无自定义位置参数）；current_state:int=0；apply_state() 唯一效果出口（基类空默认）；set_state() 唯一变更入口（current_state=… + apply_state()）；touched() 空默认；call_item(new_state:int)=set_state（无范围判定）；touched()/call_item() 无直接 current_state 赋值；所有 item 子类必须继承本基类 | 代码走查 + Select-String 扫描 |
| ② | test_item 两状态 + E 键 + 范围 + toggle | 状态 0=initial_position（_ready 记录）/ 状态 1=上移 200px；切换 Tween 0.3s；E 键经 Player.interact_pressed → touched()（input_locked 时不发射）；范围判定优先 get_overlapping_bodies()；成立 toggle 0↔1、不成立无动作；call_item 汇入 set_state | 运行读回（stdout 打印）+ 截图 + 代码走查 |
| ③ | 测试场景 | 最小节点结构（§9.1）；白模零贴图；双向 toggle 判据满足（§9.2）；headless 加载 0 错误；--self-check PASS | 场景树检查 + headless 读回 |
| ④ | 四步运行验证 + 文档先行 + 本地提交不 push | §13 四步全部通过；文档首提交早于实现代码；git status 干净、提交信息英文、无 push | 命令输出 + git log |

## 13. 四步运行验证（verify 命令清单，实现 t2 / 验证 t3 直接使用）

```powershell
# ── 步骤一 文档先行 + 静态扫描 + 备份核对 ──
git -C F:\Godot\Spine log --oneline --follow -- Spine/docs/item_constraints.md
git -C F:\Godot\Spine log --oneline --follow -- Spine/scripts/objects/item.gd
#   → 文档首次提交必须早于实现代码首次提交
Test-Path F:\Godot\Spine\Spine\scripts\player\Player.gd.bak   # True（改 Player.gd 前已备份）
Test-Path F:\Godot\Spine\Spine\scripts\objects\item.gd        # True
Test-Path F:\Godot\Spine\Spine\scripts\objects\test_item.gd   # True
Test-Path F:\Godot\Spine\Spine\scenes\test_item.tscn          # True
Select-String -Path F:\Godot\Spine\Spine\scripts\objects\item.gd,F:\Godot\Spine\Spine\scripts\objects\test_item.gd,F:\Godot\Spine\Spine\scripts\player\Player.gd -Pattern ':= *(clamp|move_toward|lerp|min|max)\('
#   → 无输出（显式类型红线，§10）
Select-String -Path F:\Godot\Spine\Spine\scripts\objects\item.gd,F:\Godot\Spine\Spine\scripts\objects\test_item.gd -Pattern 'GameState|object_id|InteractableObject'
#   → 无输出（并行体系：item 不触碰既有链路，§8）
Select-String -Path F:\Godot\Spine\Spine\scripts\objects\test_item.gd -Pattern 'current_state\s*='
#   → 仅 set_state 路径内出现（切换必须汇入 set_state，§5.3；touched/call_item 内不得直接赋值）

# ── 步骤二 工程整体 headless 加载 ──
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine --quit-after 3
#   → exit 0；stdout 无 SCRIPT ERROR / ERROR / Parse Error

# ── 步骤三 测试场景 headless 加载 + 初始状态读回 + 自检读回 ──
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/test_item.tscn --quit-after 3
#   → exit 0；stdout 含 [test_item] ready state=0（无脚本错误）
F:\Godot\godot\godot.exe --headless --path F:\Godot\Spine\Spine res://scenes/test_item.tscn -- --self-check
#   → exit 0；stdout 含 [test_item] SELF-CHECK PASS
#     （call_item→set_state→apply_state→Tween 0.3s→落点上移 200px 全链路）

# ── 步骤四 窗口运行 + E 键交互读回 + 证据 + git 卫生 ──
F:\Godot\godot\godot.exe --path F:\Godot\Spine\Spine res://scenes/test_item.tscn
#   → 按 E（范围内）：stdout 依次含 [test_item] touched in_range=true 与 apply_state 目标 y 变化（0→1：y-200）
#   → 再按 E（仍范围内，§9.2 判据）：toggle 回 0（y 还原）
#   → 截图证据：初始态 / 状态 1 上移 200px 对比图 → Spine/shots/（已在 .gitignore）
git -C F:\Godot\Spine status --porcelain   # 实现提交后应为空
git -C F:\Godot\Spine log --oneline -3     # 本地提交、英文信息、无 push
```

## 14. 决策记录与剩余假设

已定案（用户规格拍板/推荐，实现按此执行，不得偏离）：

- A1 节点类型 Area2D（§4，依据规格①与仓库先例）。
- A2 E 键实现取规格推荐项「玩家发 interact_pressed 信号、item 监听」（§6）；备选项记录备用。
- A3 状态集合由子类定义：TestItem = {0, 1}（int）；基类不枚举。
- A4 Tween 0.3s、上移 200px：规格默认/定案；允许以常量或 @export（默认值=规格值）参数化（工程惯例，见 c3 §8 参数化偏好）。
- A5 overlaps_body() 按 Godot 4.7 译为 get_overlapping_bodies()。
- A6 item 状态不入 GameState/存档（规格未要求）。
- A7 白模零贴图（Polygon2D 色块）；测试场景地板 StaticBody2D（验证必需）。
- A8 读回打印与 --self-check：无 Godot MCP 的等效替代（团队目标④），仅测试链路，非玩法内容。

剩余假设（评审/集成前显式确认；均来自仓库既有约定或规格字面，无新增玩法设计）：

- H1 脚本文件路径按用户规格原样：`scripts/objects/item.gd`、`scripts/objects/test_item.gd`；仓库惯例为「脚本文件名=class_name（PascalCase）」，本模块以用户规格路径为权威，class_name 取 PascalCase（Item / TestItem）。如需改 PascalCase 文件名，须用户确认。
- H2 测试场景文件名 `scenes/test_item.tscn`（snake_case）：仓库现状证据（player.tscn / level_scene.tscn / c3_floor.tscn 与 c3_floor_constraints.md §4.4「场景文件名 snake_case」）；任务描述转述「命名 PascalCase」按 class_name/节点名理解（同句给出的脚本路径即小写）。如需 PascalCase 场景文件名，须用户确认。
- H3 size 默认值 Vector2(64, 64) 为工程建议；测试场景实际值见 §9.2 判据（可调）。
- H4 默认物理层 1 可满足判定（不改 project.godot）；如环境不符，在测试场景内显式配置 layer/mask 兜底（仍不改 project.godot）。
- H5 双向 toggle 演示需满足 §9.2 判据（状态 1 矩形仍覆盖玩家），否则「上移后够不到、toggle 不回来」——此为规格「toggle 0↔1」的测试可达性要求，非玩法变更。
- H6 同帧双触发（正式关卡并存时 InteractableObject.interact() 与 item touched() 同按 E 各自响应）为并行体系的设计语义，本模块不实现并存场景。

## 15. 变更记录

- 2026-09-05 初版：item 交互模块约束文档先行产出（t1 requirements）。内容：Item 基类与 TestItem API 契约、E 键信号流、范围判定、测试场景结构与四步运行验证清单。影响范围：仅新增 Spine/docs/item_constraints.md。回滚要点：删除本文件即可（未触碰任何代码/场景）。
