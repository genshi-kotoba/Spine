# C4 结局白屏转场：约束文档

版本：v1.0（2026-09-06）
关联：scripts/scenes/C4Floor.gd、scenes/c4_floor.tscn、scripts/autoload/{DialogueManager,MailWorkManager}.gd、docs/c3_end_transition_constraints.md

## 1. 目标

c4_floor 中 12 个 waste 全部交互（消失）且**最后一段对话（c4_dialogue3）结束之后**：
画面 2.0s 渐变为纯白 → 切到 computer_screen；mailbox 与 work 进入第四阶段（载入 mail4.txt / work4.txt）。

## 2. 现状（已核实）

- `C4Floor._on_state_changed`：waste 消失计数，阈值 4/8/12 各播一段 MODE_INTERACTIVE 对话（texts→dialogues/c4_dialogue{1,2,3}.txt）。
- `DialogueManager.dialogue_finished` 信号存在（每段对话结束都发，不限 c4）。
- `MailWorkManager._recheck` 条件二：c4_waste1~12 全 "1" → 追加 mail4、work 版本 ≥4。**已存在，本次不改**。
- texts/mail4.txt、work4.txt 已存在（真实文本）。
- computer_screen 进入时统一播 0.5s 白色淡入（FadeWhite，c3_end §5）——**到达侧已就绪**。
- c4_floor.tscn **无**任何全屏遮罩层 → 需新增。
- work_screen `LINK_TARGETS[4] = c5_floor` 已接线（先前任务）。

## 3. 方案

### 3.1 c4_floor.tscn 新增白屏罩（仿 c3 WhiteScreen / c5 BlackRect 惯例）

- `EndingLayer`（CanvasLayer，layer=50）→ `WhiteScreen`（ColorRect 全屏 anchors_preset=15、
  白色、`modulate.a=0` 初始透明、`mouse_filter=IGNORE(2)` 红线⑦）。

### 3.2 C4Floor.gd 结局编排

- 新增成员：`_ending_pending: bool`（第 12 阈值对话已起）、`_end_done: bool`（防重入）。
- `_on_state_changed` 触发阈值 12 对话时：`_ending_pending = true`，并连接
  `DialogueManager.dialogue_finished → _on_dialogue_finished`（CONNECT_ONE_SHOT 语义手写：响应后立刻断开）。
- `_on_dialogue_finished`：非 `_ending_pending` 或 `_end_done` 直接 return（忽略其他对话的 finished）。
  否则进入转场：
  1. `_end_done = true`，断开信号。
  2. `StoryMonitor.lock_input()`。
  3. WhiteScreen `modulate.a=0 → visible=true`（初始 visible 保持 true 仅靠 alpha=0 亦可，取 c3 同款写法）→
     Tween `modulate:a` 0→1，**2.0s**。
  4. Tween 完成 → `StoryMonitor.unlock_input()` → `change_scene_to_file("res://scenes/computer_screen.tscn")`。
  5. WhiteScreen 节点缺失：push_error 后直接切场景（不卡死，同 c3 容错）。

### 3.3 解锁侧

零改动：12 waste 全 "1" 时 MailWorkManager 条件二已自动解锁 mail4/work4（到达 computer_screen 即生效）。

## 4. 影响面

只动：C4Floor.gd、c4_floor.tscn（均留 .bak）。
不改：MailWorkManager、DialogueManager、computer_screen、waste item、输入映射。

## 5. 验收

- headless c4_floor 加载 0 报错。
- 运行探针：置 12 waste 全 "1" 触发 dialogue3 → 模拟 dialogue_finished → WhiteScreen 渐白 → 场景切 computer_screen；
  mailbox 可见 mail4、work 显示 work4 且按钮指向 c5_floor。
