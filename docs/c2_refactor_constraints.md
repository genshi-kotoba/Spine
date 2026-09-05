# C2 场景重构（单背景 + ladder 四态线性流程）：约束文档与验收契约

> 依据：`docs/prompts/godot_c2_refactor_prompt.md`（2026-09-06 从 NetDrive 拉取）+ 用户 v2 变更指令（2026-09-06，见 §10 变更记录）。冲突裁决以《Spine-项目约束.md》《Spine-框架约束.md》及本文为准。
> 本文件是本次重构的**唯一权威约束**：实现、验证、评审均以本文为准。**硬约定：代码产出前先出本文档。**

## 1. 用户规格原文

**v1（prompt §1~6）**：拆除三区域解锁/黑暗/景深；单背景；curten；ladder 四态状态机（GameState key `"c2_ladder"`，`advance_state()` 推进唯一入口、`apply_state()` 贴图唯一出口）；lego 连锁（音效降级 + c2_dialogue1-3，MODE_INTERACTIVE）；结局（锁输入 → curten 消失 → 开窗音效 → 4s 渐白 → 3s 纯白 → computer_screen）。

**v2（用户 2026-09-06 指令，优先级高于 v1 冲突处）**：

1. **lego 交互时序改为**：每次 lego 交互完成 → ① 首先播放音效并唤起对话；② 这期间摄像头强制在 **0.75 秒**内缓慢平滑移动到**场景正中间**；③ 然后才更换 ladder 的 texture；④ 然后再在 **0.75 秒**内缓慢平滑移动回玩家角色身上恢复跟随。
2. **结局触发改为**：ladder 到达最后一个状态（"3"）后**不走 v1 自动结局**；而是 **curten 变成可交互 item**；玩家对 curten 按 E 交互 → curten 消失 → 才开始播放音乐、屏幕变白等一系列结局流程。

## 2. 工程事实盘点

- 工作区 = res:// = `C:\Users\31088\Desktop\翌光计划\Spine`；引擎 headless 读回校验等效 MCP。
- **相机机制**（LevelScene.gd）：`_process` 每帧调 `_update_camera` 写 `_camera.global_position.x`（c2 camera_smoothing=0 → 即时）；只管理 x；y = 玩家 y（相机是 Player 子节点）；`_camera.offset = (0, -336.5)`（FloorTemplate 取景偏移）；clamp：half=960（视口 1920），x∈[960, 2880]。
- **接管方案（决策 E1）**：C2Floor **覆写 `_update_camera()`** + `_camera_locked` 标志（锁时直接 return，解锁恢复 super）。GDScript 虚方法分派使 LevelScene._process 调到子类覆写——**LevelScene.gd 零改动**。
- **VanishItem 复用（决策 E2）**：curten 可交互化直接复用 vanish_item.gd（`_try_touch` → set_state(1) → 隐藏+关交互 + 读档恢复），state_id=`"c2_curten"`，不新建脚本。
- **curten 可达性（决策 E3）**：curten 视觉在 (1920,320) 墙上窗口处，玩家够不到；检测区 size=(1024,1300) 居中于节点 → 覆盖 y∈[-330,970]，玩家站梯子下方按 E 即可交互。
- 素材/对话/场景现状同 v1（C2_background 1280×422 scale3；ladder1-3 1011×1024 scale0.8 @ (1920,578)；c2开窗.mp3 存在；ladder.mp3 暂缺）。

## 3. 模块边界

**In scope（v2 增量）**

- 更新：`docs/c2_refactor_constraints.md`（本文 v2，先于代码）
- 修改：`scripts/scenes/C2Floor.gd`（时序改造 + 相机接管 + curten 解锁 + 结局改触发；改前刷新 .bak）
- 修改：`scenes/c2_floor.tscn`（Items/Curten 改 Area2D + vanish_item + 碰撞 + interact_pressed 连接；改前刷新 .bak）

**Out of scope / 禁区（违反即 FAIL）**

- 不改 LevelScene.gd / FloorTemplate.gd / item.gd / vanish_item.gd / Ladder.gd / GameState.gd / StoryMonitor.gd / DialogueManager.gd / Player.gd / player.tscn；
- 不动 c3 / c4 / bedroom / computer_screen / dialogue_test；`c2_bedroom.tscn` 保留；
- 不改输入映射 / project.godot；不新建 ladder.mp3；不 push。

## 4. API 契约（v2）

### 4.1 C2Floor.gd（在 v1 基础上改）

