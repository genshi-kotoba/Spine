# Spine

《C2-C5》——一栋长在自己身上的公寓。叙事驱动 · 轻交互 · 微解谜 · Godot 4 游戏项目（开发中）。

## 打开工程

- 需要 Godot 4.7+；
- 用编辑器打开 **`Spine/project.godot`**（工程在仓库的子目录 `Spine/`，仓库根 ≠ 工程根）。

## 目录与模块划分

```
Spine/
  scenes/            场景文件（main / main_scene / level_scene / player）
  scripts/
    autoload/        GameState（对象状态 + JSON 存档）、StoryMonitor（剧情触发 + 输入锁）
    objects/         InteractableObject 可交互对象基类（状态机）
    player/          Player（横版移动）
    scenes/          MainScene（固定镜头·点击）、LevelScene（卷轴 + 摄像机跟随）
    ui/              DialogueBox（逐句对话框）
  ui/                dialogue_box.tscn
```

## 协作规则

- 本地提交随时保存；**push / PR 须经确认通过**；
- 保持工作树整洁：不提交 `.godot/`、运行时数据与导出产物；
- 模块开发按上表划分，跨模块改动在 PR 说明里注明。

## 许可

待定。
