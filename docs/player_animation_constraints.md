# Player 动画化约束文档

版本：v1.1（2026-09-06）
关联：scripts/player/Player.gd、scenes/player.tscn、assets/sprites/static.png

## 1. 目标

Player 视觉从白模 Polygon2D 迁移到 AnimatedSprite2D 帧动画。
本期只接入**一张帧** `assets/sprites/static.png`，动画基础设施（SpriteFrames）一次搭好，
后续效果（walk 循环、朝向翻转、状态切换等）另行约定，本期不实现。

## 2. 素材事实（已实测）

- 画布 1280×1280，RGBA。
- 角色非透明包围盒 (181,259)-(813,977)：宽 632、高 718，脚底 y=977，角色中心 x=497。
- 角色面朝**左**。

## 3. 场景结构变更（player.tscn）

- 删除 `Visual`（Polygon2D 白模）。
- 新增 `AnimatedSprite2D` 节点 + SpriteFrames sub_resource：
  - 动画名 `static`，单帧，loop=true，autoplay。
- 对齐参数（由 §2 实测值推导，可在编辑器微调）：
  - `scale = 0.5348` → 视觉高度 384px（v1.1：0.1337 × 4；碰撞盒 32×64 不变，仅为碰撞盒的 6 倍高）。
  - `position = (76.48, -148.23)` → 脚底对齐碰撞盒底边（局部 y=+32），角色中心对齐碰撞中心。
    推导：y = 32 − 337·s，x = 143·s（s 为 scale）。
- CollisionShape2D、Camera2D、motion_profile 均不动。

## 4. 明确不做（本期）

- 不做朝向翻转（素材面朝左，flip_h 逻辑待后续）。
- 不做移动/待机动画切换。
- 不改 Player.gd（纯场景层变更）。

## 5. 验证

- headless 加载含 Player 的场景 0 报错。
