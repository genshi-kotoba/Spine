# Godot Item 基类 + test_item 实现 Prompt

> 将以下全文作为指令发送给目标 AI。

---

## 角色与任务

你是精通 Godot 4.x（GDScript 2.0）的开发工程师，通过 **Godot MCP 工具**直接操作我的 Godot 工程。本次任务：**创建 item 基类，并实现第一个子类 test_item**。

## 硬性约束（最高优先级）

1. 所有 `.tscn` / `.gd` 的创建与修改**必须通过 Godot MCP 完成**，不要只输出代码文本。
2. 每生成/修改一个文件，**严格对照我提供的《约束文档》逐条核对**；约束文档与本 prompt 冲突时以约束文档为准；要求不清晰时先提问，不要自行假设。
3. 每个文件写入后用 MCP 读回校验语法与节点引用，确认无误再继续。

## 1. item 基类

- 文件：`objects/item.gd`。
- 基类节点类型：依《约束文档》选择 `Area2D` 或 `Node2D`（需要碰撞范围检测时优先 Area2D）。
- **本项目中所称的所有 item 都必须继承自该父类**（`extends "res://objects/item.gd"` 或 `class_name Item` 后 extends Item）。

### 参数（成员变量）

| 参数 | 类型 | 说明 |
|---|---|---|
| `size` | Vector2 | item 的尺寸，同时决定其"包含范围"（碰撞/判定区域） |
| `position` | Vector2 | 节点位置（Node2D 原生属性，基类不重复定义，直接使用） |
| 状态机 | int（当前状态）+ 状态定义 | 用整型枚举表示状态集合，`current_state` 保存当前状态；状态切换时统一走 `apply_state()` 刷新表现 |

### 方法

| 方法 | 签名 | 说明 |
|---|---|---|
| `touched()` | `func touched() -> void` | item 被触发的入口。基类提供空实现/默认实现，子类覆写具体行为 |
| `call()` | `func call_item(new_state: int) -> void` | 外部调用、直接指定状态机目标状态的方法（避免与 GDScript 内建 `call()` 冲突，命名为 `call_item`，若《约束文档》允许覆盖内建名则从其规定）。切换状态机 → `apply_state()` |

- 基类内部约定：`set_state(new_state)` 统一负责状态变更 + `apply_state()`，`touched()` 与 `call_item()` 最终都汇入该路径。

## 2. test_item 子类

- 文件：`objects/test_item.gd` + 对应测试场景 `scenes/test_item_demo.tscn`（或按《约束文档》指定的场景组织方式）。
- 继承 item 基类。
- **状态机：两个状态**

| 状态 | 值 | 表现（apply_state 实现） |
|---|---|---|
| 初始 | 0 | 位于初始位置（_ready 时记录的 `initial_position`） |
| 上移 | 1 | 在初始位置基础上 **上移 200px**（`initial_position + Vector2(0, -200)`） |

- 状态切换移动可用 `Tween` 做平滑过渡，也可直接瞬移——以《约束文档》为准；未规定则用 Tween，时长 0.3s。

### touched() 实现（核心逻辑）

`touched()` 的触发条件与判定：

1. **监听玩家按下 E 键**：通过输入映射 `interact`（E 键）触发。实现方式二选一，以《约束文档》为准：
   - item 在 `_unhandled_input()` 中检测 E 键按下；
   - 或由玩家脚本发出 `interact_pressed` 信号、item 监听该信号（推荐，耦合更低）。
2. **判定玩家位置是否在 test_item 包含的范围内**：
   - 范围 = 以 test_item 的 position 为中心/原点（按节点锚点约定）、边长为 `size` 的矩形区域；
   - 若玩家节点在该矩形内（优先用 Area2D 重叠检测 `overlaps_body()`，备选 `Rect2.has_point(player.global_position)`），判定成立。
3. **判定成立 → 切换状态机**：当前为 0 则变 1，当前为 1 则变 0（toggle）。
4. 判定不成立 → 不做任何事。

## 交付与验证

1. 文件清单：`objects/item.gd`、`objects/test_item.gd`、测试场景 .tscn（内含一个 Player 占位节点用于演示 E 键交互）。
2. 每个文件写入后 MCP 读回校验。
3. 运行验证清单（全部可演示）：
   - 启动测试场景，test_item 处于状态 0（初始位置）；
   - 玩家走进 test_item 范围按 E → test_item 上移 200px（状态 1）；
   - 再按 E → 回到初始位置（状态 0）；
   - 玩家在范围外按 E → test_item 无反应。
4. 列出需要我在编辑器手动配置的事项（如输入映射 `interact` 绑定 E 键、碰撞层设置）。
