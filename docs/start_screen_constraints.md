# start_screen 重构约束（v1.0，2026-09-06）

## 背景
用户指示重构开场场景，覆盖 scene1 prompt 的「标题 + 开始按钮 + 初始化存档」设计。

## 定案
1. 删除原全部子节点（Title 精灵、StartButton、InitButton 及其子节点）。
2. 不再使用 start_screen.png 贴图；场景为**纯黑背景**（ColorRect 垫底，mouse_filter=IGNORE 遵守展示 Control 约定）。
3. 保留 MainScene 基类所需的 Camera2D（960,620）。
4. 场景启动后等待 **2.0 秒**，自动切换到 `res://scenes/computer_screen.tscn`，无需任何输入。
5. StartButton.gd / InitButton.gd 脚本文件保留在库（不再被场景引用，同 SettingIcon 先例）；start_screen.png / start_button.png 素材保留。
6. 等待期间无输入处理需求（无可交互节点）。

## 回滚要点
`git checkout <上一提交> -- scenes/start_screen.tscn scripts/scenes/StartScreen.gd`

## 修订记录

- 2026-09-06 v1.1：切到 computer_screen 时加 0.5s 渐亮过场。实现：切场景前在 SceneTree root 挂持久 CanvasLayer(层 128)+全屏黑 ColorRect(mouse_filter=IGNORE)，切场景后 tween modulate.a 1→0 0.5s 并 queue_free。computer_screen 零改动，其他入口不受影响。
