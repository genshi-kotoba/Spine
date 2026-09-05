---
name: godot-4-development
description: Godot Engine 4.x 全栈游戏开发技能（依据官方特性列表整理）。用于规划、搭建、编码、调试、优化并导出完整的 Godot 2D/3D 游戏项目，覆盖渲染器选择、2D/3D 图形与物理、GDScript/C# 脚本、着色器、音频、导入、输入、导航、网络、国际化、GUI、动画、文件格式、移动端/XR 与发布。遇到任务名称或描述匹配该技能时，先加载本技能再动手。
whenToUse: 当需要开发、修改或扩展 Godot 4 游戏项目，或需要编写 GDScript/C# 代码、搭建场景、实现玩法、UI、音效、动画、输入、网络、存档或导出游戏时。
---

# Godot 4 游戏开发技能

## 0. 技能来源与使用原则

- 本技能内容整理自 Godot 官方简体中文文档《特性列表》：<https://docs.godotengine.org/zh-cn/4.x/about/list_of_features.html>，并补充了实现这些特性所需的**节点 / 类 / API / 工作流**。
- 特性列表覆盖：平台、编辑器、渲染、2D 图形与工具与物理、3D 图形与工具与物理、着色器、脚本、音频、导入、输入、导航、网络、国际化、窗口与 OS、移动端、XR、GUI、动画、文件格式、杂项。
- 遇到本技能未展开的 API 细节时，查阅官方类参考：<https://docs.godotengine.org/zh-cn/4.x/classes/>；渲染器选择见 <https://docs.godotengine.org/zh-cn/4.x/tutorials/rendering/>；导出见 <https://docs.godotengine.org/zh-cn/4.x/tutorials/export/>。
- Godot 4 与 3.x 差异很大（渲染器、TileMap、GDScript 语法、Input 单例等），**不要**把 3.x 的代码或教程直接套用到 4.x。
- 开发流程总原则：**场景 = 节点树，玩法 = 脚本，资产 = 资源**。先用最小可玩原型验证核心玩法，再迭代内容与打磨。

## 1. Godot 核心概念（必须理解）

| 概念 | 说明 |
| --- | --- |
| 节点 (Node) | 场景树的基本元素，一切游戏对象都是节点（Node3D / Node2D / Control 三大体系） |
| 场景 (Scene) | 由节点组成的可复用、可嵌套的树；保存为 `.tscn`（文本）或 `.scn`（二进制）；文本格式对版本控制友好 |
| 资源 (Resource) | 可复用数据对象：Texture2D、Mesh、Material、AudioStream、Animation、Theme、Curve 等；由 `ResourceLoader.load()` 加载 |
| 信号 (Signal) | 节点间的发布/订阅通信机制，是解耦的核心 |
| 组 (Group) | 给节点打标签，通过 `get_tree().call_group()` 批量操作 |
| 主循环 | `SceneTree` 驱动 `_process()`（每帧）与 `_physics_process()`（固定步长，默认 60Hz） |
| 场景切换 | `get_tree().change_scene_to_file("res://scenes/level.tscn")` |

信号三种用法（推荐用 1）：
```gdscript
# 1) 声明并连接（推荐）
signal health_changed(new_health: int)
func _ready() -> void:
    health_changed.connect(_on_health_changed)
func _on_health_changed(value: int) -> void:
    print("HP = ", value)
# 2) 编辑器中在“节点”面板连接
# 3) 匿名 lambda（短逻辑时）
button.pressed.connect(func(): print("clicked"))
```

## 2. 标准项目结构

```
project.godot            # 项目配置文件（文本，含主场景、输入映射、渲染器、自动加载）
export_presets.cfg       # 导出预设（编辑器导出后生成）
icon.svg                 # 项目图标
assets/                  # 美术、音频、字体等原始素材
  images/  audio/  fonts/  models/  shaders/
scenes/                  # 场景文件 .tscn
scripts/                 # GDScript / C#
autoload/                # 单例脚本
src/ 或 addons/          # 插件
```

`project.godot` 关键区段示例：
```ini
config_version=5
[application]
config/name="My Game"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.4", "Forward Plus")

[autoload]
Game="*res://autoload/game.gd"        # 自动加载单例（带 * 表示单例模式）

[input]
move_left={ "deadzone": 0.5, "events": [Object(InputEventKey,"physical_keycode":65) ] }

[rendering]
renderer/rendering_method="forward_plus"   # forward_plus | mobile | gl_compatibility
renderer/rendering_method.mobile="mobile"
renderer/rendering_method.web="gl_compatibility"
```

## 3. 渲染器选择（开工前先定）

