# Spine 框架约束文档（点击叙事解谜 Demo）

> 依据 `godot_game_prompt.md` 生成代码框架前的约束层。与 prompt 冲突处以本文档及《Spine-项目约束.md》为准。
> 本阶段**只搭框架**：所有类只含规定的接口/信号/空实现，不填充玩法内容、演示状态配置与贴图。

## 冲突裁决（prompt vs 项目约束 → 以项目约束为准）

| 冲突项 | prompt 要求 | 裁决结果 |
|---|---|---|
| .gd 存放位置 | 按模块分目录（autoload/ objects/ …） | 全部放 `scripts/` 下，按模块分子目录 |
| 文件命名 | snake_case（game_state.gd） | PascalCase（GameState.gd） |
| .tscn 存放位置 | player/、scenes/、ui/ 分散 | .tscn 统一放 `scenes/`；UI 场景放 `ui/` |
| 入口场景 | scenes/main_scene.tscn | `scenes/main.tscn` 仍为项目入口，作为场景跳转门面 |

## 目标文件清单（本阶段交付）

```
Spine/
├── project.godot                  # 追加 Autoload 注册 + 输入映射
├── scenes/
│   ├── main.tscn                  # 已存在，入口（Node2D，门面）
│   ├── main_scene.tscn            # 主场景：固定 Camera2D + 纯点击
│   ├── level_scene.tscn           # 关卡场景：跟随摄像机 + 按键交互
│   └── player.tscn                # 角色：CharacterBody2D
├── ui/
│   └── dialogue_box.tscn          # 对话框：CanvasLayer+Panel+RichTextLabel
└── scripts/
    ├── autoload/
    │   ├── GameState.gd           # Autoload，全局状态字典 + 存档
    │   └── StoryMonitor.gd        # Autoload，剧情触发 + 输入锁
    ├── objects/
    │   ├── InteractableObject.gd  # Area2D 基类，状态机
    │   ├── AnimatedObjectSample.gd   # 空示例子类（带动画钩子）
    │   └── StaticObjectSample.gd     # 空示例子类（静态贴图）
    ├── player/
    │   └── Player.gd
    ├── scenes/
    │   ├── MainScene.gd
    │   └── LevelScene.gd
    └── ui/
        └── DialogueBox.gd
```

## 接口契约（必须逐项实现，留空逻辑用 `pass` / TODO 注释）

### GameState（Autoload 名 `GameState`）
- 信号：`state_changed(object_id, new_state)`
- `var object_states: Dictionary`
- `func set_object_state(object_id: String, new_state: String) -> void`
- `func get_object_state(object_id: String) -> String`
- `func save_game() -> void`：JSON → `user://savegame.json`
- `func load_game() -> void`：启动读取；无存档用默认空字典

### StoryMonitor（Autoload 名 `StoryMonitor`）
- 信号：`story_triggered(story_id)`（预留）
- `var input_locked: bool`
- `var trigger_table: Array`（条件表，本阶段留空数组）
- `func lock_input() -> void` / `func unlock_input() -> void`
- `func _on_state_changed(object_id, new_state) -> void`（连接 GameState 信号，匹配逻辑留 TODO）

### InteractableObject（extends Area2D，class_name InteractableObject）
- `@export var object_id: String`
- `var states: Dictionary`（状态→配置映射，子类填充）
- `var current_state: String`
- `func apply_state(state: String) -> void`（size/position/纹理映射，留 TODO）
- `func change_state(new_state: String) -> void`（→ GameState → apply_state）
- `func interact() -> void`（外部触发入口，虚方法）
- `_on_input_event(...)`：点击触发（主场景用），先查 `StoryMonitor.input_locked`
- 预留 `AnimatedSprite2D` 引用与 `play_state_animation(state)` 虚方法

### Player（extends CharacterBody2D）
- `@export var move_speed: float`、`gravity` 用项目默认
- 仅左右移动（A/D、方向键）+ 重力；`_physics_process` 内实现

### MainScene / LevelScene
- MainScene：Camera2D 固定，不响应移动输入；输入处理先查输入锁
- LevelScene：`@export var map_min_x: float` / `map_max_x: float`；摄像机水平跟随 + clamp；E 键交互最近重叠对象

### DialogueBox（extends CanvasLayer）
- `func show_dialogue(lines: Array) -> void`
- 点击任意处下一句；播完隐藏并 `StoryMonitor.unlock_input()`

## 输入映射（project.godot）
- `move_left`（A, Left）、`move_right`（D, Right）、`interact`（E）

## 本阶段不做
- 演示状态配置、贴图资源、剧情条件表内容、动画内容、UI 美术
