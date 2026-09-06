# Godot Player 朝向状态机 + 行走动画 Prompt

> 将以下全文作为指令发送给目标 AI。本 prompt 是既有「代码框架」「Player 动画化（v1.1 单帧接入）」「Player Motion Contract」等约束的延续，GameState / StoryMonitor 输入锁 / motion_profile 等约定继续生效。
> **本 prompt 取代 `docs/player_animation_constraints.md` v1.1 第 4 节「明确不做」中关于朝向翻转与移动/待机动画切换的排除条款（v1.1 其余条款继续有效）；冲突时以本 prompt 及《Spine-项目约束.md》《Spine-框架约束.md》为准。**

---

## 角色与任务

你是精通 Godot 4.x（GDScript 2.0）的开发工程师，通过 **Godot MCP 工具**直接操作我的 Godot 工程（项目路径 `C:\Users\31088\Desktop\翌光计划\Spine`）。本次任务：为 Player 增加**朝向状态机**（左/右）与**行走帧动画**，全部作用于 `scenes/player.tscn` 与 `scripts/player/Player.gd`。

## 硬性约束（最高优先级）

1. 所有 `.tscn` / `.gd` / 子资源的新建、修改、删除**必须通过 Godot MCP 完成**，不要只输出代码文本。
2. **文档先行**：改动任何代码/场景前，先把 `docs/player_animation_constraints.md` 升级为 **v2**，完整覆盖本 prompt 第 1~6 节规则（状态机定义、翻转规则、动画帧序列、切换逻辑、明确不做）；实现完成后对照该文档逐条自检。
3. 严格对照《Spine-项目约束.md》《Spine-框架约束.md》《docs/player_motion.md》及 v1.1 动画约束；冲突时以约束文档为准；不清晰先提问，不要自行假设。
4. 每个文件写入后用 MCP 读回校验，确认无误再继续。
5. **影响面控制**：只动 `scenes/player.tscn`、`scripts/player/Player.gd`、`docs/player_animation_constraints.md` 三个文件。CollisionShape2D（32×64）、Camera2D、motion_profile / 重力等全部运动参数、`_snap_to_floor`、输入映射，一律不改；其他场景与脚本零改动。

## 1. 现状与素材事实（已实测）

- Player 当前为 `AnimatedSprite2D`（单帧动画 `static`，loop，autoplay），`scale = 0.5348`，`position = (76.48, -148.23)`，视觉高约 384px。
- `assets/sprites/static.png`：1280×1280，角色**面朝左**。
- `assets/sprites/move1.png`、`assets/sprites/move2.png`：**当前为 860×839 的占位图**，画布尺寸与包围盒均与 static.png 不一致。
  - 照常按本 prompt 接线（占位图我知情，后续自行替换为 1280×1280 同规格素材）；
  - 但必须在 v2 约束文档与交付报告中**显式列出该尺寸差异及其后果**（同一 scale 下行走帧视觉会缩小/跳动，替换同规格素材后无需改代码）；
  - 若接线前发现素材与我描述不符（如缺文件），**停止并报告，不要自行寻找替代素材**。

## 2. 朝向状态机（facing）

- 状态：`facing ∈ { LEFT, RIGHT }`，**初始为 RIGHT**。
- **更新唯一来源**：`move_left` / `move_right` 输入轴（`Input.get_axis`）。仅当轴值**非零**时，将 facing 设为该方向——即 facing 永远等于**玩家最后一次输入的移动方向**。
- 松开按键、`StoryMonitor.input_locked` 锁输入、被墙挡住等情况，facing **保持不变**。
- facing 为**运行态**：不写入 GameState、不入存档；每次场景载入重置为 RIGHT。该决策写入 v2 文档。

## 3. 翻转规则（flip_h）

素材原始朝向为左，因此：

| facing | AnimatedSprite2D.flip_h | 效果 |
|---|---|---|
| RIGHT | `true` | 全部帧左右反转，面朝右 |
| LEFT | `false` | 原样显示，面朝左 |

- 翻转作用于 AnimatedSprite2D 节点整体，对**所有动画的所有帧**（含 static 静止帧）统一生效。
- `flip_h` 设置收敛为**唯一出口**（facing 变更处统一调用），不允许散落多处赋值。

## 4. SpriteFrames 动画定义（player.tscn）

- `static`（既有，保留）：单帧 `static.png`，loop=true，autoplay 保持为 `static`。
- `walk`（新增）：4 帧，顺序严格为 **`static.png → move1.png → static.png → move2.png`**，loop=true，**5 fps（每帧 0.2 秒）**。
- scale / position / 碰撞盒保持 v1.1 数值不变。

## 5. 播放切换逻辑（Player.gd）

- 每物理帧判定 `is_moving = absf(velocity.x) > 10.0`（阈值写入 v2 文档，可调）。
- `is_moving` → 播放/保持 `walk`；否则 → 播放/保持 `static`（静止即 static.png 单帧，翻转随 facing 自动生效）。
- 切换动画前判断当前动画，避免对同一动画重复 `play()` 导致帧序号每帧归零。
- 输入锁定时 velocity 已被清零 → 自然回落 `static`，朝向不变，无需特判。

## 6. 明确不做（本期）

- 不做上下方向、跳跃/下落/转身过渡动画。
- 不改任何运动参数（motion_profile、legacy 移速字段、重力、碰撞盒）。
- 不引入 AnimationPlayer / AnimationTree，只用 AnimatedSprite2D。
- facing 不入 GameState、不入存档。
- 其他场景、脚本、素材文件零改动。

## 交付与验证

1. 文件清单：`docs/player_animation_constraints.md`（升级 v2）、`scenes/player.tscn`（改）、`scripts/player/Player.gd`（改）。
2. 每个文件 MCP 读回校验 + 对照 v2 文档逐条自检。
3. headless 加载含 Player 的场景 0 报错。
4. 运行验证清单（全部可演示）：
   - 初始：角色面朝**右**（static 帧已反转）；
   - 按 D 移动：播放 walk，4 帧顺序 static→move1→static→move2 循环，每帧 0.2s，面朝右；
   - 松手：回到 static 单帧，朝向保持右；
   - 按 A：flip_h 立即取消，面朝左原样显示，walk 正常播放；
   - 移动中换向：facing 即时翻转，动画不中断重置异常；
   - 顶墙持续按方向键：velocity≈0 时回 static，facing 保持按键方向；
   - 对话/剧情锁输入期间：静止 static，朝向不变。
5. 回归：c2 / c3 / c4 移动手感与交互行为不变（运动参数零改动）。
6. 交付报告中显式列出：move1/move2 占位图尺寸差异说明、需要我在编辑器手动确认的事项（如后续替换素材后的 import 与视觉对齐抽查）。