| 渲染器 | 后端 | 平台默认 | 用途 |
| --- | --- | --- | --- |
| Forward+ | Vulkan / Direct3D 12 / Metal（RenderingDevice） | 桌面 | 功能最全：集群光照、PCSS 阴影、VoxelGI/SDFGI、反射探针无数量上限、贴花 |
| Mobile | Vulkan / D3D12 / Metal | 移动 | 特性少但简单场景更快；每网格最多 8 个 omni/spot/area 灯、8 个反射探针、8 个贴花，可用烘焙光照突破限制 |
| Compatibility (GL) | OpenGL | Web | 最低级，适合低端设备与 Web；不支持 SDFGI 等高级特性 |

- 选型建议：桌面 3D → Forward+；移动/简单 3D → Mobile；Web/低端 → Compatibility；纯 2D → Mobile 或 Compatibility 均可（2D 功能无差异）。
- 特性列表中的渲染功能（PBR、GI、阴影、雾、后期、抗锯齿、分辨率缩放等）均与渲染器能力挂钩，导出目标平台受限时应先确认渲染器。
- `Forward+` 使用深度预渲染减少 overdraw；支持可变速率着色（VRS，Forward+/Mobile 的受支持 GPU）。

## 4. 各领域特性 → 实现速查

### 4.1 平台与导出
- 编辑器与导出：Windows（x86/ARM，64/32 位）、macOS（x86/ARM，仅 64 位）、Linux（x86/ARM 64/32 位；rv64/ppc64/ppc32/loongarch64 需自行编译）、Android（编辑器实验性）、Web（4.0 实验性）。
- 仅运行导出项目：iOS。
- C# 项目**无法导出 Web**（请用 GDScript 或 Godot 3）；Android/iOS 的 C# 自 4.2 起为实验性；iOS 仅 arm64。
- 命令行导出：`godot --headless --path . --export-release "Windows Desktop" build/game.exe`；可用 CI 平台自动导出部署。

### 4.2 编辑器能力（AI 常用）
- 场景树编辑器、内置脚本编辑器（支持外部编辑器：VSCode、Vim）、GDScript 调试器（含多线程调试）、可视化性能分析器（CPU/GPU 各阶段耗时）、性能监视器（可加自定义监视器）、Tracy/Perfetto 追踪分析器。
- 脚本热重载、场景热编辑（改动即时反映到运行中的项目）；运行多个项目实例（客户端/服务器测试）；内嵌游戏面板。
- 2D/3D 选择节点后可在运行项目中检查（远程检查器）；标尺工具测距；3D 顶点吸附；“Focus Selection”两次跟踪选中对象。
- 内置离线类参考；多语言编辑器；插件（资产库下载或用 GDScript 自写）；项目管理器可导入资产库项目。
- AI 注意：项目多数操作可纯命令行完成（`godot --headless --path . --quit-after N` 等），但**烘焙光照贴图、生成导航网格、导入资源**等编辑器操作需要编辑器或 `--import` 步骤。

### 4.3 2D 图形与工具
- 精灵/多边形/线条：`Sprite2D`、`Polygon2D`、`Line2D`（支持纹理）；动画精灵 `AnimatedSprite2D`（配 `SpriteFrames`）。
- 视差：`Parallax2D` + `ParallaxLayer`（编辑器可预览的伪 3D 效果）。
- 2D 光照：`PointLight2D`/`DirectionalLight2D`（点光源支持全向/聚光、硬/软阴影逐光调节）；配合法线/镜面贴图；`LightOccluder2D` + `OccluderPolygon2D` 生成实时 SDF 遮挡，可用于 2D 全局光。
- 字体：位图字体（BMFont 导出或从图像导入，仅等宽）；动态字体 TTF/OTF/WOFF1/WOFF2（FreeType 或 MSDF 多通道 SDF 光栅化），支持彩色字体/表情、轮廓、可变字体与 OpenType 连字、模拟粗斜体、超采样、亚像素定位、LCD 优化；SDF 字体可任意分辨率缩放。
- SVG：`DPITexture` 导入类型 + Oversampling，运行时重光栅化更清晰；`CanvasItem` 过采样可按节点缩放提升清晰度。
- 粒子：`GPUParticles2D`（GPU，支持自定义粒子着色器）与 `CPUParticles2D`；可选 2D HDR 渲染增强辉光；debanding 减少色带；HDR 输出（受平台/渲染器支持）。
- TileMap：`TileMapLayer`（4.3+ 推荐）或 `TileMap`，配 `TileSet` 做 2D 图块关卡。
- 相机：`Camera2D`，内置平滑（`position_smoothing_enabled`）与拖动边距（`drag_margin_*`）。
- 路径：`Path2D`（编辑器绘制或程序生成）+ `PathFollow2D`（沿路径移动节点）。
- 几何辅助：`Geometry2D`（相交、裁剪、凸包等）。

