# 存档系统重构（暂时废弃）+ 调试解锁键：约束文档

版本：v1.0（2026-09-06）
关联：scripts/autoload/GameState.gd、scripts/autoload/MailWorkManager.gd、scripts/scenes/ComputerScreen.gd

## 1. 用户规格

1. **暂时废弃存档系统**：游戏每次重新打开，所有状态机重置为初始状态。
2. **调试键 R**（仅 computer_screen 场景）：按下后将 mailbox 与 work 设为「第二状态」——
   即 work 版本 2（work2.txt / link2.txt）、邮件解锁 1+2（mail2.txt 可读），
   也就是解锁 C3 关卡的状态。

## 2. 设计决策

- **D1 不断代码，只加开关**：GameState 增加 `const SAVE_ENABLED := false`。
  false 时 `_ready` 不读档、退出时不写档；磁盘旧存档保留但完全被忽略。
  日后恢复存档只需改回 true。delete_save() 等接口原样保留。
- **D2 R 键不注册输入映射**：调试键用 `event.keycode == KEY_R` 直检，
  不污染 project.godot 输入集（遵循「新增输入映射需确认」惯例）。
  仅在 ComputerScreen._unhandled_input 生效；先查 StoryMonitor.input_locked（弹层开着不响应）。
- **D3 解锁走 MailWorkManager 新接口**：`debug_set_unlock(mails: Array[int], work_version: int)`，
  写 GameState 两个键 + 发 mails_changed / work_version_changed（弹层开着即时刷新）。
  写入触发的 _recheck 重入由既有幂等设计收敛（无新增不再写）。
- **D4 效果核对**：R 后 = desktop_mails_unlocked "1,2"、desktop_work_version "2"，
  mailbox 显示 mail1/mail2，work 载入 work2.txt，「工作」按钮走 link2.txt → c3_level。
  与 c2_curten 流程无关，不触碰其他状态键。

## 3. 改动清单

- `scripts/autoload/GameState.gd`：SAVE_ENABLED 门控 load/save（.bak）
- `scripts/autoload/MailWorkManager.gd`：+ debug_set_unlock()（.bak）
- `scripts/scenes/ComputerScreen.gd`：+ _unhandled_input R 键处理（.bak）
- 禁区：不改 project.godot 输入映射；不删 user://savegame.json；其他场景零改动。

## 4. 验收

- headless computer_screen 0 报错。
- headless 脚本直调 debug_set_unlock([1,2], 2) 后：get_unlocked_mails()==[1,2]、get_work_version()==2。
- 重开游戏状态全初始（读档被跳过）。
