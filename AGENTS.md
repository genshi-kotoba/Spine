# Spine Codex 工作规则

本仓库包含 Godot 工程 `Spine/`，仓库根目录与工程根目录不是同一层。本文档是 Codex 在本仓库工作的入口；更深目录中的 `AGENTS.md` 优先。

模式切换与技能路由见 `docs/agent/CODEX-MODE.md`。

## 项目边界

- 使用 Godot 4.7 或更高版本，工程文件为 `Spine/project.godot`。
- 场景放在 `Spine/scenes/`，脚本放在 `Spine/scripts/`，素材放在 `Spine/assets/`。
- 不提交 `.godot/`、运行时存档、导出产物或本机缓存。
- 本地提交可以随时保存；push、创建或更新 PR 必须得到用户确认。

## Codex 并行协议

用户明确要求并行时才拆分工作。每个 workstream 必须有稳定 ID、唯一目标、明确基线、文件边界、冲突域、验收命令和交付清单。

- 默认最多使用两个子代理；`fork_turns="none"`，提示词必须完整说明目标和边界。
- 一个文件或冲突域只允许一个写入者。写任务使用隔离 worktree；只读调研可以共享当前 checkout。
- 主代理保留架构、接口、合并顺序、最终验证和用户沟通；子代理的结论必须重新检查，不能直接视为验收证据。
- 子代理中断时先续跑原 workstream；不可恢复时只重建一次，并在进度中标记 `rebuilding`，不得静默把工作收回主线程。
- 并行结果合入后按“静态 → 结构 → 语义 → 运行时”顺序做最小跨流验证。

## Codex 工具映射

- 委派：`spawn_agent`、`followup_task`、`send_message`、`wait_agent`、`interrupt_agent`。
- 目标状态：`create_goal`、`get_goal`、`update_goal`；短任务进度使用会话内说明，不引入 DSH 的 `todo_write` 或 `task_*` 假工具。
- 文件修改使用 `apply_patch`。优先 `rg`、`rg --files`、`git show` 和 Godot headless 命令。
- 视觉或运行时验证可使用已配置的 Godot MCP；没有 MCP 证据时，不声称完成运行时验收。

## 交付门禁

1. 修改前读相关 `AGENTS.md`、skill、场景/脚本和现有文档，并在工作说明中复述目标与验收标准。
2. 对外部仓库、WIP 分支或 PR，记录准确的 URL、ref、commit 和已知风险；WIP 不得误报为完成品。
3. 修改后重新读取所有改动文件，检查 `git diff --check`、`git status --short`，并运行与改动匹配的 Godot 检查。
4. 若改动场景、接口、存档或工作流，新增迁移/验收记录，说明回滚路径。
5. 交付时列出已通过、未通过和未执行的检查，以及可复现的命令。

## 回滚

优先使用 Git 分支或提交回退。修改 `project.godot`、存档格式或核心资源前先保留 `.bak`；不要使用 `git reset --hard`、`clean` 或覆盖用户 WIP。
