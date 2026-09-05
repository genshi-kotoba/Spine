# C2-C5 Spine 资源整合规格（resource_integration_spec.md）

- 版本：v1.0
- 作者：planner（团队 spine-resource-integration ｜ requirements planner）
- 服务对象：engineer（实施 t2）→ verifier（t3）→ reviewer（t4）
- 范围：本文件为**资源整合规格**，只读调研结论 + 逐文件决策 + 引用修复清单 + 验收标准。**不修改任何工程文件（场景/脚本/配置）**；实施动作由 engineer 在本规格约束下执行。

---

## 0. 结论摘要

本轮要做的不是“往现有工程拷几个素材”，而是**一次两分支 fork 的合流**：

- **外层（现状 res:// 根）** `F:\Godot\Spine\Spine`：近期开发主线，含“item 交互”功能（`item.gd` / `test_item.gd` / `test_item_demo.tscn` / `item_constraints.md`），以及门/层/角色等关卡基础。**已被 README 指定为被打开的工程**。
- **内层（协作者上传）** `F:\Godot\Spine\Spine\Spine`：提交 `4231222 Add files via upload`（作者 genshi-kotoba）。含 **C2-C5 内容**：对话系统（`DialogueManager` / 新版 `DialogueBox`）、开始屏/邮箱屏/电脑屏、`assets/sprites` 精灵资产、`dialogues` 文本。

两个工程共享同一套基础代码（多数同路径文件**内容一致**、脚本 **UID 一致**），只是各走了一条功能分支。因此整合策略是：

1. 把内层的 **C2-C5 独有资源**按“同一 `res://` 相对路径”并入外层；
2. 对 **46 个同名冲突文件**做逐文件决策（取内层 / 保留外层 / 维持现状）；
3. **保留外层 item 功能**（6 个外层独有文件不动）；
4. **不动 `scenes/main.tscn`**（铁律）。

真正需要“合并决策”的**真实内容冲突只有 7 个**（其余冲突要么内容字节一致、要么仅行尾/换行差异、要么是 `.bak`/`.uid` 附件）。

---

## 1. 工程与源定位

| 项 | 路径 | 说明 |
|---|---|---|
| **目标 res:// 根（外层）** | `F:\Godot\Spine\Spine` | README：用编辑器打开 `Spine/project.godot`；仓库根 ≠ 工程根 |
| **源（内层，协作者上传）** | `F:\Godot\Spine\Spine\Spine` | 是外层工程内被再次嵌套的一份完整 Godot 工程 |
| Godot 版本 | `4.7.2.stable` | 本机 `F:\Godot\godot\godot.exe`（`F:\Godot\godot-launcher.cmd` 代理） |

**映射规则（核心）**：内层文件 `A` → 目标 `res://A`（保持相对路径不变）。

- 例：内层 `assets/sprites/C2_background.png` → 目标 `res://assets/sprites/C2_background.png`。
- 依据：内层所有 `.tscn`/`.gd` 的资源引用**全部基于 `path="res://..."`**（grep 未发现任何 `.tscn` 内嵌 `uid://` 引用）。因此“放到正确 res:// 相对路径”即自动解析引用，无需逐个改写引用串。

---

## 2. 铁律与边界（不可逾越）

1. **不动 `scenes/main.tscn`**：主场景保持外层现状（空 `Node2D root`，无 `StartScreen` 实例）。内层 `main.tscn` 与之一致性差异见 §6.2，但**不采纳**。
2. **不 push**（团队可本地提交，禁止推到远端）。
3. **不做玩法流程接入设计**：不把 `start_screen.tscn` 接进 `main.tscn` 入口、不设计“进入游戏→开始屏→电脑屏→邮箱屏”的流程；只保证这些场景/资源被正确并入且**可独立加载**。
4. 实施阶段禁止修改任何**现有**场景结构或脚本**逻辑**（本规格允许的“取内层替换”除外）；不得改动 `.tscn` 中与整合无关的节点。

---

## 3. 数量统计（基于 git tracked，精确）