### 4.4 2D 物理
- 物理体：`StaticBody2D`（静态）、`AnimatableBody2D`（仅脚本/动画移动，如门、平台）、`RigidBody2D`（刚体）、`CharacterBody2D`（角色）、关节 `Joint2D`（`PinJoint2D`、`GrooveJoint2D`、`DampedSpringJoint2D`）、`Area2D`（区域，检测进入/离开）。
- 物理插值：项目设置 `physics/common/physics_interpolation=true`（平滑移动，尤其适合高刷新率）。
- 碰撞：内置形状（线段、盒、圆、胶囊、世界边界无限平面）→ `CollisionShape2D`；`CollisionPolygon2D` 可手绘或从精灵自动生成。
- 层与掩码：`collision_layer` / `collision_mask`（32 位位掩码）决定谁与谁碰撞/检测；`Area2D` 的 `body_entered` / `area_entered` 信号做触发、拾取、伤害判定。

### 4.5 3D 图形
- 光照模型：线性 HDR 内部光照、debanding、HDR 输出；PBR 遵循迪士尼模型：Burley/Lambert/Lambert Wrap(half-Lambert)/Toon 漫反射；Schlick-GGX/Toon/Disabled 高光；粗糙度-金属度工作流（ORM 纹理）；地平线高光遮蔽（Filament）；法线贴图；视差/浮雕贴图（距离自动 LOD）；细节贴图；次表面散射与透射；屏幕空间折射（按粗糙度模糊）；近/远渐隐（透明度混合或抖动）。
- 灯光：`DirectionalLight3D`（日月）、`OmniLight3D`、`SpotLight3D`（锥角/衰减可调）、`AreaLight3D`（矩形区域光，可带纹理）；逐灯调节高光/间接光/体积雾能量；灯光“尺寸”影响阴影半影；距离淡化系统提性能；Forward+ 下集群前向渲染，光源数量无上限。
- 阴影：Directional 正交（最快）/PSSM 2/4 分段（可混合）；Omni 双抛物面（快）/立方体贴图（准）；Spot 单纹理；支持彩色投影纹理；法线偏移与阴影压平缓解失真/悬浮；类 PCSS 阴影模糊。
- 全局光照：
  - `LightmapGI`：烘焙光照贴图（GPU 计算着色器烘焙，快；仅编辑器可烘焙，运行时不可更新；支持只烘焙间接光、混合烘焙、探针照明动态物体、球谐定向光、shadowmask、烘焙超采样、JNLM 内置去噪或 OIDN 高质量去噪、双三次过滤）。
  - `VoxelGI`：体素 GI 探针，支持动态光**和**动态遮挡物、反射；需快速烘焙（编辑器或运行时含导出项目均可）。
  - `SDFGI`：有符号距离场 GI，为大型开放世界设计，支持动态光（不支持动态遮挡物）、反射，无需烘焙。
  - `SSIL`：屏幕空间间接光照，全实时，支持任意自发光（含贴花）。
  - VoxelGI/SDFGI 可半分辨率渲染 GI 以提高性能（兼容 MSAA）。
- 反射：体素反射、SDF 反射、`ReflectionProbe`（快烘焙或慢实时，可开视差盒校正）、屏幕空间反射（按材质粗糙度）；可混用反射技术。
- 贴花：`Decal`，支持反照率/自发光/ORM/法线；纹理通道平滑叠加；法线淡化；无需实时网格生成，可在蒙皮网格上使用；距离淡化提性能。
- 天空：`Sky`（HDRI 全景；程序/物理天空响应定向光；自定义天空着色器可动画；环境光/镜面辐射图可实时更新）。
- 雾：指数深度雾、指数高度雾（`Environment` 中配置）、大气透视自动匹配天空色、太阳散射、雾对天空影响控制、材质忽略雾。
- 体积雾：全局体积雾（对光影反应；VoxelGI/SDFGI 时受间接光影响）；`FogVolume` 节点加/减雾（盒/椭圆/圆锥/圆柱/3D 纹理密度图），每体积可自定义着色器。
- 粒子：`GPUParticles3D`（子发射器、尾迹、吸引器（仅 3D：盒/球/向量场）、碰撞（盒/球/烘焙 SDF/实时高度图））；`CPUParticles3D`。
- 后期（`WorldEnvironment` + `Environment`）：色调映射（Linear/Reinhard/Filmic/ACES/AgX）、自动曝光（视口亮度）或手动、景深（盒/六边形/圆形散景）、SSAO（半/全分辨率）、辉光（双三次放大；Screen/Soft Light/Add/Replace/Mix 混合；污渍贴图；可当屏幕空间模糊）、颜色校正（1D 渐变或 3D LUT）、粗糙度限幅器、亮度/对比度/饱和度。
- 纹理过滤：最近邻/双线性/三线性/各向异性（按用途而非按纹理定义）。VRAM 压缩：BPTC（桌面高质量）、ASTC（移动高质量）、ETC2（移动快速）、S3TC（桌面快速）、Basis Universal（一次编码全平台）。
- 抗锯齿：TAA、FSR2.2（原生分辨率高质量时间 AA）、MSAA（2D/3D）、FXAA、SSAA（双线性放大 + 3D 分辨率比例 >1.0）、逐材质 Alpha AA（Alpha-to-Coverage / Alpha 哈希）。
- 分辨率缩放：低分辨率渲染 3D 同时保持 2D 原始比例；最近邻/双线性/FSR1/FSR2.2.1；mipmap LOD 偏置自动调整（可手动）。
- 相机：`Camera3D` 透视/正交/视锥偏移；多相机渲染到 `SubViewport`。

