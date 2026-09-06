# C3 合并（Spine_to_merge → Spine）：决策与验收契约

> 2026-09-06 用户指令：审查 Spine_to_merge（主要修改了 C3），把其 C3 成果融入 Spine 框架，每处冲突先问后改。
> 本文件记录审查结论与用户对每一处冲突的裁决，是本次合并的唯一权威依据。

## 1. 审查结论（差异图谱）

- 对方 c3 进化：走廊拼接架构（CorridorAssembly + CorridorVisualLayer/SpecialPointLayer/CorridorSegment/CorridorCamera）、呼吸 FX 管线（bubble_pop_ring、粒子、屏震）、C3Flow 783→1519 行（intro 黑场首键、墙三段开门、房间名横幅、文字雨、结局渐变切场景）、c3_bedroom_room 美术场景、FloatingWallText 模块、Player 时间制运动配置。
- 对方 c3 对框架层硬缺口仅 1 个：`DialogueManager.start_lines()`（纯新增）。
- 对方 c3 **不使用** player_in_range / highlight_enabled / state_id / interactable（我方 c2/c4/桌面命脉），改用自有 `is_player_in_interaction_range()` 位置判定。
- 我方 GameState 为对方超集（自动存档+delete_save）；project.godot 对方改动为 dev 环境设置（主场景/窗口/拉伸），均保我方。
- 对方独有需带入文件：c3_main.png、bubble_pop_ring.png、computer screen.jpeg（备份用）、c3_intro.txt、c3_bedroom_room.tscn、floating_wall_text.tscn(+demo)、player_motion_test.tscn、CorridorAssembly/SpecialPointLayer/CorridorVisualLayer/CorridorCamera/CorridorSegment/FloatingWallText(Demo)/PlayerMotionProfile(+tres+selftests)、7 份 c3 设计文档。

## 2. 冲突裁决记录（用户逐项确认）

| # | 冲突点 | 裁决 |
|---|---|---|
| C1 | DialogueBox：我方任意键切句+无背板 vs 对方 Enter 切句+Backdrop | **保我方**（任意键，下移 30px 不动） |
| C2 | Player：我方朴素参数+出生吸附 vs 对方 MotionProfile 时间制 | **引入对方运动配置**（PlayerMotionProfile.gd + default_player_motion.tres + 反向保持），保留我方 _snap_to_floor 与 debug-fall |
| C3 | item.gd：对方删 state_id/highlight/player_in_range | **我方基线 + 叠加对方**（SFX 三件套、vertical_interaction_padding、is_player_in_interaction_range、touched 成功时 _request_interaction_sfx） |
| C4 | LevelScene：对方删窄图 clamp 保护 | **直接用对方版**（含预览 Player 守卫 + 交互音效钩子；已知风险：窄 bedroom 相机可能错位，用户接受） |
| C5 | InteractableObject：对方 +SFX | 用对方版（我方为其子集，纯叠加无冲突） |
| C6 | DialogueManager：对方 +start_lines | 用对方版（纯叠加无冲突） |
| C7 | RoomBase：对方地板宽度修正 | **保我方**（c3 孤房地板多出的横条接受） |
| C8 | AutoDoor：对方 +set_auto_open_enabled | **叠加对方新增**（C3Flow 有调用） |
| C9 | test_item.gd：对方 _try_touch 现代化 | **用对方版** |
| — | c3 全部脚本/场景/组件/资源/文档 | 对方整体带入（指令本意，非冲突） |

## 3. 实施清单

