---
name: godot-continuity
description: Godot/Game Jam 长任务的 Codex 连续性流程。用于恢复、交接、上下文压缩，或跨会话修改 skill、工作流和项目规则。
---

# Godot Continuity

这是对 `docs/agent-guides` 中 continuity skill 的 Codex 适配。状态放在 Git、项目 `docs/` 记录和 Codex goal 中，不依赖 DSH 的 `~/.dsh`、`todo_write` 或外部 tracker。

## 恢复顺序

1. 读取当前仓库和更深层级的 `AGENTS.md`、项目 README、相关 skill 与交付记录。
2. 查看 `git status --short --branch`、当前 HEAD、远程 ref 和已有 WIP；保留用户未提交改动。
3. 找到最近的迁移/验收记录，提取目标、当前状态、下一步、已确立证据和不必重复的死路。
4. 用 `get_goal` 检查已有目标；必要时用 `create_goal`/`update_goal` 维护长任务状态。
5. 输出恢复摘要：`objective | current status | next action | files | evidence | dead ends`。

## 需要持久记录的情况

任务超过约 15 分钟、触及三个以上文件、跨会话、涉及发布/存档/skill/工作流，或需要多轮实验时，在 `docs/` 增加高信号记录。每次实验写命令、实际结果和结论。

## 交接与收尾

完成或暂停前更新记录中的下一步和验证状态。说明谁接手、从哪个 commit/ref 开始、哪些检查已通过、哪些未执行。耐久变更记录类型、影响、回滚和验证；探索性只读任务可在最终回复说明“无耐久变更”。
