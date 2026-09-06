# Player 动画化约束文档

版本：v2.0（2026-09-06）
关联：scripts/player/Player.gd、scenes/player.tscn、assets/sprites/static.png / move1.png / move2.png
依据：docs/prompts/godot_player_animation_prompt.md（取代 v1.1 §4 中朝向翻转与移动/待机切换的排除条款；v1.1 其余条款继续有效）

## 1. 目标

v1.1 已接入 AnimatedSprite2D 单帧 `static`。本期（v2）增加**朝向状态机**（左/右）与**行走帧动画**，
全部作用于 `scenes/player.tscn` 与 `scripts/player/Player.gd`。

## 2. 素材事实（已实测）

- `static.png`：1280×1280 RGBA，角色包围盒 (181,259)-(813,977)，面朝**左**。
- `move1.png` / `move2.png`：**860×839 占位图**（包围盒 (31,28)-(822,796），画布与包围盒均与 static 不一致）。
  - ⚠ **已知后果**：同一 scale 下行走帧视觉会比静止帧**明显缩小且位置跳动**（画布小、边距比例不同）。
    照常接线（用户知情）；后续替换为 1280×1280 同规格素材后**无需改代码**。
- v1.1 对齐参数不变：`scale = 0.5348`、`position = (76.48, -148.23)`、碰撞盒 32×64。

## 3. 朝向状态机（facing）

- 状态：`facing ∈ { LEFT, RIGHT }`，**初始 RIGHT**。
- **更新唯一来源**：`Input.get_axis("move_left", "move_right")`。仅当轴值**非零**时把 facing 设为该方向——
  facing 永远等于玩家最后一次输入的移动方向。
- 松手、`StoryMonitor.input_locked`、被墙挡住等情况，facing **保持不变**。
- facing 为**运行态**：不写 GameState、不入存档；每次场景载入重置 RIGHT。

## 4. 翻转规则（flip_h）

素材原始朝向左：

| facing | AnimatedSprite2D.flip_h | 效果 |
|---|---|---|
| RIGHT | `true` | 全部帧左右反转，面朝右 |
| LEFT | `false` | 原样显示，面朝左 |

- 翻转作用于 AnimatedSprite2D 节点整体，对所有动画的所有帧（含 static）统一生效。
- `flip_h` 赋值收敛为**唯一出口** `_apply_facing()`（_ready 初始化 + facing 变更处调用），不允许散落多处。

## 5. SpriteFrames 动画定义（player.tscn）

- `static`（既有，保留）：单帧 static.png，loop=true，autoplay 保持 `static`。
- `walk`（新增）：4 帧，顺序严格 **static.png → move1.png → static.png → move2.png**，loop=true，**5 fps（每帧 0.2s）**。
- scale / position / 碰撞盒保持 v1.1 数值不变。

## 6. 播放切换逻辑（Player.gd）

- 每物理帧判定 `is_moving = absf(velocity.x) > 10.0`（阈值 `MOVE_ANIM_THRESHOLD`，可调）。
- `is_moving` → 播放/保持 `walk`；否则 → 播放/保持 `static`。
- 切换前判断当前动画，避免对同一动画重复 `play()` 导致帧序号每帧归零。
- 输入锁定分支 velocity 清零后**也调用动画更新** → 自然回落 static，朝向不变。

## 7. 明确不做（本期）

- 不做上下方向、跳跃/下落/转身过渡动画。
- 不改任何运动参数（motion_profile、legacy 移速字段、重力、碰撞盒、`_snap_to_floor`、输入映射）。
- 不引入 AnimationPlayer / AnimationTree，只用 AnimatedSprite2D。
- facing 不入 GameState、不入存档。
- 只动 `scenes/player.tscn`、`scripts/player/Player.gd`、本文档三个文件；其他零改动。

## 8. 验证

- headless 加载含 Player 的场景 0 报错。
- 运行清单：初始面朝右（static 已反转）；按 D 播 walk（4 帧 0.2s 循环，朝右）；松手回 static 朝向保持；
  按 A 立即朝左原样显示；移动换向即时翻转不中断；顶墙 velocity≈0 回 static 朝向保持；锁输入静止 static。
- 回归：c2 / c3 / c4 移动手感与交互不变（运动参数零改动）。

## 变更记录

- v1.0（2026-09-06）：AnimatedSprite2D 单帧接入，删 Polygon2D 白模。
- v1.1（2026-09-06）：scale ×4（0.5348），对齐公式 y=32−337·s、x=143·s。
- v2.0（2026-09-06）：朝向状态机 + walk 动画（godot_player_animation_prompt）；记录 move1/move2 占位图尺寸差异。