- 新增常量：`SCENE_CENTER: Vector2 = Vector2(1920, 619.5)`（地图正中间视野中心）；`CAMERA_MOVE_TIME: float = 0.75`。
- 新增成员：`var _camera_locked: bool = false`。
- **相机接管**：`func _update_camera(delta: float) -> void` 覆写——`_camera_locked` 为真直接 return；否则 `super._update_camera(delta)`。
- `_on_state_changed(object_id, new_state)`：
  - id ∈ LEGO_IDS 且 "1" → `_run_lego_sequence()`（async 即发即忘，见下）；
  - id == `Ladder.STATE_KEY` 且 new_state == "3" → `_enable_curten()`（`_curten.set_interaction_enabled(true)`；读档恢复同样调用，见 _restore_progress）；
  - id == `ID_CURTEN` 且 "1" → `_start_ending()`。
- **`_run_lego_sequence()`（v2 时序核心，async）**：
  1. `_play_ladder_sfx()`（缺失 push_warning 降级，不变）；
  2. `n = _lego_count()`；`DIALOGUE_PATHS.has(n)` → `DialogueManager.start_dialogue(DIALOGUE_PATHS[n], MODE_INTERACTIVE)`；
  3. `_camera_locked = true`；Tween `_camera.global_position` → `SCENE_CENTER - _camera.offset`（= (1920, 956)，视野中心正好落在地图正中），时长 0.75s，`TRANS_SINE + EASE_IN_OUT`（缓慢平滑）；`await` 完成；
  4. `_ladder.advance_state()`（此刻才换贴图）；
  5. Tween `_camera.global_position` → `Vector2(_follow_target_x(), _player.global_position.y)`（回到跟随位），0.75s 同样缓动；`await` 完成；
  6. `_camera_locked = false`（恢复 LevelScene 逐帧跟随，目标 x 与 clamp 结果一致，无缝衔接）。
- `_follow_target_x() -> float`：复现 clamp 语义——half=视口宽/2×zoom；min>max 倒挂时返回地图中心 x；否则 `clamp(_player.position.x, map_min_x+half, map_max_x-half)`（显式类型，红线）。
- `_play_ladder_sfx()` / `_lego_count()` / `LEGO_IDS` / `DIALOGUE_PATHS` / `ID_CURTEN` / `FLAG_ENDING` / `ladder_sfx_path`：同 v1 不变。
- **删除 v1 部件**：`DialogueManager.dialogue_finished` 连接与 `_on_dialogue_finished()`（结局不再由对话结束触发）。
- `_start_ending()`（v2 微调）：防重入 flag → lock_input → WindowSfx.play → 4s 渐白 → 3s 纯白 → stop + 转场。**不再 queue_free curten、不再写 ID_CURTEN**（curten 已被 VanishItem 自行隐藏并写状态）。
- `_restore_progress()`（v2 读档语义）：
  - ladder=="3" 且 curten 未消失 → `_enable_curten()`（重进后 curten 仍可交互）；
  - `ID_CURTEN=="1"`（结局中途退出）→ 清 `FLAG_ENDING` 后 `call_deferred("_start_ending")` 补播结局（防死档，决策 E4）；
  - 相机/lego/ladder 由各自机制恢复，不重复处理。

### 4.2 c2_floor.tscn（v2 增量）

- `Items/Curten`：Node2D → **Area2D**，script=vanish_item.gd（既有 ext_resource id 6），`size = Vector2(1024, 1300)`、`state_id = "c2_curten"`、`interactable = false`、`highlight_enabled = true`；position (1920, 320) 不变；
  - 新增子节点 `CollisionShape2D`（sub_resource `curten_col`，RectangleShape2D 1024×1300，基类 _ready 同步 size）；
  - 原 `Sprite2D` 子节点（scale 0.8、texture curten.png）保留不动；
  - 新增连接：`interact_pressed` from Player → Items/Curten → touched。
- 其余节点（Background / Ladder / Lego1-3 / Sfx / EndingLayer）不动。

### 4.3 不变项（v1 契约继续有效）

- Ladder.gd 全部（四态、唯一出入口、读档重建、不可交互）；
- lego 初始可交互、state_id 不变；对话文件沿用；ladder.mp3 缺失降级；
- 结局时序（锁输入 → 音效 → 4s 渐白 → 3s 纯白 → computer_screen，防重入）。

## 5. 信号流（v2）

```
E → LegoN.touched() → set_state(1) → GameState["c2_legoN"]="1"（VanishItem 隐藏）
  → C2Floor._run_lego_sequence：
      LadderSfx（缺失仅 warning）→ start_dialogue(c2_dialogue{n}) 锁输入
      → 相机锁 + 0.75s 平滑到场景正中 → Ladder.advance_state() 换贴图
      → 0.75s 平滑回玩家 → 相机解锁恢复跟随
GameState["c2_ladder"]="3" → C2Floor：curten.set_interaction_enabled(true)
E → Curten.touched() → set_state(1) → GameState["c2_curten"]="1"（VanishItem 隐藏）
  → C2Floor._start_ending：lock_input → WindowSfx → 4s 渐白 → 3s 纯白 → computer_screen
```