### 4.6 3D 工具与物理
- 内置网格：立方体、圆柱/圆锥、（半）球、棱柱、平面、四边形、圆环、条带、管状（`MeshInstance3D` + `BoxMesh` 等）。
- `GridMap`（3D 图块关卡）、CSG（`CSGBox3D` 等，原型用）、程序式几何（`SurfaceTool`、`ArrayMesh`、`ImmediateMesh`）、`Path3D` + `PathFollow3D`、`Geometry3D`。
- 场景导出 glTF 2.0（编辑器或运行时均可）。
- 物理体：`StaticBody3D`、`AnimatableBody3D`、`RigidBody3D`、`CharacterBody3D`、`VehicleBody3D`（街机车辆，非真实模拟）、关节 `Joint3D`（Pin/D6/ConeTwist/Generic6DOF/Hinge/Slider）、`SoftBody`（软体）、布娃娃（多 `PhysicalBone3D` + 关节）、`Area3D`；物理插值同 2D。
- 碰撞形状：盒/球/胶囊/圆柱/世界边界；编辑器可从任意网格生成三角形碰撞形状（trimesh）或一个/多个凸碰撞形状（convex）。
- 位掩码与 2D 相同：`collision_layer` / `collision_mask`。

### 4.7 着色器
- 语言：GLSL 启发的 Godot 着色器语言（`.gdshader`）；类型：`shader_type canvas_item`（2D：顶点/片段/光照）、`shader_type spatial`（3D：顶点/片段/光照/天空/雾）、`shader_type particles`（粒子）、`shader_type sky`、`shader_type fog`。
- 2D 可写自定义顶点/片段/灯光着色器；3D 可写自定义顶点/片段/灯光/天空/雾着色器。
- `DrawableTexture2D` 可让自定义着色器实时程序化生成/修改纹理。
- 可视化着色器编辑器 + 可视化着色器插件；GitHub 上 gdshader 代码块高亮。
- 简单示例（2D 变色精灵）：
```gdscript
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() { COLOR = texture(TEXTURE, UV) * tint; }
```

### 4.8 脚本
- 通用：脚本扩展节点的 OOP 设计；信号与组通信；跨语言脚本（GDScript ↔ C#）；2D/3D/4D 线性代数类型（Vector2/3/4、Transform2D/3D、Quaternion、Basis）。
- **GDScript**：高级解释型语言，可选静态类型，语法受 Python 启发但**不是** Python；支持线程（`Thread`、`Semaphore`、`Mutex`）。
- **C#**：单一二进制（体积小、依赖少）；.NET 8+；完整 C# 12；支持 Windows/Linux/macOS；Android/iOS 实验性（4.2+，iOS 仅 arm64）；**不支持 Web**；建议外部 IDE。
- **GDExtension**（C/C++/Rust/D 等）：按需链接本机库；官方 C/C++ 绑定；社区 D/Swift/Rust 绑定；游戏逻辑优先 GDScript 或 C#。
- GDScript 常用语法：
```gdscript
extends CharacterBody2D
class_name Player            # 全局可引用类型名

@export var speed := 200.0   # 编辑器可见导出变量
@onready var sprite := $Sprite2D   # 场景就绪后取节点
var hp := 100
const MAX_HP := 100
enum State { IDLE, RUN }

func _ready() -> void:
    add_to_group("players")
    print("Hello, %s!" % name)

func _physics_process(delta: float) -> void:
    var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = dir * speed
    move_and_slide()

func _process(delta: float) -> void:
    pass

func take_damage(amount: int) -> void:
    hp -= amount
    if hp <= 0: queue_free()   # 安全删除节点
```

### 4.9 音频
- 输出：单声道/立体声/5.1/7.1；2D/3D 定位与非定位播放（`AudioStreamPlayer` / `AudioStreamPlayer2D` / `AudioStreamPlayer3D`）；2D/3D 多普勒。
- 音频总线：可重路由的 `AudioBusLayout` + 数十种效果（`AudioEffectReverb`、`AudioEffectEQ`、`AudioEffectCompressor`、`AudioEffectLimiter`、`AudioEffectDistortion`、`AudioEffectDelay`、`AudioEffectPitchShift`、`AudioEffectChorus` 等），在“音频”面板编辑。
- 复音（单节点同时播放多音，`max_polyphony`）、随机音量/音高、实时音高缩放、顺序/随机采样（`AudioStreamRandomizer`，随机可防重复）。
- `AudioListener2D` / `AudioListener3D` 从相机之外的位置收听；程序式音频（`AudioStreamGenerator` + `AudioStreamGeneratorPlayback`）；麦克风录音（`AudioStreamMicrophone`）；文本转语音（`DisplayServer.tts_*`，平台引擎）；MIDI 输入（`MidiMessage`，无输出）。
- 后端 API：Windows WASAPI、macOS CoreAudio、Linux PulseAudio 或 ALSA。