| 集合 | 数量 | 说明 |
|---|---:|---|
| 内层 tracked 文件 | 97 | 提交 4231222 实际入库 |
| 外层 tracked 文件 | 52 | 当前 HEAD |
| **同名冲突**（同 res:// 相对路径在两工程都存在） | **46** | 其中 20 个字节一致、26 个不同（多为附件/行尾差异） |
| 内层独有（待 ADD） | 51 | 28 源 + 22 附件(`.import`/`.uid`) + 1 runtime log（不入库） |
| 外层独有（保留） | 6 | item 功能 |
| **真实内容冲突** | **7** | project.godot / main.tscn / InteractableObject.gd / Player.gd / MainScene.gd / DialogueBox.gd / dialogue_box.tscn |

> 注：任务描述“Spine/Spine/ 下 122 文件”为**描述性数字**（协作者上传时可能把 `.godot` 编辑器缓存、运行时产物一并算入）。整合以 **git tracked 97 份**为权威清单；`.godot/`（编辑器缓存）、`app_userdata/**`（运行时日志）均不入库（`.gitignore` 已忽略）。

---

## 4. 新增文件清单（ADD）——把内层独有资源并入外层

### 4.1 待复制源文件（28）→ 目标 `res://<同路径>`

**精灵资产（13）**
```
res://assets/sprites/C2_background.png
res://assets/sprites/computer screen.jpeg
res://assets/sprites/cursor_icon.png
res://assets/sprites/item_icon.png
res://assets/sprites/mail_icon.png
res://assets/sprites/mailbox_screen.jpeg
res://assets/sprites/main_character.png
res://assets/sprites/setting_icon.png
res://assets/sprites/start_button.png
res://assets/sprites/start_screen.png
res://assets/sprites/work_icon.png
res://assets/sprites/backup/computer screen.jpeg
res://assets/sprites/backup/start_screen.png
```

**对话文本（2）**
```
res://dialogues/dialogue1.txt
res://dialogues/dialogue2.txt
```

**场景（4）**
```
res://scenes/computer_screen.tscn
res://scenes/dialogue_test.tscn
res://scenes/mailbox_screen.tscn
res://scenes/start_screen.tscn
```

**脚本（9）**
```
res://scripts/autoload/DialogueManager.gd
res://scripts/objects/MailIcon.gd
res://scripts/objects/SettingIcon.gd
res://scripts/objects/StartButton.gd
res://scripts/objects/WorkIcon.gd
res://scripts/scenes/ComputerScreen.gd
res://scripts/scenes/DialogueTest.gd
res://scripts/scenes/MailboxScreen.gd
res://scripts/scenes/StartScreen.gd
```

### 4.2 待携带附件（22）——与源文件一一对应拷贝

`.import`（13，对应上方 13 个精灵）、`.uid`（9，对应上方 9 个 `.gd`）。逐项：
```
assets/sprites/C2_background.png.import
assets/sprites/computer screen.jpeg.import
assets/sprites/cursor_icon.png.import
assets/sprites/item_icon.png.import
assets/sprites/mail_icon.png.import
assets/sprites/mailbox_screen.jpeg.import
assets/sprites/main_character.png.import
assets/sprites/setting_icon.png.import
assets/sprites/start_button.png.import
assets/sprites/start_screen.png.import
assets/sprites/work_icon.png.import
assets/sprites/backup/computer screen.jpeg.import
assets/sprites/backup/start_screen.png.import
scripts/autoload/DialogueManager.gd.uid
scripts/objects/MailIcon.gd.uid
scripts/objects/SettingIcon.gd.uid
scripts/objects/StartButton.gd.uid
scripts/objects/WorkIcon.gd.uid
scripts/scenes/ComputerScreen.gd.uid
scripts/scenes/DialogueTest.gd.uid
scripts/scenes/MailboxScreen.gd.uid
scripts/scenes/StartScreen.gd.uid
```

### 4.3 不入库
```
Godot/app_userdata/Spine/logs/godot.log   ← 运行时日志，.gitignore 已忽略，禁止入库
```

---

## 5. 冲突文件决策表（46 项）

图例：
- `TAKE_INNER` 用内层版本覆盖外层（内层为超集/更完整）
- `KEEP_OUTER` 保留外层版本（外层为超集/含较新功能）
- `NO_CHANGE` 内容一致（字节级或仅行尾/换行差异），维持现状即可
- `PROTECTED` 铁律保护，不得改动
- `SIDECAR_BACKUP` `.bak` 开发者备份，非构建输入，保留外层即可
- `SIDECAR_UID` `.uid`，两工程 uid 值相同，随源文件携带/保留皆可