## 6. 编码红线与惯例

- 禁止 `:=` 推断 Variant 内建函数返回值（clamp/min/max/lerp/move_toward/randf_range），显式标注类型。
- 命名/私有前缀/信号 snake_case 同项目惯例；item 脚本互不引用，连锁只经 GameState。
- 相机接管只经 `_camera_locked` + Tween，不改 LevelScene 任何代码。

## 7. 验收标准表（v2）

| # | 规格 | 验收标准 | 证据 |
|---|---|---|---|
| ① | lego 时序 | 任一 lego 交互 → 先音效+对话 → 相机 0.75s 平滑到场景正中 → 然后 ladder 换贴图 → 0.75s 平滑回玩家恢复跟随 | 窗口运行目视 |
| ② | 相机平滑 | 两段移动均缓慢平滑（SINE 缓动），无瞬移；结束后跟随无缝 | 运行 |
| ③ | 结局改触发 | ladder=3 后无自动结局；curten 变为可交互（靠近高亮、E 有效） | 运行 |
| ④ | curten 交互 | E → curten 消失 → 锁输入+开窗音效+4s 渐白+3s 纯白+转场 computer_screen；整局一次 | 运行 |
| ⑤ | 读档 | ladder=3 重进 curten 仍可交互；结局中途退出重进补播结局转场 | 存档验证 |
| ⑥ | 回归 | 禁区文件零改动；c2/c3/c4 headless 0 错误 | git diff + headless |

## 8. verify 命令清单

```powershell
# 1 红线扫描（应无输出）
Select-String -Path scripts\scenes\C2Floor.gd -Pattern ':= *(clamp|move_toward|lerp|min|max|randf_range)\('
# 2 禁区核对（应无 diff）
git diff --name-only HEAD -- scripts/scenes/LevelScene.gd scripts/scenes/FloorTemplate.gd scripts/objects/Ladder.gd scripts/objects/vanish_item.gd
# 3 headless（均无 SCRIPT ERROR）
& 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . res://scenes/c2_floor.tscn --quit-after 3
# 4 窗口运行 §7 验收
& 'D:/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . res://scenes/c2_floor.tscn
```

## 9. 决策记录与剩余假设

v2 新增定案：

- E1 相机接管用 C2Floor 覆写 `_update_camera` + `_camera_locked`，LevelScene 零改动。
- E2 curten 复用 vanish_item.gd（不新建脚本），state_id `c2_curten`。
- E3 curten 检测区 1024×1300（窗口垂到地板，玩家站梯子下方可交互）；视觉位置不变。
- E4 结局中途退出重进：清 flag 补播结局（防死档）。
- E5 相机目标：正中 = 视野中心 (1920,619.5)（相机 global_position 目标 (1920,956)）；返回目标 = clamp 后跟随 x + 玩家 y，与 LevelScene 逐帧写值一致保证无缝。
- E6 缓动统一 `TRANS_SINE + EASE_IN_OUT`（"缓慢平滑"）。

v1 定案沿用（未被 v2 覆盖的部分）：

- D1 背景 scale3 @ (1920,619.5)；D2 ladder (1920,578) scale0.8；D3 curten 视觉 (1920,320) scale0.8；
- D7 EndingLayer layer=30；D8 c2_dialogue1-3 沿用不覆盖；H1 lego 占位贴图与检测区不变；H3 ladder.mp3 用户自补。

被 v2 取代（作废）：

- ~~D4/D6：dialogue3 播完自动触发结局~~（改 curten 交互触发）；~~结局内 queue_free curten / 写 ID_CURTEN~~（VanishItem 自行处理）。

## 10. 变更记录

- 2026-09-06 v1 初版：c2 重构约束文档先行产出（prompt §1~6 全覆盖）。
- 2026-09-06 v2：按用户指令改 lego 时序（音效+对话 → 相机 0.75s 至正中 → 换 ladder 贴图 → 0.75s 回玩家）与结局触发（ladder=3 后 curten 可交互化，E 触发结局）；影响 C2Floor.gd 与 c2_floor.tscn 的 Curten 节点；LevelScene 零改动（覆写接管）。回滚要点：`git checkout 859f7b2 -- scripts/scenes/C2Floor.gd scenes/c2_floor.tscn` 并还原本文件 v1。
