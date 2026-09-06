# c5_floor 新场景：约束文档

版本：v1.0（2026-09-06）
依据：docs/prompts/godot_c3end_c5_prompt.md 任务 B
关联：scenes/c5_floor.tscn、scripts/scenes/C5Floor.gd、scripts/components/EndingTextSequence.gd、scripts/scenes/WorkScreen.gd、texts/

## 1. 目标

C5 楼层：单背景 + 3 个隐形触发区顺序唤起 tr1/tr2/tr3 对话 + 三段全播后 2s 渐黑 → 七段文字序列（1~7.txt）→ 自动退出游戏。

## 2. 偏差与决策记录（先于实现）

- **D1 文本路径**：prompt 写 `res://dialogues/tr*.txt`、`res://dialogues/1~7.txt`，但用户已把 10 份**真实文本**放在
  `res://texts/`（tr1~tr3.txt、1~7.txt，非占位）。以实际位置 **texts/** 为准，不再创建占位、不挪动文件。
- **D2 C5.png 缺失（已解决 2026-09-06）**：`res://assets/sprites/C5.png` 已到位，实测 **2172×724**（宽高比 3:1）。
  按预留规则接线：高度 1280 → 宽度 = 1280 × 3 = **3840**，uv = 原生尺寸 (2172,724)，接法与 c4_floor Background/Rect 完全一致。
  ~~场景 Background/Rect 先放纯色占位（Color(0.10,0.10,0.12)）~~ 已替换为纹理。
- **D3 地图宽度（已确认 2026-09-06）**：实测宽度 3840，与占位值一致 → `map_max_x = 3840` 不变，触发区 960/1920/2880 均分三段亦不变。
- **D4 退出出口**：EndingTextSequence 播完发 `sequence_finished`；`get_tree().quit()` 由 C5Floor 执行（组件不自带退出）。

## 3. 场景骨架（c5_floor.tscn，继承 floor_template.tscn）

- 根节点 C5Floor（instance floor_template），script=C5Floor.gd（`class_name C5Floor extends FloorTemplate`）。
- exports：`player_spawn_position = (320, 956)`、`camera_position_offset = (0, -336.5)`、`camera_smoothing = 0.0`、
  `map_max_x = 3840`（D3 占位）。
- `Background/Rect`（Polygon2D）：3840×1280 @ (1920,619.5)，纯色占位（D2）。
- `Environment`：Floor/Ceiling/WallLeft/WallRight 与 c4_floor **逐项一致**
  （floor_col 3840×40、ceiling_col 3840×40、wall_side_col 20×817；Floor@(1920,1008) cs 偏移 (5,-133)、
  Ceiling@(1920,231)、WallLeft@(0,619.5)、WallRight@(3840,619.5)）。
- `Triggers`：Trigger1/2/3 = Area2D + CollisionShape2D（trigger_col 240×817），仅碰撞无视觉、
  不继承 Item、无高亮、不响应 E。等间距横排：**x = 960 / 1920 / 2880，y = 619.5**（D3 宽度下三分点）。
- `EndingLayer`（CanvasLayer layer=50）→ `BlackRect`（ColorRect 全屏黑、IGNORE、初始 `modulate.a=0`）。
- `EndingTextSequence`（CanvasLayer layer=60，挂 EndingTextSequence.gd）。

## 4. 触发区逻辑（C5Floor.gd）

- `_ready`：super → 连 3 个 trigger 的 `body_entered` → `_on_trigger_entered(body, idx)`；连
  `DialogueManager.dialogue_finished` → `_on_dialogue_finished`。
- 进入判定：body is Player 且 `GameState.get_process_flag("c5_tr{idx}_shown") == false` →
  置旗标 true、`set_deferred("monitoring", false)`（整局一次）→
  `DialogueManager.start_dialogue("res://texts/tr{idx}.txt", MODE_INTERACTIVE)`，记录 `_pending_trigger = idx`。
- `dialogue_finished`：`_pending_trigger` 对应 `_tr_finished[idx] = true`；三旗标齐且三段均播完 → `_start_ending()`。
- 旗标键：`c5_tr1_shown` / `c5_tr2_shown` / `c5_tr3_shown`（process_flags，随存档体系但不依赖存档）。

## 5. 结尾文字序列（EndingTextSequence.gd，extends CanvasLayer）

- 接口：`start(paths: Array[String])`、信号 `sequence_finished`。状态机用 Tween + await，不用 Timer 堆叠。
- 单文件流程：CenterContainer（全屏）+ VBoxContainer（`separation = 9`）逐行建 Label（白字、字号 18、
  水平居中、初始 alpha 0、mouse_filter=IGNORE）→ 逐行 Tween alpha 0→1（**1.0s/行**（2026-09-06 由 0.5s 调整），严格串行，亮起保持）→
  末行亮起后整体保持 **3.0s** → 全部行 **0.5s** 内一起淡出（parallel tween）→ queue_free → 下一文件。
- 第 7 个文件淡出后：`sequence_finished.emit()` → C5Floor `get_tree().quit()`。
- 文件顺序：`texts/1.txt` … `texts/7.txt`（D1）。空文件跳过；缺失 push_error + 跳过，不中断序列。
- 全程输入由 C5Floor 锁定；不做跳过/加速/回放。

## 6. C5Floor._start_ending()（防重入 `_ending_started`）

1. `StoryMonitor.lock_input()`；
2. BlackRect Tween `modulate:a` 0→1，**2.0s**；
3. `EndingTextSequence.start([1..7 路径])`；await `sequence_finished` → `get_tree().quit()`。

## 7. C5 入口（WorkScreen.gd）

- `LINK_TARGETS` 增加 `4: "res://scenes/c5_floor.tscn"`。
- `_update_work_button()`：`disabled = not LINK_TARGETS.has(MailWorkManager.get_work_version())`（解除 v4 禁用）。
- link4.txt 已存在且非空（"C5-回家 / 为每一处生长，找到它应在的位置"）。

## 8. 影响面与验收

只新增/改：c5_floor.tscn、C5Floor.gd、EndingTextSequence.gd、WorkScreen.gd（一处）、本文档。
不改：输入映射、其他场景/脚本。
验收：headless c5_floor 加载 0 报错；运行走查三触发区 → 渐黑 → 七段序列 → 自动退出；v4 按钮可用进 c5。
~~待办（补 C5.png 后）：背景贴图接线 + map_max_x 按实测宽度更新 + 触发区 x 按新宽度重排。~~ 已完成（2026-09-06）：纹理接线完成，map_max_x=3840 与触发区 960/1920/2880 实测均无需改动。