```
docs/c3_floor_constraints.md                                  NO_CHANGE
project.godot                                                 TAKE_INNER
project.godot.bak                                             SIDECAR_BACKUP
scenes/auto_door.tscn                                         NO_CHANGE
scenes/auto_door.tscn.bak                                     SIDECAR_BACKUP
scenes/c3_floor.tscn                                          NO_CHANGE
scenes/c3_floor.tscn.bak                                      SIDECAR_BACKUP
scenes/floor_template.tscn                                    NO_CHANGE
scenes/level_scene.tscn                                       NO_CHANGE
scenes/locked_bedroom_door.tscn                               NO_CHANGE
scenes/locked_bedroom_door.tscn.bak                           SIDECAR_BACKUP
scenes/main.tscn                                              PROTECTED
scenes/main_scene.tscn                                        NO_CHANGE
scenes/player.tscn                                            NO_CHANGE
scenes/player.tscn.bak                                        SIDECAR_BACKUP
scripts/autoload/GameState.gd                                 NO_CHANGE
scripts/autoload/GameState.gd.uid                             SIDECAR_UID
scripts/autoload/StoryMonitor.gd                              NO_CHANGE
scripts/autoload/StoryMonitor.gd.uid                          SIDECAR_UID
scripts/components/DepthParallax.gd                           NO_CHANGE
scripts/components/DepthParallax.gd.uid                       SIDECAR_UID
scripts/objects/AnimatedObjectSample.gd                       NO_CHANGE
scripts/objects/AnimatedObjectSample.gd.uid                   SIDECAR_UID
scripts/objects/AutoDoor.gd                                   NO_CHANGE
scripts/objects/AutoDoor.gd.bak                               SIDECAR_BACKUP
scripts/objects/AutoDoor.gd.uid                               SIDECAR_UID
scripts/objects/InteractableObject.gd                         TAKE_INNER
scripts/objects/InteractableObject.gd.uid                     SIDECAR_UID
scripts/objects/LockedBedroomDoor.gd                          NO_CHANGE
scripts/objects/LockedBedroomDoor.gd.bak                      SIDECAR_BACKUP
scripts/objects/LockedBedroomDoor.gd.uid                      SIDECAR_UID
scripts/objects/StaticObjectSample.gd                         NO_CHANGE
scripts/objects/StaticObjectSample.gd.uid                     SIDECAR_UID
scripts/player/Player.gd                                      KEEP_OUTER
scripts/player/Player.gd.bak                                  SIDECAR_BACKUP
scripts/player/Player.gd.uid                                  SIDECAR_UID
scripts/scenes/FloorTemplate.gd                               NO_CHANGE
scripts/scenes/FloorTemplate.gd.uid                           SIDECAR_UID
scripts/scenes/LevelScene.gd                                  NO_CHANGE
scripts/scenes/LevelScene.gd.bak                              SIDECAR_BACKUP
scripts/scenes/LevelScene.gd.uid                              SIDECAR_UID
scripts/scenes/MainScene.gd                                   TAKE_INNER
scripts/scenes/MainScene.gd.uid                               SIDECAR_UID
scripts/ui/DialogueBox.gd                                     TAKE_INNER
scripts/ui/DialogueBox.gd.uid                                 SIDECAR_UID
ui/dialogue_box.tscn                                          TAKE_INNER
```

---

## 6. 真实内容冲突（7 项）逐项决策 + diff 依据

> 依据均为“归一化去除行尾/换行差异后”的内容对比。以下差异均为**语义性**内容差异。

### 6.1 `project.godot` → **TAKE_INNER**

| | 说明 |
|---|---|
| 外层 | `config/name="Spine"`；`run/main_scene="res://scenes/main.tscn"`；viewport 1920×1240；`[autoload]` GameState、StoryMonitor；`[input]` move_left/right/interact。 |
| 内层 | 除上述**完全一致**外，另加：`[autoload] DialogueManager="*res://scripts/autoload/DialogueManager.gd"`、`[input] dialogue_t`（物理键 T）、`dialogue_y`（物理键 Y）。 |
| 决策 | 内层为**纯超集**，其余配置镜像一致。取内层即仅补上对话系统的 autoload 与输入映射，风险极低。 |

