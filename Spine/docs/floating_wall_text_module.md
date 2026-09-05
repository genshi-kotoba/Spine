# 墙面悬浮文字模块

## 用途

`res://scenes/floating_wall_text.tscn` 是一个无外部资产、无全局单例依赖的 `Node2D` 模块，用于场景墙边的风格化悬浮文字。默认表现包含确定性错落排版、字号与倾斜差异、红黑错版阴影、轻微漂浮和高频小幅抖动。

## 接入

1. 把 `floating_wall_text.tscn` 实例化到任意 2D 场景。
2. 将节点位置放到目标墙面中心。
3. 在 Inspector 的 `Content` 中修改 `phrases`；在 `Layout` 中调整占用区域、字号和倾斜；在 `Motion` 中调整抖动与漂浮。
4. 流程需要控制显隐时调用 `set_revealed(visible, duration)`；运行时换文案可调用 `set_phrases(...)`。

模块的 `seed_value` 决定布局，保持同一个值即可稳定复现。文字过长时会自动缩小到配置的最小字号，避免越出各自排版单元。

## 验收

独立打开 `res://scenes/floating_wall_text_demo.tscn` 可查看最终表现。自动检查命令：

```bash
/Volumes/OmubotDisk/Godot/Godot.app/Contents/MacOS/Godot \
  --headless --path /Volumes/OmubotDisk/Godot/Spine/Spine \
  res://scenes/floating_wall_text_demo.tscn -- --self-check
```

检查覆盖文字数量、字号差异、动画位移和运行时文案重建。

## 回滚

删除以下新增文件即可完整回滚，不需要修改 `project.godot` 或存档数据：

- `scripts/components/FloatingWallText.gd`
- `scripts/scenes/FloatingWallTextDemo.gd`
- `scenes/floating_wall_text.tscn`
- `scenes/floating_wall_text_demo.tscn`
- `docs/floating_wall_text_module.md`
