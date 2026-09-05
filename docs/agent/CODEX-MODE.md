# Codex 模式状态

本文件把 `origin/docs/agent-guides` 的 DSH/DeepSeek 工作流压缩为 Codex 可执行的状态机。它是项目级约定，不是对 Codex 工具的伪配置。

## 状态机

`DISCOVER` → `PLAN` → `IMPLEMENT` → `VERIFY` → `HANDOFF`

- **DISCOVER**：读取 `AGENTS.md`、README、目标 ref、相关场景/脚本和 docs；外部事实记录 URL、commit、PR 状态。
- **PLAN**：写出目标、范围、基线、冲突域、验收命令和回滚路径。用户明确要求并行时，才进入并行 workstream。
- **IMPLEMENT**：用 `apply_patch` 小步修改；每个文件只有一个写入者，保留用户 WIP。
- **VERIFY**：按静态、结构、语义、运行时顺序验证；重读改动文件，并报告未执行的检查。
- **HANDOFF**：更新迁移/验收记录，给出当前 HEAD、下一步、已知风险和可复现命令。WIP 快照不能标记为完成品。

## 并行状态

每个 workstream 使用 `pending | running | rebuilding | done | failed` 状态，并携带：稳定 ID、base revision、唯一目标、文件边界、冲突域、验收证据和交付物。Codex 映射如下：

| 需要的动作 | Codex 工具 |
| --- | --- |
| 启动独立子任务 | `spawn_agent` |
| 续跑/纠正原任务 | `followup_task` / `send_message` |
| 等待结果 | `wait_agent` |
| 中断任务 | `interrupt_agent` |
| 长任务目标 | `create_goal` / `get_goal` / `update_goal` |

默认最多两个子代理。主代理负责架构、依赖顺序、集成和最终验收；只读调研可共享 checkout，写任务应使用隔离 worktree。

## 技能路由

| 工作类型 | 首选项目技能 |
| --- | --- |
| Godot 场景、脚本、输入、导出 | `godot-4-development`（来源：`docs/agent-guides`，按需提取） |
| 资源来源、许可、导入 | `godot-asset-sourcing`、`create-game-assets`（来源：`docs/agent-guides`） |
| UI、动画、音频、着色器 | 对应 `godot-ui-control`、`godot-animation`、`godot-audio`、`godot-shaders`（来源：`docs/agent-guides`） |
| 可能静默失败的交付或文档迁移 | `.agents/skills/godot-deep-delivery/SKILL.md` |
| 恢复、交接、跨会话 | `.agents/skills/godot-continuity/SKILL.md` |

来源技能中依赖 DSH 插件、`todo_write`、`task_*`、`agent_teams_*`、`$DSH_HOME` 或 Windows 专用路径的段落，不得直接执行；先改写为本文件和根 `AGENTS.md` 中的 Codex 语义。

## 当前状态

- 工作分支：`codex/wip-pr-4`
- 基线：PR #4 / `wip/c3-framework-v2` / `3c203c62778c352b1f88321b24223cf3fca61b49`
- 状态：C3 完整流程白模已通过项目 headless 自检；Godot MCP/人工完整游玩尚未执行，仍按 WIP 快照管理。
