# Godot C3 场景完善 + bedroom 场景 Prompt

> 将以下全文作为指令发送给目标 AI。本 prompt 是既有「代码框架」与「Item 基类」prompt 的延续，`objects/item.gd`（touched / call_item / 状态机 / E 键范围交互）约定继续生效。

---

## 角色与任务

你是精通 Godot 4.x（GDScript 2.0）的开发工程师，通过 **Godot MCP 工具**直接操作我的 Godot 工程。本次任务：**完善 c3 场景（lockedbedroom 交互跳转），并新建 bedroom 场景**。

## 硬性约束（最高优先级）

1. 所有 `.tscn` / `.gd` 的创建与修改**必须通过 Godot MCP 完成**，不要只输出代码文本。
2. 每生成/修改一个文件，**严格对照我提供的《约束文档》逐条核对**；冲突时以约束文档为准；不清晰先提问，不要自行假设。
3. 每个文件写入后用 MCP 读回校验，确认无误再继续。

## 1. c3 场景：lockedbedroom 交互对象

- 在 c3 场景（c3floor）中放置可交互对象 **lockedbedroom**。
- 脚本：`objects/lockedbedroom.gd`，**必须继承 item 父类**（`extends Item` / `extends "res://objects/item.gd"`）。
- **touched() 行为**：玩家在其交互范围内按下 E 键触发时 → **切换场景到 bedroom**（`get_tree().change_scene_to_file("res://scenes/bedroom.tscn")`）。
  - 范围判定沿用 item 基类约定（Area2D 重叠 / size 矩形）。
  - 场景跳转直接执行，不改状态机；如《约束文档》要求记录"已进入卧室"状态，则先写 GameState 再跳转。
- 贴图/尺寸使用 assets 中对应资产；先列出 assets 确认实际文件名，缺失则向我确认。

## 2. bedroom 场景（新建）

- 文件：`scenes/bedroom.tscn` + `scenes/bedroom.gd`。
- **场景尺寸**：
  - y 轴大小与 c3floor **完全一致**；
  - x 轴大小 = **c3floor x 轴的四分之一**。
  - 场景边界 / 摄像机 `map_min_x` / `map_max_x` 等参数按此比例设置（直接引用 c3floor 的配置值计算，不要硬编码两遍导致脱节）。
- **玩家角色**：与 c3floor 一致——复用同一 `player/player.tscn` 实例，移动、跟随摄像机、边缘钳制逻辑全部沿用框架实现；出生位置放在场景入口侧（默认左端，可按《约束文档》调整）。

## 3. bedroom 中的 test_item（带高亮）

- 在 bedroom 场景中放置一个 **test_item**，行为与 `godot_item_prompt.md` 定义完全一致：
  - 继承 item 父类；状态机 0 = 初始位置 / 1 = 上移 200px；
  - E 键 + 玩家在范围内 → 状态 toggle；范围外无效。
- **新增需求：交互高亮**
  - 当玩家处于可以与该 item 交互的位置（即 touched 判定范围内）时，**item 高亮显示**；离开范围后立即恢复常态。
  - 实现建议（以《约束文档》为准）：复用 item 基类的 Area2D 进出信号（`body_entered` / `body_exited`）切换高亮，无需每帧轮询。
  - 高亮形式：`modulate` 提亮（如 1.3 倍亮度）或描边 shader；优先用简单的 modulate 方案，效果参数做成变量便于调整。
  - **建议把高亮能力下沉到 item 基类**（`set_highlight(on: bool)`，默认关闭），所有子类可复用；test_item 在 bedroom 中开启。

## 交付与验证

1. 文件清单：`objects/lockedbedroom.gd`、c3 场景改动、`scenes/bedroom.tscn/.gd`、item 基类高亮改动（如有）。
2. 每个文件 MCP 读回校验 + 对照约束文档自检。
3. 运行验证清单（全部可演示）：
   - c3 中玩家走近 lockedbedroom 按 E → 进入 bedroom 场景；
   - bedroom 高度与 c3floor 一致、宽度为其 1/4；玩家可左右移动，摄像机跟随且在边界停住；
   - 玩家走近 test_item → item 高亮；走开 → 高亮消失；
   - 高亮状态下按 E → test_item 上移 200px，再按复位；范围外按 E 无效。
4. 列出需要我在编辑器手动配置的事项（贴图、碰撞层、出生点微调等）。