**整体复制（对方版覆盖/新增，含 .uid）**：scripts/c3/**（8 改 + camera/corridor_specials/corridor_visual/flow 新目录）、scripts/components/{ItemMarker,ScreenShake,InteractHint,DarknessMask,ParticleBurst,FloatingWallText}.gd + darkness_mask.gdshader、scripts/objects/{InteractableObject,AutoDoor,test_item}.gd、scripts/scenes/{LevelScene,FloatingWallTextDemo}.gd、scripts/autoload/DialogueManager.gd、scripts/player/{PlayerMotionProfile.gd,player_motion_selftest.gd,default_player_motion.tres}、scenes/{c3_floor,c3_level,c3_bedroom_room,floating_wall_text,floating_wall_text_demo,player_motion_test}.tscn、assets/background/c3_main.png、assets/fx/bubble_pop_ring.png、assets/sprites/computer screen.jpeg、dialogues/c3_intro.txt、docs/ 7 份。

**手工合并**：
- `scripts/objects/item.gd`：我方基线 + `_setup_interaction_sfx/_request_interaction_sfx`（_ready 与 touched 接线）+ `vertical_interaction_padding` + `is_player_in_interaction_range()`。
- `scripts/player/Player.gd`：对方版 + 我方 `_snap_to_floor`（首帧吸附）与 debug-fall 块接回。
- `scenes/player.tscn`：加 motion_profile ext_resource 绑定（保留我方 uid 属性）。

**不动**：DialogueBox（C1）、GameState、RoomBase（C7）、project.godot、c2/c4/desktop 全部、Bedroom.gd。

**禁区**：不 push（合并完成后用户另行指令）；改前全部留 .bak。

## 4. 验收

1. headless 加载 c3_level / c3_floor / c3_bedroom_room / floating_wall_text_demo / player_motion_test 0 错误；
2. 回归：c2_floor / c4_floor / computer_screen / dialogue_test / c2_bedroom / c4_bedroom headless 0 错误；
3. 红线扫描新改动文件（我方手写部分）；
4. 窗口验收（用户）：c3 全流程（intro→走廊→呼吸 FX→结局）、c2/c4 流程不回退、bedroom 相机状况确认（C4 风险项）。

## 5. 变更记录

- 2026-09-06 初版：审查 + 9 项冲突裁决落定，待实施。

## 实施记录（2026-09-06 完成）

- 已按 §3 全部裁决落地。c3 侧文件整批带入（含 .uid）；框架层手工合并。
- 附带修复：Corridor.gd 自检段 2 处 `:=` 推断 Variant（rocking_forwarded/pulse_ok）改显式 bool；DialogueManager 并行编辑竞态导致 start_lines 丢失，已补回并核验。
- 未带入：`assets/sprites/computer screen.jpeg`（桌面素材，与 c3 无关）。
- 验证：红线 0 命中；editor 扫描 0 错误；c3_level/c3_floor/c3_bedroom_room/floating_wall_text_demo/player_motion_test + 回归 c2_floor/c4_floor/computer_screen/dialogue_test/c2_bedroom 全 0 错误。

## 追加：组件层合并（2026-09-06，运行时 set_rocking 报错引出）

初批漏拷 components 层。盘点 6 个差异文件后按用户裁决落地：
- 纯叠加直接带入：ScreenShake（sway/rocking/base_offset API，shake 语义保留）、ParticleBurst（set_world_space_particles）、InteractHint（_process 轮询 is_player_in_interaction_range + 碰撞锚点偏移）。
- 裁决⑧ ItemMarker 用对方版（星星→Line2D 描边高光；仅 c3+demo 使用，demo 同步换对方版）。
- 裁决⑨ DarknessMask 用对方新默认色 Color(0.02,0.03,0.09,0.55)（「用户定案：非全黑」）+ side_mask/intensity API + shader 侧向遮罩分支。
- 验证：红线 0；c3_level/item_marker_demo/fx_demo/e_hint_demo/darkness_demo/c2/c4/computer_screen 全 0 错误（含 Nonexistent function 检查）。

## 第二轮合并（Spine 2 merge → Spine，2026-09-06 12:35 版）

> 对方新源目录 `Spine 2 merge`。差分基准 = 上次合并源 Spine_to_merge（09:01），我方 c3 侧自一轮合并后零改动（已核验 SAME），可安全直盖。

### 对方增量清单

- **故障字幕升级**：GlitchDialogueBox 加 font_scale / world_anchor（世界锚定，相机跟随）/ persistent（不自动切句）/ 描边渲染；DialogueManager 的 start_dialogue/start_lines 加对应透传参数（向后兼容）。
- **C3Flow 改版**：intro 三段提示与全部流程悬浮文字从 FloatingWallText 迁到独立 GlitchDialogueBox 实例（layer 26）；「不过」开场即解锁移动，书房出门锁延长至「总之」提示结束；INTRO_BREATH_RATE 2→4；特异点通过后 1s 播底部字幕；第三特异点五句故障文字并行触发；厨房对白后「←」方向提示；OkPopup 彻底移除；E 键判定改 _flow_interactive_dialogue_active。
- **BreathSystem**：_initial_breathe_locked——首次缺氧前锁空格、倒计时加速，缺氧开始后恢复。
- **CorridorAssembly**：特异点①换真奖状素材（certificate_1~3.png ×24 随机）；特异点②12 行三角书山（DirAccess 动态加载 assets/corridor/books，空目录走程序化回退）；特异点③静态 Label 删除（改 C3Flow 触发）；自检加 book_mountain 检查。
- **c3_level.tscn**：删 OkPopup 节点与 IntroFloatingLayer（两个 FloatingWallText 实例）、删 3 个对应 export 赋值。

### 裁决记录

| # | 冲突点 | 裁决 |
|---|---|---|
| R1 | DialogueBox 任意键切句 | 双方已各自独立实现（我方另删 Backdrop），我方版为超集，**不动** |
| R2 | DialogueManager | 用对方新版（font_scale/world_anchor 纯叠加），保留我方 start_lines 注释行 |
| R3 | FloatingWallText 组件全家（脚本+2场景+demo脚本+文档，对方已废弃删除，新版 c3 零引用） | **跟随对方删除**（用户裁决） |
| R4 | assets/corridor/books 对方未提供 | 先用程序化回退（对方自带机制），补素材后自动生效，不阻塞 |
| R5 | OkPopup.gd 文件本体 | 保留在 components 库（c3 场景引用随新版 tscn 删除） |

### 实施清单

- 覆盖：GlitchDialogueBox.gd / DialogueManager.gd / BreathSystem.gd / C3Flow.gd / CorridorAssembly.gd / c3_level.tscn（.gd 均先留 .bak；.uid 保留我方不动）
- 新增：assets/corridor/certificates/（3 png + .import）
- 删除：scripts/components/FloatingWallText.gd(+uid)、scripts/scenes/FloatingWallTextDemo.gd(+uid)、scenes/floating_wall_text.tscn、scenes/floating_wall_text_demo.tscn、docs/floating_wall_text_module.md
- 不动：DialogueBox.gd（R1）、dialogue3.txt（仅换行符差异）、project.godot、GameState.gd 等我方后续改动文件
