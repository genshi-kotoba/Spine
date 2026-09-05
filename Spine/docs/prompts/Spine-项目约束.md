# Spine 项目约束文档

> 本项目为 Godot 引擎小体量 2D 测试用 Demo。在任何代码文件产出前，须先阅读本约束。

## 基本信息

| 项 | 值 |
|---|---|
| 项目名 | Spine |
| 引擎 | Godot 4.7.2 (stable) |
| 类型 | 2D |
| 主语言 | GDScript |
| 渲染 | 2D 默认（Forward+，可按需改 Mobile/Compatibility） |
| 项目路径 | `C:\Users\31088\Desktop\翌光计划\Spine` |

## 目录结构约定

```
Spine/
├── project.godot      # 项目配置
├── scenes/            # 所有场景 (.tscn)
│   └── main.tscn      # 主场景，根节点 Node2D
├── scripts/           # 所有 GDScript (.gd)
├── assets/            # 美术资源
│   ├── sprites/
│   └── audio/
└── ui/                # UI 场景与资源
```

## 编码规范

- 语言：仅使用 GDScript，不引入 C#/C++。
- 命名：
  - 文件/类：PascalCase（如 `PlayerController.gd`）
  - 变量/函数：snake_case（如 `move_speed`）
  - 常量：SCREAMING_SNAKE_CASE（如 `MAX_HP`）
  - 私有成员：前缀 `_`（如 `_velocity`）
- 节点引用优先使用 `@onready var` + `%UniqueName` 或 `$Path`。
- 信号连接在代码中完成，避免编辑器硬连线（测试 Demo 除外）。
- 每文件顶部注释说明用途。

## 工作流约束

1. **文档先行**：产出任何代码文件前，先生成/更新对应 markdown 约束文档。
2. 小体量定位：控制资源与依赖，不引入大型插件。
3. 场景组织：主场景 `scenes/main.tscn` 为入口，功能拆分为子场景实例化。