### 6.2 `scenes/main.tscn` → **PROTECTED（保留外层）**

| | 说明 |
|---|---|
| 外层 | `[gd_scene format=3]`；`[node name="root" type="Node2D" unique_id=1595679044]`（空根）。 |
| 内层 | `load_steps=2`；`ext_resource start_screen.tscn`；`[node name="Main"...]` + `[node name="StartScreen" instance=ExtResource("1")]`。 |
| 决策 | **铁律不动**。内层把 C2-C5 的进入入口（StartScreen）挂进主场景，但属玩法流程接入，本阶段不采纳。主场景保持外层空根。 |

### 6.3 `scripts/objects/InteractableObject.gd` → **TAKE_INNER**

| | 说明 |
|---|---|
| 外层 | `func apply_state(state: String) -> void:` 仅 `# TODO` + `pass`（空实现）。 |
| 内层 | `apply_state` 已实现：`states.get(state,{})` → 依次应用 `position`（节点位置）、`size`（碰撞盒 `CollisionShape2D.shape.size`，仅 RectangleShape2D）、`texture`（`load()` 赋给 `Sprite2D.texture`）。 |
| 决策 | 内层为**超集**（把外层 TODO 补全）。与 item 功能**无关**（`item.gd` 独立 `extends Area2D`，其 `apply_state(new_state:int)` 是另一方法）。外层门场景（auto_door/c3_floor/locked_bedroom_door）**未配置 `states`**（grep 无 `states`/`apply_state`/`texture` 引用）→ 取内层后 `states.get(state,{})` 返回空集，`apply_state` 空转，**不改变门行为**。内层新增的图标脚本（MailIcon/SettingIcon/WorkIcon/StartButton）依赖该实现 → 必须取内层。 |

### 6.4 `scripts/player/Player.gd` → **KEEP_OUTER**

| | 说明 |
|---|---|
| 外层 | 比内层多 `signal interact_pressed` + `_unhandled_input`（`StoryMonitor.input_locked` 时不发射；`is_action_pressed("interact")` 时 emit）。 |
| 内层 | 无 `interact_pressed` 信号、无 `_unhandled_input`（旧版，仅移动+重力）。 |
| 决策 | 外层为**超集**。item 功能依赖 `interact_pressed`（`test_item_demo.tscn` 内联连接），保留外层以**不回归** item 功能。C2-C5 内容不消费 `interact_pressed`，多出该信号无害；另 `StoryMonitor.input_locked` 两工程内容一致（存在），故外层 `_unhandled_input` 成立。**注意**：保留外层 Player.gd 时，其配套 `.uid` 亦保留外层；`player.tscn` 两工程**内容一致**（同路径引用 Player.gd），无冲突。 |

### 6.5 `scripts/scenes/MainScene.gd` → **TAKE_INNER**

| | 说明 |
|---|---|
| 外层 | `_ready()`：`_camera.position = camera_position`（无条件）。 |
| 内层 | 增加保护：`if camera_position != Vector2.ZERO: _camera.position = camera_position`（ZERO 时保留场景文件中的位置）。 |
| 决策 | 内层为**安全增量**（避免 ZERO 覆盖场景内手动摆放的镜头位置）。取内层。 |

### 6.6 `scripts/ui/DialogueBox.gd` + `ui/dialogue_box.tscn` → **TAKE_INNER（耦合，必须同取）**

