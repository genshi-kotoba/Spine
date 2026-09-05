# Godot c2 / c4 场景制作 Prompt（含 c2 区域解锁流程）

> 将以下全文作为指令发送给目标 AI。本 prompt 是既有「代码框架」「Item 基类」「c3/bedroom」prompt 的延续，Item 父类（touched / call_item / 状态机 / E 键交互 / 高亮 set_highlight）、GameState 单例、bedroom 场景结构约定继续生效。

---

## 角色与任务

你是精通 Godot 4.x（GDScript 2.0）的开发工程师，通过 **Godot MCP 工具**直接操作我的 Godot 工程。本次任务：**制作 c2、c4 两个关卡场景及其 bedroom 场景，其中 c2 包含完整的三区域解锁流程**。

## 硬性约束（最高优先级）

1. 所有 `.tscn` / `.gd` 的创建与修改**必须通过 Godot MCP 完成**，不要只输出代码文本。
2. 每生成/修改一个文件，**严格对照我提供的《约束文档》逐条核对**；冲突时以约束文档为准；不清晰先提问，不要自行假设。
3. 每个文件写入后用 MCP 读回校验，确认无误再继续。

## 1. 基础场景：c2、c4、c2_bedroom、c4_bedroom

- **c2 / c4 白模与 c3_floor 完全相同**：复制 c3_floor 的结构（尺寸、地面、摄像机钳制参数、玩家生成逻辑），只改必要部分。
- 两个场景各有一个 **bedroom_door** 可交互对象：
  - 交互逻辑与 c3_level 中的 locked_bedroom **相同**（继承 Item 父类，touched = 范围内按 E → 场景跳转）。
  - c2 的 bedroom_door → 跳转 `scenes/c2_bedroom.tscn`；c4 的 → `scenes/c4_bedroom.tscn`。
  - **注意**：c2 的 bedroom_door 初始不可交互，详见第 3 节。
- **c2_bedroom / c4_bedroom 与既有 bedroom 场景结构相同**（高 = 对应 floor、宽 = 1/4、复用 player）。c4_bedroom 中央同样放置 ladder_window（同第 4 节）还是保持与 bedroom 完全一致——以《约束文档》为准，未规定则 c4_bedroom 与 bedroom 完全一致（含 test_item）。

## 2. c2 场景布局：三区域 + item

c2 地图从左到右均分为 3 个区域，区域边界做成可配置变量（`zone_boundaries`），供遮罩与阻挡共用：

| 区域 | 位置 | 可交互 item |
|---|---|---|
| kitchen | 左 1/3 | **candle**、**lego3** |
| living | 中 1/3 | **star**、**lego2** |
| study_room | 右 1/3 | **lego1** |

- 所有 item 继承 Item 父类，**它们的状态机全部由全局脚本 GameState 统一监控管理**（状态写入 GameState，key = item 唯一 ID；区域解锁逻辑监听 GameState 状态变化，不在 item 内部硬编码连锁逻辑）。
- 贴图用 assets 对应资产；先列出 assets 确认文件名，缺失则汇报。

## 3. c2 区域解锁流程（核心逻辑）

### 3.1 初始状态

- 玩家出生在 **kitchen**。
- **living 与 study_room 处于黑暗状态**：用 **shader 编写黑暗遮罩**覆盖该区域（每区域一块 ColorRect/TextureRect + 变暗 shader，或全屏 shader 按区域 x 范围遮罩），kitchen 正常显示。
- **玩家无法进入黑暗区域**：在区域边界放置阻挡碰撞（StaticBody2D），走到边缘被挡下。
- **三个 lego（lego1/2/3）初始不可交互**：touched 不响应、**不出现交互提示**（即不触发高亮 set_highlight）。
- **bedroom_door 初始不可交互**：同样不响应、无交互提示。

### 3.2 解锁链条（由 GameState 状态驱动）

| 触发 | 结果 |
|---|---|
| 与 **candle** 交互 | candle 消失（状态变更 + 隐藏节点）；living 黑暗遮罩移除、正常显示；living 边界阻挡移除，玩家可进入 |
| 与 **star** 交互 | star 消失；study_room 黑暗移除；边界阻挡移除；**三个 lego 全部变为可交互**、出现交互提示（高亮恢复正常逻辑） |
| 与任一 **lego** 交互 | 该 lego 消失 |
| **全部三个 lego 都已交互**（GameState 中三者状态均为已交互） | **bedroom_door 变为可交互**、出现交互提示 |

- 实现要求：
  - 连锁反应统一由 c2 场景脚本（或 StoryMonitor 条件表，以《约束文档》为准）**监听 GameState.state_changed 驱动**，不要在 item 脚本里互相直接引用。
  - "消失" = 从场景移除/隐藏并更新 GameState；读档恢复时按 GameState 状态重建（已消失的不出现、已解锁的区域不黑暗）。
  - 可交互开关建议在 Item 基类增加 `interactable: bool`（false 时 touched 直接返回、不参与高亮），lego 与 bedroom_door 复用。

## 4. c2_bedroom 场景：ladder_window + 白屏转场

- c2_bedroom **中央不放置 test_item**，改为放置 **ladder_window**：
  - 继承 Item 父类；**状态机有两个状态**（如 closed / open），交互即切换状态（toggle 或单向切换，以《约束文档》为准）。
- **与 ladder_window 交互后触发转场**：
  1. 画面在 **5 秒内逐渐变成纯白色**（全屏白色 ColorRect + Tween 渐显 alpha 0→1，或 white-fade shader）。
  2. 纯白画面**持续 3 秒**。
  3. **切换场景到 computer_screen**（`change_scene_to_file`）。
- 转场期间锁定玩家输入（复用 lock_input），防止二次触发。

## 交付与验证

1. 文件清单：c2/c4 场景及脚本、bedroom_door / candle / star / lego×3 / ladder_window 脚本、c2_bedroom/c4_bedroom、黑暗遮罩 shader、Item 基类 interactable 改动。
2. 每个文件 MCP 读回校验 + 对照约束文档自检。
3. 运行验证清单（全部可演示）：
   - c4：白模同 c3，bedroom_door 交互进 c4_bedroom，结构同 bedroom；
   - c2 初始：出生 kitchen，living/study_room 黑暗，边界被阻挡，lego 无提示不可交互，bedroom_door 无提示不可交互；
   - 交互 candle → candle 消失、living 亮、可进 living；
   - 交互 star → star 消失、study_room 亮、三个 lego 出现提示可交互；
   - 交互三个 lego 后 → bedroom_door 出现提示，可交互进入 c2_bedroom；
   - c2_bedroom 中无 test_item、中央为 ladder_window；交互 → 状态切换 → 5 秒渐白 → 纯白 3 秒 → 进入 computer_screen。
4. 存档验证：中途保存退出重进，黑暗/消失/解锁状态正确恢复。
5. 列出需要我在编辑器手动配置的事项。
