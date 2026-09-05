# C3 主场景视觉资产接入记录

## 范围

本轮将主场景改为下载目录最新的单张 C3 资产；不再拆分房间，不再叠加木门或分隔墙，不决定具体交互点位，不移动现有 `Items/*` Area2D。

## 坐标契约

- 世界地图仍为 `3840px`；单张底图覆盖完整横向范围。
- 下载源：`/Users/kragcola/Downloads/c3.png`，尺寸 `2172×724`。
- 裁切范围：`y=117..544`（含端点），输出 `assets/background/c3_main.png`，尺寸 `2172×428`；上下白边及边界抗锯齿行已去除。
- `RoomArtwork/Main` 居中于 `(1920,619.5)`，缩放覆盖游戏区 `3840×817`；纵向轻微拉伸以保持完整横向构图，底部显示资产自身深色边框。
- 仅保留地面、天花和左右边界碰撞；不再创建房间分隔墙、木门或对应视觉层。

## 交互绑定预备

`c3_floor.tscn` 保留单一 `InteractionAnchors/BindingSlots` 空节点，仅作为后续绑定入口；不包含 Area2D、碰撞、提示或状态逻辑。现有 `C3Level/Items` 路径和坐标保持原样，后续绑定由用户指定后再接入。

## 流程联动

`c3_level.tscn` 的 `wall_hide_paths` 仅保留 `WhiteModel/RoomArtwork`，光影阶段隐藏单张 C3 底图；恢复逻辑沿用已有路径恢复机制。

## 回滚

移除 `assets/background/c3_main.png`、`c3_floor.tscn` 的 `RoomArtwork` 与单一 `InteractionAnchors` 节点，并清空 `c3_level.tscn` 的 `wall_hide_paths`，即可恢复本轮视觉接入；不影响地面/边界碰撞和 item 状态机。旧拆分资产备份位于 `/tmp/c3_split_assets_backup/`。

## 验收命令

```sh
git diff --check
git status --short
```

本轮已用 Godot `4.7.2` 运行 editor 导入加载与 `res://scenes/c3_level.tscn -- --self-check`；两项均通过。未做人工画面截图验收。
