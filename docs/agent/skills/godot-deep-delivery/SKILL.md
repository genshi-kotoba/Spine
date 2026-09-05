---
name: godot-deep-delivery
description: Godot/游戏项目深度交付技能（由 omubot-deep-delivery 适配）：用于任务可能静默失败的场景——用户批评深度/验证质量、要求联网检索、涉及程序化资产/UID与导入冲突/存档格式、修改 prompt/skill/hook/工作流、或生产级变更需要调研、碰撞检查、dry-run、运行验证与回滚故事时。交付/修复后按 本技能 + game-acceptance 执行，禁止“看起来可以”收尾。
whenToUse: 在 Godot 游戏项目中做会静默失败的变更、被要求深度调研/强验证、修复后验收、或用户质疑上次交付质量时。
---

# Godot Deep Delivery（适配版，源自 omubot-deep-delivery）

本技能把 omubot 仓库的深度交付方法论适配到 Godot 项目（gdjam-practice / Game Jam 工作流）。omubot 仓库任务仍使用仓库内权威副本；本技能为跨项目通用版。

## Delivery Executor Mode（五条硬规则，实施已定型的任务时不可省）

1. **先读后问**：先读仓库/项目文档/日志/测试（read/grep/glob/pwsh）。答案在项目里就自己找，只在确实无法从代码库、存档、日志、文档获取时才问用户。
2. **改前复述**：执行前用自己的话复述目标与验收标准；可能理解错就先抛出来，别改完才发现。
3. **不报完成前重读**：重新打开改过的文件，确认编辑真的达成目标（不信工具回执）。
4. **用 Godot 自检工具箱自己验证**（下面矩阵），不把测试甩给用户：
   - 规则/逻辑 → headless 单测（退出码 0）
   - 编译/语法 → `--check-only`（无 Parse Error/SCRIPT ERROR）
   - 运行时状态 → MCP `game_eval`/`game_get_property`/`game_get_logs`/`get_debug_output`
   - 视觉 → `game_screenshot` 拉图 + `read_image` 目视（逐方向/逐数量核对）
   - 外部写入（真实发送/上传/联网写）→ 需当前任务对精确动作与目标的授权；否则离线 fixture/dry-run/只读
   - 需要新权限/凭据/外部变更时，明确报告边界；绝不扩展范围或编造验证。
5. **先尝试再升级**：一种方案失败就诊断换方案；升级用户前带证据（试了什么、为何失败），不把问题原样抛回。

## Verification Matrix（Godot 版，未达证据不算完成）

- **Static**：`godot.exe --headless --path <proj> --check-only --script <file>.gd`；资源导入无错（.godot/imported 齐、编辑器扫描日志无 ERROR）。
- **Structural**：`read_scene`/断言计数（节点数、键、清单、测试输出 pass/fail 数量）；场景加载（`--script` 或 MCP 真机树）。
- **Semantic**：证明核心含义而非形状——规则单测覆盖横/竖/两斜、边界、≥5 连、平局、悔棋还原、非法输入；AI 必堵/必攻/限时；积分/连胜公式 + 持久化读写一致。
- **Runtime**：MCP 真机（scene 树/属性/方法/截图/日志）；存档 `user://` read-back；性能打点（如 AI time=ms）。
- **Negative/collision**：最容易混淆的用例——非法坐标、已占位、满盘、重复 ID/键、同名资源、UID 冲突、必堵必攻局面。
- **Idempotency/rollback**：重跑是否安全；回滚路径（`project.godot.bak`、git、销毁式变更先备份存档；undo 语义说明）。

## 调研底线（实现前内部回答）

- 哪条现有项目行为/文档/走查清单（docs）约束此项？
- 会与什么冲突：现有 ID/键、导入缓存（.godot）、UID、存档格式、运行时缓存或 UI 语义？
- 哪些事实必须来自网络/官方文档而非记忆？搜索结论可能因同名/旧页/转述摘要出错？
- 最小可复现输入是什么（能证明实现的用例/测试/截图）？

## 资产与数据规则（替代角色卡规则）

- 程序化/占位资产：先 `art_engine`/生成脚本 dry-run；检查输出目录、帧数、命名；Abort 条件：缺资源、重复名、导入失败（无 .ctex/.import）。
- 存档/数据：写前备份；校验键名与类型；损坏文件回退默认（有单测）。
- 导入/UID（4.4+）：新增资源后检查 `get_uid` 与 `update_project_uids`；避免引用失效。

## Final Answer Contract（保留）

收尾给出：改了什么/结论；证据与命令/MCP 检查；用 web 时的来源；残余风险或后续检查。简洁，但不省略未通过的检查与未验证假设。


## 并行交付与恢复（DSH 适配 omubot Token-Aware 协议）

拆子代理并行时，每流必须（主线程在分发时写进 prompt）：

- **稳定 id + 一个目标 + 边界**：只写自己名下文件；冲突域显式声明（符号/API/生成物/存档/端口/缓存/测试命名空间/WIP），一个冲突域一个写入者。
- **基线与交付件**：prompt 内含 base revision、验收证据要求（断言/截图/日志）、交付清单（文件路径+验证命令输出）。
- **预算**：默认并行 2 个后台子代理起（本机偏好可到 4），主线程保持关键路径；小任务不拆（见全局 AGENTS.md 拆分场景化）。
- **集成**：按依赖顺序合入，做最小跨流验证（编译+彼此依赖单测），不信任上层报告。
- **恢复协议**：子代理中断/超时 → 先续跑原流；不可恢复时按原 scope/prompt 重建一个替换（唯一替换在途），状态标记 rebuilding；优先保留已交付文件证据再重建；同一流最多一次重建，仍失败则该流标记失败并如实汇报——绝不静默降级为上层顺手做了。
- **失败即止**：权限/令牌/外部写被拒 = 立即停，不自行扩大授权。

## 迁移清单（D3 变体）

大重构（场景结构/接口/存档格式/模块替换）必须先写旧到新迁移对照（docs 变更记录或 docs/migrations 节）：文件/节点/接口/数据四列，逐项回归；完成前逐列打勾。


## 相关文件（Godot 项目）

- `docs/gomoku.md`（交付文档/问题清单）、`docs/ux_test_plan.md`（走查清单）、`docs/gomoku_interface.md`（契约）
- `scripts/tests/*.gd`（headless 套件）、`project.godot.bak`（回滚）、`user://gomoku_save.cfg`（存档）
- MCP：`F:/Godot/tools/mcp-tugcan/build/index.js` + 游戏侧 `McpInteractionServer`（9090）
