---
name: godot-continuity
description: Godot/Game Jam 项目上下文连续性技能（由 omubot-continuity 适配）：跨会话/压缩后恢复长任务不重新发现、交接前检查点、单次会话内长任务的状态纪律。用户在说 继续/接着/恢复/别重新开始/防止失忆、上下文压缩/新会话后、大任务结束前交接、bug 调查需测试台账、或改动 prompt/skill/hook/工作流文档/发布行为时使用。
whenToUse: 长任务恢复/交接、跨会话工作、压缩后防止失忆、或需要持久状态台账时。
---

# Godot Continuity（适配版，源自 omubot-continuity）

omubot 仓库任务的连续性仍用仓库内权威副本；本技能为 Godot 项目通用版（状态落在项目 docs + DSH todo，而非 Codex 专用 tracker）。

## Recovery Protocol（恢复协议）

1. 读全局 AGENTS.md（`~/.dsh/AGENTS.md`）与项目 AGENTS.md（若存在）。
2. 读 `docs/gomoku.md`（交付文档，含状态/问题清单/变更记录）——若在 Godot 其他项目则读对应交付文档。
3. 读 `docs/ux_test_plan.md` 与 `docs/gomoku_interface.md`（验收清单/契约）——评估已完成/未完成项。
4. 若前次会话有显式 State 文件（如 `.workspace/agent-session-state.md`、`docs/tracking/ACTIVE.md`），读它；没有则跳到 5。
5. 用 todo 工具（todo_write / TodoPanel）呈现当前阶段与剩余步骤；查看 `git status --short`。
6. 输出恢复报告：目标、当前状态、下一步具体动作、涉及文件、已确立证据、**不复查清单**（避免重新发现）。

不要从架构文档/旧 wiki 重新开始，除非状态文件缺失、过期或被 git 状态反驳。

## Tracker Threshold（何时建立状态记录）

用 todo（todo_write）+ 交付文档记录，当任一条件成立时：

- 任务预计超过 15 分钟
- 触及 3+ 个文件
- 跨会话/用户说"别丢上下文"
- 涉及发布行为、部署、存储、skill/hooks/提示词、工作流规则
- bug 调查需要多次实验（须建 Test Ledger：每次实验记命令/实际结果/结论）

单轮小任务只用 todo，不建文档台账。

## Update Protocol（更新协议）

- 交付文档（docs/gomoku.md）保持"高信号"：结论、决策、验证、回滚、进度概况；问题清单按模板（严重度/根因/修复/回归证据/验收入口）。
- 每个有意义的 bug 实验追加到 Test Ledger（docs 走查记录或独立小节），写清命令、实际结果、结论。
- 只有耐久变更（发布行为/工作流/技能/文档规则）才写"变更记录"节。
- DSH todo 每轮实时更新（阶段性胶囊）。

## Resume Output（恢复输出格式）

- objective ｜ current status ｜ next concrete action ｜ files likely involved ｜ evidence already established ｜ dead ends not to retry

## Stop / Handoff Protocol（停止/交接协议）

长任务最终回复前：

1. 更新 todo + 交付文档的 next step 与验证状态。
2. 若完成：明确"已完成/未验证项"；若移交：写清交接段（谁接手、从哪步、什么没验）。
3. 若耐久变更：更新变更记录（docs/gomoku.md）。
4. 报告已验证与未验证项。


## 维护日志格式（耐久变更当轮写）

docs 交付文档「变更记录」节条目模板（中文、倒序）：

~~~
[日期+时间] 类型：新增/修复/重构/流程/技能
内容：一句话说明（行为/存档/工作流变化点）
影响：范围（模块/场景/存档格式/其他会话依赖）
回滚：如何回退（.bak 还原 / git 回退 / 存档备份点）
验证：当时通过的命令/断言/截图证据
~~~

仅探索性/无持久变化的任务可跳过；跳过时在最终回复说明无耐久变更。


## Godot 工具链接

- `F:/Godot/godot/godot.exe` headless 测试/检查；MCP game 工具；`user://gomoku_save.cfg` 存档（读用 `mode=ro` 理念：游戏运行中不直接改文件，用 MCP 读取）。
- 代码代际 marker 检查：`str("_x" in node)` 确认真实加载新代码后再验证（防旧进程误判）。