| | 说明 |
|---|---|
| 外层 | `DialogueBox.gd`：旧 API `show_dialogue(lines: Array)`；`_unhandled_input` 仅鼠标左键切句；`$Panel/$Panel/RichTextLabel`；`dialogue_box.tscn` 为 `Panel`+`RichTextLabel` 结构。外层**无任何场景/脚本引用它**（grep 只见定义本身）→ **死代码**。 |
| 内层 | `DialogueBox.gd`：重写为 `MODE_INTERACTIVE`/`MODE_AUTO`；`show_dialogue(lines: Array, mode: int = MODE_INTERACTIVE)`；`_unhandled_input` 改为“任意键切句 + 1s 冷却 + 始终拦截”；`is_active()`；`$DialogueLabel`/`$AutoTimer`；CJK 字体（Microsoft YaHei 等）、`layer=20` 锚点布局。`dialogue_box.tscn` 为 `DialogueLabel`(RichTextLabel)+`AutoTimer`(Timer) 结构。 |
| 决策 | 内层 `DialogueManager`（autoload）`preload("res://ui/dialogue_box.tscn")` 并调用 `_box.show_dialogue(lines, mode)`、连 `dialogue_finished`。故 **`DialogueBox.gd` 与 `dialogue_box.tscn` 必须同时取内层**，节点结构 `DialogueLabel`/`AutoTimer` 与脚本 `$DialogueLabel`/`$AutoTimer` 需一致。外层旧版为死代码，替换无副作用。 |

---

## 7. 保留文件（外层独有，不动）

```
res://docs/item_constraints.md          （item 模块规格文档）
res://scenes/test_item_demo.tscn        （item 交互演示场景）
res://scripts/objects/item.gd           （item 基类，extends Area2D）
res://scripts/objects/item.gd.uid
res://scripts/objects/test_item.gd      （子类）
res://scripts/objects/test_item.gd.uid
```

这 6 个文件构成外层近期开发的 **item 交互功能**，内层没有，**不参与整合**，保留原样。它们依赖 `Player.interact_pressed`（外层 Player.gd，§6.4 已保留）与自身 `item.gd` 的 `apply_state(int)`，与 `InteractableObject` 的 `apply_state(String)` 互不影响。

---

## 8. 引用修复清单（“修复引用”到底要做什么）

1. **`project.godot`**：随 §6.1 取内层，自动带上 `[autoload] DialogueManager` + `[input] dialogue_t/dialogue_y`。**这是唯一的“工程级引用变更点”**。
2. **其余引用全部基于 `path="res://..."`**，且内层新文件及其引用在“同路径落位”后即全部解析（§4 已列，逐项核对：`DialogueManager`→`ui/dialogue_box.tscn`；`MailIcon`→`assets/sprites/mail_icon.png`；`SettingIcon`→`setting_icon.png`；`StartButton`→`scenes/computer_screen.tscn`+`start_button.png`；`WorkIcon`→`work_icon.png`；`ComputerScreen`→`scenes/mailbox_screen.tscn`+`cursor_icon.png`；`DialogueTest`→`dialogues/dialogue1.txt`/`dialogue2.txt`）。**因此无需逐个改 `.tscn`/`.gd` 内部引用串。**
3. **`.uid` 一致性**：经比对，内层与**外层对同一路径的脚本 UID 值完全一致**（如 `InteractableObject.gd.uid` 两工程同为 `uid://y88gs24dvidt`）→ 无 UID 冲突、无“重复 UID”风险。携带 `.uid` 即可让编辑器沿用而非重生成。若编辑器仍提示个别重复 UID，删除对应 `.uid` 让其重生成即可（引用皆 path 型，安全）。
4. **`.import` 附件**：随 13 个精灵资产一并携带，使纹理导入 uid 稳定；若项目 `res://` 路径与 `.import` 记录一致，无需重新导入。让 Godot 对整个工程做一次 `--import` 刷新即可。
5. **不入库**：`app_userdata/.../godot.log` 运行时日志（gitignore 已忽略，禁止入库）。

---

## 9. 风险与待确认决策点

