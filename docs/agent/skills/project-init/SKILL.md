---
name: project-init
description: >
  新项目/新仓库「从头干净」初始化技能：git init（main 分支）+ Godot 4 专属 .gitignore +
  .gitattributes（CRLF）+ 初始 commit 由一键脚本原子完成，并验证 clean、无 .godot 入库。
  Use when 用户说"开个新项目/新游戏/新仓库/从头干净处理/初始化项目"，或任何新建
  godot project 目录、git 仓库的起点 —— 必须走本链路，禁止"先跑起来再补 git"。
---

# Project Init（新项目自动化初始化）

> 教训来源（gdjam-practice 2026-09-01 流程审计 · 环节 10 仓库卫生 ❌）：
> 项目启动时没做一次性 git 初始化（无 .gitignore / 无提交基线），最终留下 104 行 dirty
> （addons 删除未提交、.godot 挂出、23 个残留日志）。**git 干净不是打扫出来的，是初始化时定下的。**

## When to use

- 任何新 Godot 项目 / 新 git 仓库起点。
- 用户提及"从头 / 干净 / 新项目 / 初始化"。

**When *not* to use:** 既有仓库的日常维护（git add/commit/交互式；用 git-guardrails）；只做小样本目录。

## Core workflow（全部可复现）

### 1. 一键脚本（首选）

```powershell
powershell -File F:\Godot\tools\init_godot_project.ps1 -ProjectPath D:\NewGame -ProjectName newgame
```

脚本原子完成（保证不可分割）：**写 .gitignore → 写 .gitattributes → git init -b main → 初始 commit → 验证 clean**；
幂等：已在 repo 内只补文件、已有 commit 不重复提交；输出 RESULT PASS/FAIL。

### 2. 项目骨架（脚本之外的配套，一次到位）

| 文件 | 内容 | 目的 |
|---|---|---|
| `AGENTS.md`（项目根） | 红线 + 触发规则（从本项目模板拷） | 链路延续 |
| `README.md` | 一句话 pitch（与 game-design-plan 同源）+ 运行方式 + CREDITS 指针 | 对外门面 |
| `docs/` + `docs/gomoku.md` 风格交付文档（§0 速查/§7 变更记录） | 工程纪律 | 连续性 |
| `assets/…/CREDITS.md` | 资产台账（来源/许可/日期/用途） | 许可可追溯 |
| `export_presets.cfg` | Web+Windows 预设 | 发布前置 |

### 3. 验证断言（脚本已做 + 人工三问）

- [ ] `git status --porcelain` 为空（CLEAN）
- [ ] `git log --oneline` = 恰好 1 条初始 commit
- [ ] .godot/ 不在跟踪列表（`git ls-files | Select-String .godot` 为空）
- [ ] 人工三问：git 身份（user.name/email 已配置？）→ 远程（origin 要建吗？）→ 许可（license 文件选 MIT/CC 等？）

## Pitfalls（都是踩过的）

1. **忘 .gitignore 的时机**：先 add 再想起 → .godot/ 已入库 → 补救：`git rm -r --cached .godot` + 写 .gitignore + 提交（脚本若在文件存在前跑则不会发生）。
2. **嵌套 .git**：在已有 repo 内再 init（脚本已判 `--is-inside-work-tree`，不嵌套）。
3. **CRLF 警告**：`.gitattributes` 写 `* text=auto eol=crlf`（Windows 工作流）。
4. **外部资产整类忽略**：切勿 *.zip 全局忽略——Kenney 原包/许可文件应入库；大文件走 lfs 或"仅存台账+下载脚本"。
5. **export_presets.cfg 本地路径**：提交前清绝对路径（或接受模板差异）。
6. **空初始 commit**：git 不允许空提交——.gitignore/.gitattributes 本身就是首提交物，保证非空。

## 输出物

`RESULT: PASS` 验证块（HEAD + CLEAN + 文件存在）——交付时必须附上，不许口头"弄好了"。