### 4.10 导入
- 自定义导入插件（`EditorImportPlugin`）。
- 图片：见《导入图像》（PNG/JPG/WebP/SVG 等，带压缩与 mipmap 设置）。
- 音频：WAV（可选 QOA 或 IMA-ADPCM 压缩）、Ogg Vorbis、MP3。
- 3D 场景：**glTF 2.0（推荐）**；`.blend`（透明调用 Blender 的 glTF 导出）；FBX（透明调用 FBX2glTF）；Collada `.dae`；Wavefront OBJ（仅静态）。运行时与导出项目也可加载 glTF 2.0。
- 导入时用 Mikktspace 生成切线，保证与 Blender 等一致。
- 导入设置位于资源导入面板（`Import` 标签）；重新导入：`godot --headless --path . --import`。

### 4.11 输入
- `InputMap` 输入映射系统：硬编码输入事件或可重映射输入动作；轴值可映射到两个动作并配置死区；同一套代码支持键盘与手柄。
- 键盘：物理按键模式（`physical_keycode`）布局无关；鼠标：光标可见/隐藏/捕获/限制，自定义或系统光标，捕获时 Windows/Linux 用原始输入绕过系统加速；游戏手柄：最多 8 个，支持 LED 颜色、运动传感器（陀螺仪瞄准）；数位板/笔：压力与倾斜。
- 推荐 API：`Input.is_action_pressed("jump")`、`Input.get_vector(...)`、`_input(event)` / `_unhandled_input(event)`、`InputEventKey/MouseButton/JoypadMotion`。
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        print("点击于 ", event.position)
```

### 4.12 导航
- `AStar2D` / `AStar3D`（2D/3D A* 算法，程序式寻路）。
- `NavigationRegion2D` / `NavigationRegion3D`：导航网格，编辑器或运行时（含导出项目）烘焙生成；支持动态避障。
- `NavigationAgent2D` / `NavigationAgent3D`：给目标位置，自动沿网格寻路并输出速度；配合 `NavigationObstacle2D/3D` 做动态避障。
```gdscript
# NavigationAgent2D 用法
@onready var agent: NavigationAgent2D = $NavigationAgent2D
func _ready() -> void:
    agent.target_position = some_global_pos
func _physics_process(delta: float) -> void:
    velocity = global_position.direction_to(agent.get_next_path_position()) * speed
    move_and_slide()
