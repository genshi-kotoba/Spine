class_name WasteItem
extends "res://scripts/objects/vanish_item.gd"
## WasteItem — c4_floor 楼层 12 个 waste 共用的通用脚本（docs/c4_waste_constraints.md §4.1）
## 行为全部继承 VanishItem（传递继承 item 基类）：
##   状态机 {0=在场, 1=已消失}；E 键 _try_touch() → set_state(1)；
##   apply_state(1) = 隐藏 + 关闭交互；state_id 非空时状态由 GameState 统一监控管理。
## 本类零额外逻辑；12 个实例仅靠场景配置的 state_id（c4_waste1..c4_waste12）区分。
