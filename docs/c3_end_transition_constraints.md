# C3 结局转场改造：约束文档

版本：v1.0（2026-09-06）
依据：docs/prompts/godot_c3end_c5_prompt.md 任务 A
关联：scripts/c3/flow/C3Flow.gd、scripts/autoload/MailWorkManager.gd、scripts/scenes/ComputerScreen.gd、scenes/computer_screen.tscn

## 1. 目标

EndItem 交互触发白屏后：2.0s 渐变纯白 → 写 `c3_end=1`（解锁 mail3/work3）→ 切 computer_screen（0.5s 白色淡入）。

## 2. 现状（已核实）

- 链路：BedroomEndItem.touched → `end_white_requested` → BedroomEnding._on_end_white（须 `_sequence_done`）→ `white_screen_end_requested` → C3Flow.on_white_screen_end()。
- 现实现：`_show_screen_overlay("white")`（WhiteScreen 直接 visible）+ `FLAG_END_WHITE` 置位，无渐变、无切场景。
- WhiteScreen：c3_level.tscn `OverlayLayer/WhiteScreen`（ColorRect 全屏、默认白色、visible=false、OverlayLayer layer=100）。
- texts/mail3.txt、work3.txt 已存在（真实文本）。

## 3. 白屏转场时序（C3Flow.on_white_screen_end 重写）

1. 防重入：成员布尔 `_end_transition_done`，已触发直接 return（整局一次；`_reset_flags` 中复位供自检）。
2. `StoryMonitor.lock_input()`。
3. `FLAG_END_WHITE` 置位（既有行为保留）。
4. WhiteScreen（white_screen_path）：`modulate.a = 0` → `visible = true` → Tween `modulate:a` 0→1，**2.0s**。
   节点缺失：push_error 并直接走第 5 步（不卡死）。
5. Tween 完成 → `GameState.set_object_state("c3_end", "1")` → `StoryMonitor.unlock_input()` →
   `get_tree().change_scene_to_file("res://scenes/computer_screen.tscn")`。

## 4. mail3/work3 解锁（MailWorkManager._recheck 加条件三）

- `GameState.get_object_state("c3_end") == "1"` → mails 追加 3、`target_work = max(target_work, 3)`。
- 与既有两条件同构；幂等、只升不降、无变化不写回。

## 5. computer_screen 白色淡入（0.5s，统一行为）

- 场景新增顶层 `FadeInLayer`（CanvasLayer，layer=110 高于 OverlayLayer/弹层）→ `FadeWhite`（ColorRect 全屏白、
  `mouse_filter=IGNORE(2)`、初始 `modulate.a=1`）。
- `ComputerScreen._ready()`：Tween FadeWhite alpha 1→0，**0.5s**，完成后 hide。
- **统一行为**：从任何入口（start_screen、C3 结局、C2 结局、链接序列）进入 computer_screen 都播放该淡入。
  与 start_screen 的黑色渐亮罩并存（先黑罩淡出、白罩同时在淡，视觉效果为统一的白淡入收尾）。

## 6. 影响面

只动：C3Flow.gd、MailWorkManager.gd、ComputerScreen.gd、computer_screen.tscn（均留 .bak）。
不改：c3_level.tscn（WhiteScreen 保持场景现状）、BedroomEnding、其他场景/脚本/输入映射。

## 7. 验收

- headless c3_level / computer_screen 0 报错。
- 运行：C3 卧室 EndItem → 锁输入 2s 渐白 → computer_screen 白淡入 → mailbox 见 mail3、work 显示 work3、按钮指向 c4_floor。
- 回归：c2/c4 解锁链与 R 调试键不变。
