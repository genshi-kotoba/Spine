# Godot 2D 点击叙事解谜游戏 — 代码框架生成 Prompt

> 将以下全文作为指令发送给目标 AI。

---

## 角色与任务

你是一名精通 Godot 4.x（GDScript）的游戏开发工程师。你将通过 **Godot MCP 工具**直接操作我的 Godot 工程，为我搭建一款 **2D 点击交互叙事解谜游戏** 的完整代码框架。

## 硬性约束（最高优先级）

1. **所有场景（.tscn）与脚本（.gd）文件的创建、修改，必须通过 Godot MCP 工具完成**，不要只输出代码文本让我手动粘贴。
2. **每生成一个 .tscn 或 .gd 文件，必须严格对照我提供的《约束文档》执行**，逐条核对后再写入；如约束文档与本 prompt 冲突，以约束文档为准。
3. 若约束文档缺失或某条要求不清晰，**先向我提问澄清，不要自行假设**。
4. 使用 Godot 4.x 语法（GDScript 2.0）。不使用任何第三方插件。
5. 每个文件生成后，用 MCP 读取验证写入成功且语法无误，再进入下一个文件。

## 游戏概述

2D 点击交互叙事解谜游戏。包含两类场景：
- **主场景（点击交互场景）**：摄像机固定，玩家只能通过点击与场景中的对象交互。
- **关卡场景（角色移动场景）**：玩家操控角色左右移动，走近可交互对象后按键触发交互。

## 技术架构要求

### 1. 全局状态管理 `GameState`（Autoload 单例）

- 文件：`autoload/game_state.gd`，注册为 Autoload，名称 `GameState`。
- 职责：以字典形式存储**所有可交互对象的全局状态**（key = 对象唯一 ID，value = 该对象状态机当前状态）。
- 必须实现：
  - `save_game()`：将全部状态序列化为 JSON 保存到 `user://savegame.json`。
  - `load_game()`：游戏启动时自动读取存档文件并恢复状态；存档不存在则使用默认初始状态。
  - `set_object_state(object_id: String, new_state: String)` 与 `get_object_state(object_id: String) -> String`。
  - 发出信号 `state_changed(object_id, new_state)`，供监控系统监听。

### 2. 可交互对象基类 `InteractableObject`

- 文件：`objects/interactable_object.gd`，继承 `Area2D`，所有可交互对象的场景与脚本都基于此基类。
- 每个对象内部维护一个**状态机**（可用字典 + 当前状态变量实现，状态集合在对象内枚举定义），其当前状态同步到 `GameState` 全局变量。
- 必须提供方法：
  - `apply_state(state)`：根据状态机当前状态，设置本对象的 **size、position、纹理图像**（纹理用状态→贴图路径的映射表配置）。
  - `change_state(new_state)`：切换状态机 → 更新 GameState → 调用 `apply_state` → 需要时播放对应动画。
- 状态变更来源有两种，都要支持：
  - **被点击**（监听自身 `input_event` 信号，主场景用）。
  - **被其他对象/角色调用**（公开 `interact()` 方法供外部触发，关卡场景用）。
- 部分对象需要动画：基类预留 `AnimatedSprite2D` 节点引用与 `play_state_animation(state)` 虚方法，子类按需覆写；无动画对象退化为静态贴图切换。

### 3. 主场景（固定摄像机 + 纯点击交互）

- 文件：`scenes/main_scene.tscn` + `scenes/main_scene.gd`。
- 摄像机 `Camera2D` 固定在预设位置，**不接受任何移动输入**。
- 玩家唯一交互方式：点击场景中的 `InteractableObject`，触发其状态机变更。

### 4. 关卡场景（角色移动 + 跟随摄像机 + 按键交互）

- 文件：`scenes/level_scene.tscn` + `scenes/level_scene.gd`、`player/player.tscn` + `player/player.gd`。
- **角色**：`CharacterBody2D`，仅支持左右移动（A/D 或方向键），带简单重力与地面碰撞。
- **跟随摄像机**：
  - 默认保持角色位于摄像机中心（仅水平方向跟随即可，垂直方向如设计需要可同样处理）。
  - 摄像机位置必须 **clamp 在关卡地图边界内**：当继续跟随会导致摄像机视野超出地图边缘时，摄像机停止移动，角色可以继续走出中心位置。
  - 地图边界以可配置变量（`map_min_x` / `map_max_x`）暴露，方便逐关调整。
- **按键交互**：角色进入某 `InteractableObject` 的检测范围（Area2D 重叠）时，按交互键（E）调用该对象的 `interact()` 改变其状态机；同一时间只交互最近/当前重叠的对象，UI 提示可选。

### 5. 剧情监控系统 `StoryMonitor`（Autoload 单例）

- 文件：`autoload/story_monitor.gd`，注册为 Autoload。
- 职责：监听 `GameState.state_changed` 信号；内部维护一张**触发条件表**（条件 = 一组对象状态组合，可在编辑器或脚本中配置），当全局状态满足某条件时触发对应剧情，每个剧情只触发一次。
- 剧情分两种类型，触发期间**玩家无法进行任何点击交互或角色操控**（全局输入锁定），剧情结束后恢复正常状态：
  - **类型一：演绎剧情（cutscene）**
    - 摄像机与相关对象按预设程序运动（用 `Tween` 或 `AnimationPlayer` 编排镜头移动与对象动作序列）。
    - 演绎脚本以数据化方式配置（步骤列表：目标节点、目标位置/状态、时长），便于逐条剧情填写。
  - **类型二：对话剧情（dialogue）**
    - 摄像机固定不动。
    - 画面下半部分弹出对话文本框（`CanvasLayer` + `Panel` + `Label`/`RichTextLabel`）。
    - 对话内容为一组按顺序排列的句子；**点击画面任意位置切换到下一句**；全部播完后关闭文本框，解除输入锁定。
- 提供 `lock_input()` / `unlock_input()`，主场景与关卡场景的输入处理都必须先检查该锁定状态。

## 交付物

按以下结构通过 MCP 在工程中创建全部文件（节点结构按职责合理搭建）：

```
project/
├── autoload/
│   ├── game_state.gd
│   └── story_monitor.gd
├── objects/
│   └── interactable_object.gd   # + 至少 2 个示例子类（一个带动画、一个不带）
├── player/
│   ├── player.tscn / player.gd
├── scenes/
│   ├── main_scene.tscn / main_scene.gd
│   └── level_scene.tscn / level_scene.gd
└── ui/
    └── dialogue_box.tscn / dialogue_box.gd
```

同时为每个示例对象写一段最小可运行的演示状态配置，保证打开工程即可运行验证：点击主场景对象能切换状态并刷新外观；关卡场景角色可移动、摄像机正确跟随并在地图边缘停住；靠近对象按 E 触发状态变化；满足预设条件时两种剧情各演示一次。

## 工作流程

1. 先向我确认：Godot 确切版本、《约束文档》是否已提供、存档字段是否有额外要求。
2. 按模块顺序逐个创建文件：GameState → InteractableObject → 主场景 → Player → 关卡场景 → StoryMonitor → 对话 UI → 示例剧情配置。
3. 每完成一个文件：用 MCP 读回校验 → 对照约束文档逐条自检 → 汇报「文件路径 + 关键接口 + 自检结果」。
4. 全部完成后，给出运行验证步骤清单，并列出需要我手动在编辑器里做的配置（如贴图资源导入、输入映射绑定）。
```