- **R1｜main.tscn 保护 → C2-C5 入口不可达**：主场景保持空根，`start_screen.tscn` 不会由启动自动加载。这属“不做玩法流程接入”的边界，**非缺陷**。t3 验证 C2-C5 时必须**直接加载新场景**（`--scene` 逐个打开）或通过 `DialogueManager` 单测触发，以证明资源本身可加载、无缺失引用。
- **R2｜`.bak` 文件**：为开发者备份，**非构建输入**（Godot 不识别 `.bak` 为资源），保持外层现状即可；取内层源文件后对应 `.bak` 会略陈旧，但无功能影响。
- **R3｜`backup/` 子目录**：`computer screen.jpeg`/`start_screen.png` 的备份副本，**无任何引用指向**（grep 未命中）→ 携带或不带皆无功能影响；为不丢失协作者数据，建议携带（§4.1 已列为 ADD）。
- **R4｜两功能并存**：item 功能（外层，int 状态机 + `interact_pressed`）与 C2-C5 对话系统（内层，`DialogueManager` + 新 `DialogueBox`）无共享状态，按设计并行，互不干扰。
- **R5｜需要确认的少数点**：
  - `DialogueManager.start_dialogue("res://dialogues/dialogueX.txt", MODE_*)`：`dialogueX.txt` **按行分句、忽略空行**（`_load_lines` 实现），请确认文本格式与 `dialogue1/2.txt` 一致（换行即一句）。
  - 内层 `DialogueBox.gd` 引用 `StoryMonitor.lock_input()/unlock_input()/input_locked`：两工程 `StoryMonitor.gd` 内容一致，方法存在，已确认。
  - `InteractableObject` 的 `states` 键值形态：`states[state] = {"texture": path, "size": Vector2, "position": Vector2}`（键均可选），已与 `MailIcon.gd` 等 `"texture": "res://..."` 写法核对一致。

---

## 10. 验收标准（供 t3 验证）

> 在 `F:\Godot\Spine\Spine` 上执行（Godot 4.7.2：`F:\Godot\godot\godot.exe`）。

| # | 验收项 | 方法 | 通过标准 |
|---|---|---|---|
| A1 | 工程无导入错误 | `godot.exe --headless --path F:\Godot\Spine\Spine --import`（或 `--quit` 触发导入） | 全部资源/场景/脚本导入无 ERROR；无 missing resource（path 型 `ExtResource` 全部解析） |
| A2 | 主场景可运行 | `--path ... --quit-after 60`（或编辑器 F5） | 加载 `res://scenes/main.tscn`（空根）无脚本/资源缺失错误 |
| A3 | autoload 注册 | 导入后查看错误/日志 | `GameState`、`StoryMonitor`、`DialogueManager` 三者均成功注册，无缺失脚本报错 |
| A4 | 新场景可独立加载 | 逐场景：`--path ... scenes/<scene>.tscn`（或实例化） | `start_screen`、`computer_screen`、`mailbox_screen`、`dialogue_test` 均无缺失 `ExtResource`/脚本错误 |
| A5 | 精灵资产可导入 | `--import` 后检查 `.godot/imported/` | 13 个资产均成功导入（有对应导入记录） |
| A6 | 无 UID 冲突 | 打开编辑器/导入日志 | 无 `duplicate UID` / `UID collision` 报错 |
| A7 | item 功能不回归 | 加载 `scenes/test_item_demo.tscn` | 场景可载入，`Player.interact_pressed` 连接存在 |
| A8 | 门/层场景不回归 | 加载 `auto_door`/`c3_floor`/`locked_bedroom_door` | 可载入，无因 `InteractableObject` 取内层引发的新错误 |
| A9 | （可选功能冒烟）对话可触发 | 运行 `dialogue_test.tscn` 场景并模拟按键 | 首句显示、按键切句/自动切句、结束后解锁输入（`DialogueBox` 新 API 生效） |

失败即判定整合不达标，转 engineer 修复后重测。

---

## 11. 变更记录（维护日志 · 中文倒序）

| 日期 | 类型 | 内容 | 影响范围 | 回滚要点 |
|---|---|---|---|---|
| 本次 | 新增 | 首次建立 C2-C5 Spine 资源整合规格（本文件 v1.0），含工程/源定位、46 冲突决策、7 真实内容冲突 diff 依据、ADD/保留清单、引用修复与验收标准 | 仅新增规格文档，不影响任何工程文件 | 删除本文件即可（纯文档，无工程副作用） |
| 2026-09-05 | 资源整合 | 协作者 4231222 资源并入 res://：51 独有上移 + 5 TAKE_INNER + Player.gd 保留外层 + main.tscn 未动；Spine/Spine 清空；.gitignore 补 godot.log/*.bak/backup/；backup/ 副本未携带（存于 git 历史 4231222）；验证：t3 5 条 verify 全过、t4 review pass、headless 双跑 exit 0 | project.godot 新增 DialogueManager autoload + dialogue_t/y；InteractableObject/MainScene/DialogueBox/dialogue_box 采用内层版 | git revert 本提交；backup 数据从 4231222 恢复 |
