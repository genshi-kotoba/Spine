# C3 卧室墙纸背景：约束文档

版本：v1.0（2026-09-06）
关联：scenes/c3_bedroom_room.tscn、scenes/c3_level.tscn、scripts/c3/bedroom/BedroomWallItem.gd

## 1. 目标

C3 卧室背景用真实墙纸贴图铺满，随墙 item（BedroomWallItem）交互推进切换：

- 进入卧室（墙 state=1，到达时墙纸已撕开一半）→ `wallpaper1.png`
- 玩家再交互 1 次（state=2）→ `wallpaper2.png`
- 再交互 1 次（state=3，封顶）→ `wallpaper3.png`

与既有「墙 E×3」流程完全同频，不新增交互次数、不改状态机。

## 2. 现状（已核实）

- 素材：`assets/sprites/wallpaper{1,2,3}.png`，均 **1280×853**。
- 房间：`c3_bedroom_room.tscn`（RoomBase 程序化白模），room_width=1280、wall_height=780、stand_surface_y=988。
  背墙可视区 = x∈[0,1280]、y∈[208,988]（天花底→地板顶），中心 (640, 598)。
- 墙 item：c3_level.tscn `Rooms/Bedroom/WallItem`（BedroomWallItem），state 0..3；
  `BedroomEnding.prime_arrival_reveal()` 到达即置 state=1，玩家只需再 E 两次到 3。
- 既有占位视觉（墙面色渐变红/橙/黄 Polygon2D）**保留不动**——本次只加背景层。

## 3. 方案

1. `c3_bedroom_room.tscn` 新增 `Wallpaper`（Sprite2D，room 根节点直接子节点）：
   - texture=wallpaper1.png（初始），position=(640,598)，原尺寸 1280×853 不缩放；
   - 上下溢出部分被 RoomBase 后添加的 Environment 天花/地板色块自然遮挡（同 z 后绘制者在上）。
2. `BedroomWallItem.gd` 新增可选墙纸联动（不影响无配置的旧用法）：
   - `@export var wallpaper_target: NodePath`、`@export var wallpaper_state_textures: Array[Texture2D]`（index=state）；
   - `apply_state()` 末尾：target 非空且 index 有效则换 `sprite.texture`。
3. `c3_level.tscn` WallItem 节点配置：
   - `wallpaper_target = NodePath("../Wallpaper")`；
   - `wallpaper_state_textures = [wp1, wp1, wp2, wp3]`（state0/1 同为 wallpaper1，与到达即撕开一半的语义一致）。

## 4. 影响面

只动：c3_bedroom_room.tscn、c3_level.tscn、BedroomWallItem.gd（均留 .bak）。
不改：BedroomEnding、C3Flow、RoomBase、输入映射、既有占位视觉。

## 5. 验收

- headless c3_level 加载 0 报错。
- 运行：进卧室背景=wallpaper1；墙 E 第 1 次→wallpaper2；第 2 次→wallpaper3；第 3 次（封顶）不再变。