```

### 4.13 网络
- 低阶：`StreamPeer` + `TCPServer`（TCP）；`PacketPeer` + `UDPServer`（UDP）；`HTTPClient`（低阶 HTTP）；`HTTPRequest`（高阶，用信号 `request_completed`）；开箱即用 HTTPS（捆绑证书）。
- 高阶多人：UDP + **ENet**（`ENetMultiplayerPeer`）或 WebSocket（`WebSocketMultiplayerPeer`）的多人 API；`multiplayer.peer`、`@rpc` 注解 + `rpc_id()` 远程调用自动复制；支持不可靠/可靠/有序传输；`MultiplayerSpawner` / `MultiplayerSynchronizer` 简化复制；`UPnP` 免端口转发。
```gdscript
# 主机
var peer := ENetMultiplayerPeer.new()
peer.create_server(port)
multiplayer.multiplayer_peer = peer
multiplayer.peer_connected.connect(func(id): print("玩家加入 ", id))
# 客户端
var peer := ENetMultiplayerPeer.new()
peer.create_client("127.0.0.1", port)
multiplayer.multiplayer_peer = peer
# RPC
@rpc("any_peer", "call_local")
func fire(): ...
rpc("fire")
```
- WebSocket 客户端与服务器全平台可用；WebRTC 客户端与服务器全平台可用。

### 4.14 国际化
- 完全 Unicode（含表情）；仅 Windows/macOS/Linux 支持加载系统字体，默认作为后备字体显示未支持字符（无需打包大字体）。
- 字符串存 CSV 或 gettext（`.po`），编辑器可生成 POT/PO；GUI 自动用翻译，代码用 `tr("KEY")`；支持复数形式与翻译上下文；双向排版、文本整形、OpenType 本地化形式；RTL 地区自动 UI 镜像；伪本地化测试。
- 实现：`Translation` 资源 + `TranslationServer`；`ProjectSettings` 的 `locale/translations`；`tr()` 全项目可用。

### 4.15 窗口与 OS 整合
- 单进程多独立窗口（`Window` 节点或 `DisplayServer`）；移动/缩放/最小化/最大化；标题与图标；透明叠加窗口 + 多边形鼠标穿透（`window/mouse_passthrough_polygon`）；吸引注意（标题栏闪烁）。
- 全屏（Windows 默认无边框全屏快速切换，可选独占全屏减输入延迟）；无边框；置顶；忽略焦点；弹出/独占窗口；原生文件对话框（Win/macOS/Linux/Android）；托盘图标（Win/macOS）；macOS 全局菜单与客户端装饰（CSD）。
- `OS.execute()` 阻塞/非阻塞执行命令（含运行多个项目实例）；协议处理程序打开文件/URL；自定义命令行参数（`OS.get_cmdline_user_args()`）；屏幕阅读器（Win/macOS/Linux）。
- `--headless` 无头服务器模式（无 GPU/显示服务器也可运行）；`--write-movie` 录屏。

### 4.16 移动端与 XR
- 触控：`TouchScreenButton`（虚拟摇杆/按钮）；Android/iOS 应用内购（`InAppStore` 插件）；第三方模块广告；Android 画中画。
- XR：开箱即用 **OpenXR**；桌面 VR 头显（Valve Index、WMR、Quest via Link）；通过插件支持 Android 头显（Meta Quest 1/2/3/Pro、Pico 4、Magic Leap 2、Lynx R1）；Apple visionOS 有限支持（仅平面应用，无沉浸式）；`XROrigin3D` + `XRCamera3D` 场景结构。

### 4.17 GUI 系统
- 一切控件继承 `Control`；编辑器 UI 本身也是 Control 节点。
- 常用控件：`Button`、`CheckBox`、`CheckButton`、`RadioButton`、`LineEdit`（单行）、`TextEdit`（多行）、`CodeEdit`（语法高亮/行号）、`PopupMenu` / `OptionButton`（可选搜索栏）、`ScrollBar`、`Label`、`RichTextLabel`（BBCode 富文本 + 动画）、`Tree`（也可做表格）、`ColorPicker`（RGB/HSV/OKHSL + 调色板）、`ProgressBar`、`TextureRect`、`PanelContainer`。
- 控件可旋转/缩放（`rotation`、`scale`）；拖放支持（`_get_drag_data` / `_can_drop_data` / `_drop_data`）。
- 布局：锚点（`Anchor`）贴角落/边缘/中心；容器 `Container` 自动布局：`VBoxContainer`/`HBoxContainer`（堆叠）、`GridContainer`（网格）、`FlowContainer`（流式折行）、`MarginContainer`（边距）、`CenterContainer`（居中）、`AspectRatioContainer`（纵横比）、`SplitContainer`（可拖拽分割器）、`TabContainer`、`ScrollContainer`、折叠区块（`CollapsibleContainer`，4.x 新）。
- 分辨率适配：`canvas_items` 或 `viewport` 拉伸模式（`display/window/stretch/mode`）+ `expand` 纵横比；用锚点/容器适配任意分辨率。
- 主题：内置主题编辑器；`Theme` 资源；`StyleBoxFlat`（向量程序式：圆角/斜角/阴影/边框/抗锯齿）与 `StyleBoxTexture`（纹理式）；`Control.theme` 或全局主题。
- 输入回调：`_gui_input(event)`、`focus`/`grab_focus()`；信号 `pressed`、`text_changed`、`item_selected` 等。

### 4.18 动画
- `AnimationPlayer`：动画化任意属性（可自定义插值）；轨道可调用方法、播放声音、用贝塞尔曲线。
- `AnimationTree`：混合树（状态机 `AnimationNodeStateMachine`、混合 `BlendSpace2D/3D`、`OneShot`、`TimeScale` 等）。
- 骨骼：`Skeleton2D`/`Skeleton3D` + 正/逆向运动学（`IK` 约束或 `InverseKinematics` 节点）；布娃娃。
- 简易补间（不用动画播放器）：`create_tween()`：
```gdscript
var tween := create_tween()
tween.tween_property(sprite, "position", Vector2(100, 0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
tween.tween_callback(func(): print("完成"))
```

### 4.19 文件与序列化
- 场景/资源：文本（可读、版本控制友好）或二进制（大场景更快）。
- `FileAccess` 读写文本/二进制（可选压缩或加密）；`JSON`（`JSON.parse_string` / `JSON.stringify`）；`ConfigFile`（INI 风格）；`XMLParser`；任何 Godot 数据类型可（反）序列化（含 Vector2/3、Color）。
- 导出项目中无需导入系统即可加载/保存图像、音频/视频、字体与 ZIP（`Image.load_from_file`、`AudioStreamWAV.load_from_file`、`ZIPReader`/`ZIPPacker`）。
- 打包：PCK（快速搜索优化的自定义格式）、ZIP 或直接打进可执行文件（单文件分发）；额外 PCK 支持 mod/DLC（`ProjectSettings` 的 `pck` 命令行参数加载）。
```gdscript
# 存档示例（ConfigFile）
var cfg := ConfigFile.new()
cfg.set_value("player", "hp", 100)
cfg.save("user://save.cfg")
var cfg2 := ConfigFile.new()
cfg2.load("user://save.cfg")
print(cfg2.get_value("player", "hp", 0))
```

### 4.20 杂项能力
- 视频播放：Ogg Theora（`VideoStreamPlayer`）；Movie Maker 模式（`--write-movie out.avi`，同步音频、完美帧同步）。
- 低层服务器访问：`DisplayServer`、`RenderingServer`、`PhysicsServer3D/2D`、`AudioServer` 等，可绕过场景树开销。
- 命令行自动化、CI 导出部署、Bash/zsh/fish 补全脚本；`print_rich("[color=red]文本[/color]")` 彩色输出。
- 编辑器可检测项目使用的功能并生成编译配置 → 更小的自定义导出模板；C++ 模块可静态链接（引擎 C++17，GCC/Clang/MSVC/MinGW 编译，MIT 许可，可复现构建）。

## 5. 完整开发工作流（AI 自主开发）

### 阶段 0：设计决策
1. 明确：游戏类型、核心玩法循环、目标平台、视角（2D/3D）、美术风格、单机/联机。
2. 据此确定渲染器（见 §3）、输入方案、UI 布局策略。
3. 列出最小可玩原型（MVP）范围：一个可玩关卡 + 核心机制 + 胜负条件。

### 阶段 1：项目脚手架
1. 创建目录结构与 `project.godot`（主场景、渲染器、窗口尺寸、输入映射、自动加载单例）。
2. 创建自动加载单例（如 `Game`、`Audio`、`Save`），存放全局状态与服务。
3. 创建主场景 `main.tscn`（可先用脚本生成或手写 tscn，或用 `PackedScene` 节点从零构建）。
4. 确保 `godot --headless --path . --quit` 能无错误启动。

### 阶段 2：核心玩法原型
1. 玩家角色：`CharacterBody2D/3D` + 移动脚本（`Input.get_vector` + `move_and_slide` / `move_and_slide()`）+ 相机跟随。
2. 关卡搭建：`TileMapLayer`/`GridMap`/`StaticBody*` + `CollisionShape*`。
3. 交互：`Area*` 触发（拾取、伤害区、检查点）；信号连接。
4. 敌人/AI：`CharacterBody*` + `NavigationAgent*` 或状态机（`match` 或 `AnimationTree` 状态机）。
5. 游戏流程：生成（`Timer` + 随机位置）、死亡/重生（`queue_free` / `get_tree().reload_current_scene`）、得分/血量 UI。

### 阶段 3：内容实现
- UI（`CanvasLayer` + Control）：主菜单、HUD、暂停、设置（音量/画质/键位重映射）、结算界面；`get_tree().paused` + 处理节点 `process_mode`。
- 音频：背景音乐（`AudioStreamPlayer`，总线“Music”）、音效（总线“SFX”）、`AudioStreamRandomizer` 变化。
- 动画：`AnimationPlayer`（UI/场景/角色动作）、`Tween`（程序式动效）、粒子（死亡/命中/环境）。
- 存档：`ConfigFile`/`JSON` 到 `user://`；设置持久化。
- 网络（如联机）：`MultiplayerSpawner/Synchronizer` + `@rpc`（见 §4.13）。
- 国际化：所有用户可见文本走 `tr()` + CSV/PO 翻译。

### 阶段 4：打磨与性能
- 世界环境：`WorldEnvironment`（雾、辉光、SSAO、色调映射、体积雾）。
- 性能：合并静态网格、`LightmapGI`/`VoxelGI` 烘焙、粒子数量、`remote transform`、LOD、`Profiler` 检查 CPU/GPU 热点。
- 输入细节：手柄支持、死区、UI 导航（`focus_neighbor_*`）、触屏虚拟按键。

### 阶段 5：测试与调试
- `godot --path . --debug` 或直接运行；用 `print()`、`print_rich()`、`push_error()` 诊断。
- 远程调试：从编辑器运行项目 + 远程检查器（改动不回写，仅查看）；热重载/热编辑用于迭代。
- 常见错误与修法：
  | 症状 | 原因/修法 |
  | --- | --- |
  | 空引用崩溃 | 节点路径写错；`@onready` 引用不存在的节点；改用 `get_node_or_null()` 或 `is_instance_valid()` |
  | 无碰撞/穿透 | `collision_layer/mask` 位不匹配；子级 CollisionShape 未启用；物理体类型选错 |
  | 信号不触发 | 未 `connect`；在 `_ready` 前发射；对象已释放（自动断开需 `CONNECT_REFERENCE_COUNTED` 或绑定） |
  | 场景切换报错 | 路径写错（`res://` 开头、.tscn 后缀）；场景未保存 |
  | 导入后黑屏/紫 | 资源未导入（跑一次 `--import`）；渲染器不支持的功能（如 Web 用 Forward+） |
  | C# 无法导出 Web | Godot 4 限制，改 GDScript 或用 3.x |
  | 手柄无反应 | InputMap 未映射；死区太大 |

### 阶段 6：导出与发布
1. `项目 → 导出` 创建预设，或手写 `export_presets.cfg`；配置图标、包名、权限、架构。
2. 命令行：`godot --headless --path . --export-release "Windows Desktop" build/game.exe`（先确保导入完成：`godot --headless --path . --import`）。
3. Web：`--export-release "Web" build/index.html`（注意 C# 不支持）。
4. 内容更新：额外 PCK 支持 mod/DLC；`--main-pack` 指定 PCK。
5. CI：GitHub Actions 等跑上述命令自动出包。

## 6. 速查：常见节点选型表

| 需求 | 用这个 |
| --- | --- |
| 2D 角色控制 | `CharacterBody2D` + `move_and_slide()` |
| 3D 角色控制 | `CharacterBody3D`（+ `move_and_slide()`，含坡度/墙检测） |
| 刚体物理 | `RigidBody2D/3D` + `_integrate_forces` |
| 触发器/拾取/伤害区 | `Area2D/3D`（`body_entered` 信号） |
| 2D 关卡 | `TileMapLayer` + `TileSet`（4.3+） |
| 3D 关卡 | `GridMap` 或 CSG 或 `MultiMeshInstance3D` |
| 跟随路径移动 | `Path2D/3D` + `PathFollow2D/3D` |
| 寻路 | `NavigationRegion*` + `NavigationAgent*`（或 `AStar*` 纯逻辑） |
| UI 布局 | 容器 + 锚点，勿用绝对坐标 |
| 对话/日志 | `RichTextLabel`（BBCode） |
| 动画状态机 | `AnimationTree` + `AnimationNodeStateMachine` |
| 程序动画 | `Tween`（`create_tween()`） |
| 全局音效总线 | `AudioBusLayout` + `AudioStreamPlayer*` |
| 全局状态 | 自动加载单例（autoload） |
| 存档 | `ConfigFile` / `JSON` + `user://` |
| 联网 | `ENetMultiplayerPeer` + `@rpc` |
| 保存场景实例 | `PackedScene` + `instantiate()` |
| 定时器 | `Timer`（`timeout` 信号）或 `get_tree().create_timer()` |
| 背景/天空 | `WorldEnvironment`（2D 用 `CanvasModulate` 调色） |

## 7. 常用代码模板

```gdscript
# --- 2D 玩家（CharacterBody2D）---
extends CharacterBody2D
@export var speed := 300.0
@export var jump_velocity := -400.0
func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity += get_gravity() * delta
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity
    var dir := Input.get_axis("move_left", "move_right")
    velocity.x = dir * speed
    move_and_slide()

# --- 摄像机跟随 ---
extends Camera2D
@export var target_path: NodePath
@onready var target := get_node(target_path)
func _process(delta: float) -> void:
    if target: global_position = target.global_position
# 开启 position_smoothing_enabled 可获得平滑跟随

# --- 生成敌人 ---
@export var enemy_scene: PackedScene
func _on_timer_timeout() -> void:
    var e := enemy_scene.instantiate()
    e.global_position = Vector2(randf_range(0, 480), randf_range(0, 270))
    add_child(e)

# --- HTTP 请求 ---
func fetch(url: String) -> void:
    var http := HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(func(_r, code, _h, body):
        if code == 200:
            var data = JSON.parse_string(body.get_string_from_utf8())
            print(data)
    )
    http.request(url)

# --- 场景切换 ---
get_tree().change_scene_to_file("res://scenes/game.tscn")

# --- 暂停 ---
get_tree().paused = true   # 暂停节点需 process_mode = PROCESS_MODE_ALWAYS / WHEN_PAUSED
```

## 8. 参考资料
- 特性列表（本文档来源）：<https://docs.godotengine.org/zh-cn/4.x/about/list_of_features.html>
- 类参考（API 权威）：<https://docs.godotengine.org/zh-cn/4.x/classes/>
- 教程索引：<https://docs.godotengine.org/zh-cn/4.x/tutorials/index.html>
- 渲染器概述：<https://docs.godotengine.org/zh-cn/4.x/tutorials/rendering/>
- 导出：<https://docs.godotengine.org/zh-cn/4.x/tutorials/export/>
- 系统需求：<https://docs.godotengine.org/zh-cn/4.x/about/system_requirements.html>
