# DSH 文档到 Codex 的迁移记录

## 来源与基线

- 来源仓库：`https://github.com/genshi-kotoba/Spine`
- 参考 ref：`origin/docs/agent-guides`（commit `90e017fbacf4236f47aa726d4e527a20e5c0638a`）
- 工作基线：PR #4 `wip/c3-framework-v2`（commit `3c203c62778c352b1f88321b24223cf3fca61b49`）
- PR 状态：OPEN，标题为 `[WIP] C3 staging v2 (overall not acceptable, new WIP snapshot)`；正文明确要求不要合并。

## 迁移映射

| DSH 文档概念 | Codex 形态 | 处理结论 |
| --- | --- | --- |
| `docs/agent/AGENTS.md` 用户级全局设置 | 仓库根 `AGENTS.md` | 只保留项目边界、并行、验证和回滚规则；删除 DSH 插件、Windows 路径和本机状态。 |
| `godot-deep-delivery` | `.agents/skills/godot-deep-delivery/SKILL.md` | 保留五条交付硬规则、验证矩阵、WIP/外部仓库和并行恢复约束。 |
| `godot-continuity` | `.agents/skills/godot-continuity/SKILL.md` | 将 DSH todo/tracker 替换为 Codex goal、Git 和项目 `docs/` 记录。 |
| DSH `subagent` / `workflow` / `agent_teams_*` | Codex `spawn_agent` / `followup_task` / `wait_agent` | 只在用户明确要求并行时使用；主代理保留集成与最终验收。 |
| DSH `todo_write` / `task_*` | Codex goal 工具与会话进度 | 不写入不存在的工具名，避免复制不可执行配置。 |

## C3 完整流程白模快照（2026-09-05）

- 基线：`origin/wip/c3-framework-v2`，commit `3c203c62778c352b1f88321b24223cf3fca61b49`；目标分支：`codex/wip-pr-4`。
- 范围：C3 白模完整流程、2.35:1 取景与横向相机边界、书房门锁定、光影揭示、有限走廊与三个屏息特异点、呼吸/缺氧/镜头跷跷板、独立卧室及往返状态保持；同时保留 ItemMarker 的近远描边和可复用特效组件。
- 已通过（从仓库根执行）：
  - `/Volumes/OmubotDisk/Godot/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/OmubotDisk/Godot/Spine/Spine --scene res://scenes/c3_level.tscn -- --self-check`
  - `/Volumes/OmubotDisk/Godot/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/OmubotDisk/Godot/Spine/Spine --scene res://scenes/c3_level.tscn -- --corridor-breath-self-check`
  - `/Volumes/OmubotDisk/Godot/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/OmubotDisk/Godot/Spine/Spine --script res://scripts/c3/flow/study_door_selftest.gd`
  - `git diff --check`
- 未执行：Godot MCP 场景树/截图验证和人工完整游玩。无界面检查证明状态机和物理断言通过，不构成视觉成品验收。
- 回滚：在该快照提交后使用 `git revert <c3-whitebox-commit>`，或切回 `3c203c62778c352b1f88321b24223cf3fca61b49`；不使用 `git reset --hard` 或清理工作树。

## 验收与回滚

- 验收：`git diff --check`、文件重读、Codex skill 结构检查、PR/ref 与来源核对。
- 未执行：未启动 Godot 场景的完整运行时/MCP playtest；PR #4 本身仍是 WIP，不能据此宣称游戏完成。
- 回滚：删除本次新增的 `AGENTS.md`、`.agents/skills/godot-*` 和本记录，或使用包含这些文件的 Git 提交回退；不改动 PR #4 的游戏代码。
