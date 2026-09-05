# AGENTS.md — 用户全局技能与工作偏好（DSH $DSH_HOME/AGENTS.md）

本文件是 DSH（DeepSeek Harness）的用户级指令基线，对所有 profile / 项目生效。
项目根目录下的 AGENTS.md（更具体）优先于本文件（更宽泛）。

## 本机 DSH 内置能力（重新扫描确认）——直接调用，勿为此装第三方插件

以下能力 DSH 桌面端**原生自带**（@deepseek-ai/dsh-* 内置插件），优先直接使用：

### 联网
- 内置 **web_search** 与 **web_fetch**（dsh-tool-web / dsh-web-fetch-http / dsh-web-search-deepseek 提供）。查资料、抓页面优先用它们；必要时可经 shell（pwsh+curl）抓正文。
- 不要为"联网"装插件。

### 文件与代码
- read / write / edit / glob / grep（文件系统工具）；pwsh（PowerShell）、bash 执行。
- 生成、修改、检索、执行脚本都原生可用。

### 并发与编排（Codex 式多并发）
- 子代理：**subagent / subagent_fork**（并行委托）、send_message、interrupt_agent、list_agents（这俩工具无路由参数，恒继承主路由；子代理默认模型规则见「任务默认调度协议」）。
- 工作流：**workflow**（fan-out 编排）、ralph（fresh-agent 迭代）。
- 后台任务：job_kill / job_list / job_output（长命令/后台运行）。
- 已设 **agent-loop.maxParallelToolCalls: 99**——同类可并行小任务请并发处理。
- 不要为"并行/多 worker"再装插件：并行编排 + 质量门禁已由已装 AgentTeams（默认调度制）承担，见「任务默认调度协议」。

### 目标 / 任务 / 计划
- 目标：create_goal / get_goal / update_goal；任务：todo_write（总览胶囊）；任务执行调度：**AgentTeams 默认**（见「任务默认调度协议」）；计划：plan 模式（DSH 内置 dsh-plan-mode）。
- 进度用 todo + 阶段汇报（内置 TodoPanel 胶囊随 todo_write 自动出现在回复内——Codex 式勾选清单，零插件；每轮请先 todo_write 再汇报，不要只用文字列进度）。

### 多媒体与视觉
- 图片：read_image；附件/图片展示：dsh-client-ui-attachment；主题/美化：dsh-client-ui-theme（内置换肤）。
- （注：record-browser-gif / preview-tour 为旧环境预览类技能，当前未安装，勿依赖。）
- 视觉结果优先以图片内联展示；主题、贴图附件直接用内置，不必为"看图/主题"装第三方插件。

### 视觉能力（pro 主代理无视觉 · 2026-09-04 实测定案，方案 D 组合）
- **通道 0（聊天框拖图自动分流，2026-09-04 装）**：dsh-vision-fallback 插件——pro 主模型下拖图/粘贴图片自动交给 deepseek-v4-flash-vision-exp（settings.yaml `vision-fallback:` 段配置：baseURL=api.deepseek.com、apiKeyRef=DEEPSEEK_API_KEY、mode=auto），以隐藏上下文回传，UI 原图保留；主模型切视觉模型时自动让路。**二次排查记录（同日）**：初装致桌面端启动失败，根因=profile 内 dsh-credentials/dsh-home-paths 0.1.0-rc.6 与宿主 0.1.1-rc.2 错位 + 遗留坏插件 deepseek-pet（已卸载）；已用 pnpm 对齐两包至 0.1.1-rc.2 并重装，宿主 API 预检通过（agent/pre-step、resolveModelInfo 均在；settings.installSection 缺失但插件自带 register 回退），待重启验收。回滚：`dsh plugin remove dsh-vision-fallback` + 还原 package.json.bak-20260904-150608。
- **事实**：主代理 `deepseek-v4-pro` 不声明图像输入，调 read_image 会被本体拒绝（`does not declare image input`）；本机唯一视觉模型 = `deepseek-v4-flash-vision-exp`（官方文档 https://api-docs.deepseek.com/guides/vision/ ，支持 JPEG/PNG/GIF/WebP，base64 data URL，48MiB 上限）。
- **通道 1（自动化管道，默认）**：`F:\Godot\tools\ds-vision.ps1`——截图（全屏 / `-WindowTitle` 窗口 / `-Region` 区域）或 `-Image` 传图 → flash-vision-exp → 文本或 `-Json`。调用：`powershell -NoProfile -ExecutionPolicy Bypass -File F:\Godot\tools\ds-vision.ps1 ...`（本机执行策略 Restricted，须带 Bypass）。实测：探针图→Red，区域截图→White。
- **通道 2（正式视觉评审）**：建团队时加 visual-reviewer 成员（默认路由即 flash-vision-exp；已实测成员可用内置 read_image 真看图并感知颜色），按质量门禁出结构化结论。
- **通道 3（人想看）**：GUI 输入框模型选择器手动切 deepseek-v4-flash-vision-exp 贴图。
- **回滚要点**：视觉结论来自 flash 档模型，重大美术/UI 定案仍由主代理综合判断；不想要时删脚本与本节即可。

### 外接能力
- **MCP client（dsh-mcp-client）已内置**：已配 netease-music；游戏/视觉可再按需加 filesystem、Playwright、浏览器截图等 MCP server。
- 配置在各工具的 mcp 配置（.mcp.json / .codex/config.toml / .claude/settings.json）。

### 技能
- skill 工具 + 技能目录：<projectRoot>/.dsh/skills（rank100）、<projectRoot>/.agents/skills（rank200）、customSkillDirs（300）、<dshHome>/skills（400）。
- 项目级技能放 <projectRoot>/.agents/skills/<name>/SKILL.md。

### 沙箱与权限
- fs / bash / pwsh 沙箱 + 沙箱策略（审批、权限模式）。路径、命令执行受当前权限模式约束；被拦时不升级，改走替代路径或说明。

### 会话 / 持久化 / 压缩
- session 持久化、checkpoint、compaction（上下文压缩）、spill。

## 我的主力工作：Game Jam 48h（48 小时游戏开发）+ 准备工作与学习

这是当前最高优先级场景。请围绕"快速出可玩、能迭代、能被评审看到"组织工作。注意：提速靠并发与切分，**不靠降低思考强度**——设计、验证、测试步骤不做表面功夫，只是不做无关的过度工程。

### 工程约定
- 优先选能跑起来的栈，避免在 jam 里引入需要长时间构建/配置的新工具链。
- 游戏用尽可能少的运行时依赖；美术/音效用程序化、占位图或免费资产可替代方案优先。
- 开发节奏：先**深度思考**定下核心循环、接口与数据流（这一步不可省、不可并发），再按 vertical slice 快速实现："不要先搭大框架"指不做无关的过度工程，而非跳过设计。
- 48 小时按阶段分：立项(≤2h) → 核心循环(≤12h) → 打磨与内容(≤24h) → 提交修 bug(最后 6h)。请主动提醒我当前处于哪个阶段、下一步最小动作是什么。

### 代码与工具偏好
- 保持脚本/代码可在 PowerShell (Windows) 直接运行；路径用原生 Windows 形式，注意编码（UTF-8）。
- 优先小步、可回退的改动，每个 step 给出"现在能跑/能看"的结果。
- 涉及资源文件（贴图/音频/字体/预制体）时，先确认路径与导入方式，避免静默失败。

## 我偏好的 Agent 工作方式（尽量贴近 Codex 风格）

### 并发 ≠ 降思考（关键约束）
- 高并发只用于**相互独立**的叶子子任务（素材/贴图/音频生成、独立文件或模块、可并行测试、批量预览）。每个 subagent 独立上下文、独立思考，不降智。
- **根任务保持顺序深度思考**：核心循环、架构/接口/数据流决策、集成与验收，由主线程串行深想，绝不并发赶工。
- reasoningEffort 保持 max（settings.yaml 实测：agent-default-model.reasoningEffort = max）；提示词**不得**诱导模型"少想/快出/别验证"——提速一律来自并发与切分，不来自压缩思考。
- 验收/测试不可省：并行产出后必须合入验证（团队模式由独立 review 成员强制门禁；轻量例外时再用子代理并行做审查，如 dsh-review 思路）。

### 任务默认调度协议（AgentTeams 标准 · 2026-08-31 用户新规：默认 Team，轻量仅限明示例外）
用户发来任何**可执行任务** = 已发布。**默认全部走 AgentTeams 质量标准**（approval="required" 计划制），主代理自动执行：
1. **判定例外**：仅当用户**明确表示**不需要 Team（"不用 team / 轻量 / 直接做 / 不要拆"等）时，降级为原生路线（原"任务自主拆分协议"：subagent/subagent_fork 并行 + 主线程集成验收）。**未明示 = 走团队**，不得自行降级。
2. **团队设计**：agent_teams_create（approval="required"）→ 按任务配 roster（如 researcher / engineer / reviewer；执行与审查尽量分成员，审查者可独立配更严模型或 route）→ 设计任务 DAG（质量链 requirements → implementation → verification → review → integration，每环可多轮）→ 每个质量任务写全契约（objective / acceptance / verify 命令 / inScope / outOfScope）。

**子代理默认路由（2026-09-04 用户新规：默认 flash-vision，不再继承队长 pro 路由）**：默认情况下，所有子代理（AgentTeams 成员）使用 `provider=deepseek-official`、`model=deepseek-v4-flash-vision-exp`（v4flashvision，实验视觉版），reasoningEffort 省略（自动取该模型目录默认档）。创建成员时必须在 add_member / edit_plan 显式传这两个字段；仅需要更强推理的角色（深度设计、核心 review、架构类）才显式改回 `deepseek-v4-pro`。原生 `subagent`/`subagent_fork` 工具无路由参数、恒继承主路由（无法切 flash）；`workflow` 的 phase/agent 级 provider/model 与 `taskboard_create` 的 model 固定同样默认填 flash-vision-exp。
3. **计划展示**：首条回复列出 ① 团队与角色 ② 任务图与依赖 ③ 各任务验收标准，**等待用户 Approve 后才执行**（批准前不得 spawn / claim）。
4. **运行监督（captain）**：批准后 scheduler 自动派活；我用 agent_teams_status 跟踪、send_message 指导/纠正、必要时 reassign_task 换人；不做与成员重复的工作；每条进度用 todo 做总览。
5. **集成验收**：成员产出合入后由主线程复核（静态→结构→运行），不合格打回（review 门禁自动 reroute 到 repair + 下一轮 review，直到 pass 或 escalate）；禁止"成员说完成即交付"。
6. **收尾**：交付附「团队执行摘要」（任务数/各自状态/评审轮次/验收结果）；工作完成后 agent_teams_delete 清理。
硬边界（保留，防矫枉过正）：架构/接口/数据流决策、根因诊断链、最终集成验收——由主线程（captain）串行深想，绝不外包给并发成员。
纯咨询/问答（聊天讨论、无执行交付）不算"任务"，不建团队；规则/文档类小改（本文件、skill 等）可直接执行。

**边界澄清（2026-09-04 补，堵今日漏洞）**：
- **凡会改动本机系统配置/注册表/包管理/插件安装/环境变量的任务 = 可执行任务，一律默认团队**（最小计划：1 个执行+1 个评审/审计，如无明确契约要求则 kind=work 亦可）；绝不以"运维诊断、动作小、我已备份"为由自行降级——豁免权只在用户。
- **直接执行清单（仅此两类）**：① 纯咨询/问答；② 规则、文档、skill 类小改。其余全部走团队。
- **角色模型分配**：实现类成员默认 flash-vision-exp（见路由规则）；**评审/审计/深度 review 类成员显式改回 deepseek-v4-pro**（更强的独立判断力）。
- **变更类任务的收尾环节**：主线程复核后，跑一轮最小独立审计（1 成员，只读，对照契约逐项 PASS/FAIL + requiredFix）作为门禁；审计通过才算交付，之后 agent_teams_delete。
- **开工前自检**：收到可执行请求，第一步自查"是否属于直接执行清单"——不属于则立即 agent_teams_create（approval="required"）并展示计划，绝不先动手。

- 多并发：默认由 AgentTeams 任务图/DAG 承担；仅轻量例外时（用户明示），同类可并行小任务尽量并发（maxParallelToolCalls 已满，再加用 subagent 并行）。
- 聊天区显示图片：视觉结果（截图、渲染图、生成图、UI 预览、图片对比）优先以图片形式交付；用内置附件/图片展示，必要时 lightbox 增强。
- 进展可视化：复杂/多步任务给出任务列表（todo）与阶段进度，并按阶段汇报。能用图表/预览说明的不只写文字。

## 技能与工具使用
- 优先用已安装 DSH 技能；项目级技能放 <projectRoot>/.agents/skills/ 或 <projectRoot>/.dsh/skills/。
- 需要外部能力时优先用 MCP server（已配 netease-music；游戏/视觉再按需加 filesystem、Playwright、浏览器截图等）。
- 涉及"评审/预览/截图"时优先内置能力（read_image / 附件与图片展示）；旧预览类技能（record-browser-gif、preview-tour）当前未安装，勿假设可用。

### Skill 触发规则（防漏装/漏用）
- omubot 仓库任务（kragcola/omubot 或其克隆/工作区）：先加载对应 skill（omubot-admin-console / omubot-deep-delivery / omubot-continuity / omubot-design-system；仓库内 .agents/skills 为权威副本，优先级高于全局）。
- 交付/修复/验收类任务：先按 game-acceptance 五轴清单执行（全局 godot-deep-delivery 提供验证矩阵），禁止以"看起来可以"收尾；每个修复必须回归并留证据。
- 全局已装方法论（Godot 适配版）：godot-deep-delivery、godot-continuity（按需加载完整版）；omubot 仓库任务走仓库内权威副本（omubot-admin-console / omubot-deep-delivery / omubot-continuity / omubot-design-system），仅在 omubot 仓库内生效。
- 外部资产获取（纹理/图集/图标/字体/音效素材、用户要求"从互联网获取资产"、新项目评估资产可获取性）：先加载 `godot-asset-sourcing` 并按渠道矩阵实测；**未实测前禁止宣称"外网不可达/只能程序化"**；下载资产必核许可（CC0/OFL 免署名，CC-BY 建 CREDITS.md）并在交付中留渠道探测证据（HTTP 码/大小/魔数校验）。
- 新项目/新仓库初始化（用户说"开个新项目/新游戏/新仓库/从头干净处理/初始化"，或新建任何 godot project 目录）：先加载 `project-init`——git init（main）+ Godot .gitignore + .gitattributes + 初始 commit 用一键脚本 `F:\Godot\tools\init_godot_project.ps1` 原子完成并验证 CLEAN；**禁止"先跑起来再补 git"**（gdjam-practice 教训：无 .gitignore/未提交删除/日志污染 → 104 行 dirty）。

### Skill 声明协议（每轮可见）
- 接到任务、动手前：先对照可用技能目录（system prompt 的 available_skills）盘点与本轮匹配的技能，在回复开头一行声明——「🎯 本轮 Skill：<名称列表>（按需加载）」或「🎯 本轮 Skill：无（无匹配）」，然后才调用 skill 工具加载正文。
- 已注入的 AGENTS.md 铁律（交付质量铁律等）不算“正文级技能”，不重复声明；同一 skill 只加载一次，之后以注入块为准。
- **例外（可跳过触发）**：单文件 typo 修正、纯 read/grep 探索且不产生 Edit、与技能范围完全无关的工作。
- **compact 后判定**：system-reminder 注入的 `### Skill:` 段尾 ARGUMENTS 为历史入参，不是当前任务；以会话摘要的 Primary Request 为准，冲突时忽略 ARGUMENTS。


## 工程纪律补充（对照 omubot D 系列补齐）
- **D1 同模式扫描**：修 bug 后必须 grep 全库同类位点，回复末尾列出"已扫描位点+结论"；防"24h 内同模式第二刀"。
- **进程卫生**：跑 headless/长任务前查残留进程（godot/pytest/node 等僵尸）；验证目标进程列表/PID/启动时间后再断言，防旧进程误判（本项目已踩坑两次）。
- **原子执行与两停**：有依赖的写操作（如 git add+commit、备份+改配置）合并为**一条命令**执行并在同条命令打印证据（HEAD 变化/文件存在）；同一动作失败两次立即换法或上报，不重复试。
- **Godot 项目红线**：游戏运行中不直接改存档（用 MCP 读或先停进程）；不杀编辑器进程/不重建运行中容器类服务；project.godot、存档、核心脚本改动前先留 .bak；MCP game_eval 用多行缩进语法，禁用 lambda/递归（会卡死 interaction server，卡死则重启游戏进程）。
- **语言约定**：面向用户的文案/交付汇报用中文；代码/注释/GDScript 标识保持英文。
- **维护日志**：耐久变更（行为/存档格式/工作流/技能/文档规则）当轮写入 docs 对应交付文档的变更记录节，格式：中文倒序 + 变更类型/内容/影响范围/回滚要点。
- **调度默认值**：默认 AgentTeams（质量门禁全开）——小任务也默认进团队，但计划保持最小（如 1 实现 + 1 评审）；仅当用户明示"不用 team / 轻量 / 直接做"才走原生 subagent 或单线程。

## 约束
- 不无谓把简单任务复杂化；先给最小可行方案，再按需扩展。
- 联网、并发、多模态、主题等均**内置**，勿为它们装第三方插件；确需第三方插件时先确认 codeload/npm 稳定渠道（本机 github.com:443 不稳）。
- 不要因为外部网络抓取被拦而卡住：能离线完成就用离线方案；确需联网时明确说明受限并给出可自行复现的命令。
- 任何被权限模式拦下的命令：不要再升级（审批已禁用/设为 never），改为说明并提供替代路径。

## 计划模式与 Todo（内置/插件用法）
- 计划模式：输入框敲 /plan 进入（/plan off 退出）；激活后计划审查 UI 出现。复杂任务请求时先计划、批准后执行。
- Todo：DSH 内置 todo_write + TodoPanel 胶囊（回复内自动出现勾选清单）；@dennisrongo/dsh-todo（独立 Todo 页签）当前未安装，勿假设可用。

## 交付质量铁律（提炼自 omubot deep-delivery/continuity 技能）
- **主动，不躺平**：能自己查到/搜到的绝不问用户——先读仓库/文档/日志，外部当前事实用内置 web_search 主动检索（"不会主动去搜索"是明确要修正的毛病）。
- **先复述再动手**：执行前用自己的话复述目标与验收标准；可能理解错就先抛出来，别改完才发现。
- **不报"完成"前重读自己**：重新打开改过的文件确认编辑真的达成目标，而不是只信工具返回成功。
- **自己验证，别把测试甩给用户**：静态（build/lint/typecheck）→结构（计数/字段/清单）→语义（核心含义）→运行时（只读 API/端点）；外部写入/发消息需当前任务授权，否则离线 fixture/dry-run。
- **先尝试再升级**：一种方案失败就诊断换方案；升级用户前带证据（试了什么、为何失败）。
- **来源优先一手**：技术/流程主张用官方文档；用到 web 时在结论中标注来源。
- **假设清单 + 最小复现**：把风险假设转为检查/白名单/干跑；交付要有可复现的证据与残余风险说明。
## 当前插件与工具状态（2026-08-31 实测 · 变更时更新本节约）
- 桌面端：DSH Desktop 2.0.3，profile=desktop；已装 **11 个插件**（10 之前 + dsh-vision-fallback 0.10.0；曾试装 @linxin666/dsh-client-ui-task-board 因其 engines.dsh>=0.1.2-alpha.1 在 0.1.1-rc.2 上 UI 未挂载，已换掉）：
  @zhuchenglong/dsh-side-chat（侧边对话）、dsh-at-any（@file 提及）、dsh-codex-timeline（回合时间线）、dsh-file-upload（拖拽文件→chip）、reasoning-slider（推理强度滑块）、@nanmicoder/dsh-agent-teams（多代理团队+任务板；**默认调度制**，见「任务默认调度协议」；并行调度已于 2026-08-31 实证：3 个无依赖任务同帧分发给 3 成员同时 working → 汇合任务依赖门禁自动解锁 → 4/4 completed 一次通过，DAG 模式=并行叶子+汇合点）、@wxg-prc-cpg/browser-skill-dsh-plugin（BrowserSkill 浏览器）、dsh-cost-meter（成本/余额）、dsh-mermaid（MrmoLabs 版）。验收文档：F:\code\dsh-plugin-acceptance.md。
- **例外（勿装）**：@ch4acko3/dsh-turn-fold + dsh-harmony——桌面 2.0.3 无 Harmony Host，装上桌面无法启动（已实测）；dsh-plugin-appshot 需 .NET SDK 构建原生组件，暂缓。
- **工具限制**：glob / grep 当前不可用（"ripgrep launch failed"，打包运行时缺 <runtime>-rg 伴随文件）；先用 pwsh Get-ChildItem / Select-String 替代。
- **task-ui 技能**的 task_add/task_list/task_update/task_delete 全局任务库工具未注册（宿主插件未装）；任务清单用内置 AgentTeams（agent_teams_*）。
- MCP：netease-music 已配（F:\code\.mcp.json，项目级）。
- **网络代理基线（2026-09-04 修复重启断网）**：HTTP_PROXY/HTTPS_PROXY/ALL_PROXY（用户级环境变量）指向 http://127.0.0.1:58223 —— LibCyber Desktop 的固定本地端口（`C:\Users\王\AppData\Roaming\pirate\config.yaml` 首行 `port: 58223`，非随机）。已注册 HKCU Run 开机自启：`LibCyberDesktop` → `"F:\Libcyber\LibCyber Desktop\LibCyber Desktop.exe"`，重启后代理监听自动恢复，无需手动开软件。Clash Verge 与此无关（system proxy 关闭），保持不动。2026-09-04 追加：系统代理（WinINET）已开启指向 127.0.0.1:58223（ProxyOverride 旁路 localhost/127.*/内网/<local>/腾讯系域名 *.codebuddy.cn *.tencent.com *.qq.com 等；LibCyber 核心规则对腾讯域本就 DIRECT），Chromium/Electron 类应用（浏览器、WorkBuddy/CodeBuddy）亦走此代理；LibCyber 退出时浏览器会断外网，由开机自启兜底。WorkBuddy 报"账号和积分获取失败"与网络无关（TCP/端点全通，腾讯域直连）——优先查登录会话过期。2026-09-04 审计补记（posthoc-audit 团队发现）：WinINET 三项曾于 14:56 被 LibCyber 重启清空（其系统代理开关为关时启动会重置为直连）——已重写并复核（ProxyEnable=1 等），**持久化需在 LibCyber GUI 打开「系统代理」开关**，否则每次其重启都会再次清空；auditor 审计结论：网络修复其余项 PASS、视觉插件二轮修复全 PASS，残余风险=插件待重启验收、cost-meter 双 credentials 实例待观察、web-search-pro 从依赖树消失（不在 10 插件清单内，内置 web_search 不受影响）。若重装/更换代理软件：同步改端口、环境变量与本条。

### 历史插件说明（当前均未安装，装回前勿假设可用）
- **dsh-task-status（@vlln）**：输入框上方后台任务状态条（计数+tail 轮询）；现未装，后台任务状态以内置 jobs 查看。
- **dsh-ds-attach（wqx-txdsyl，v0.1.0）**：DS 风格文件卡片附件（回形针/拖拽→解析→注入文本）；现未装，附件走内置 ui-attachment。
- **dsh-pocket（v2.8.0）**：手机远程访问（局域网扫码+8 位密码；公网 cloudflared 隧道）；现未装，如需再装并补防火墙放行。
- **dsh-popout-sidebar（v1.0.1）**：产物侧栏+GFM 编辑增强；现未装，产物展示用内置附件/预览。
- **代码质量五件套**：dsh-forge-gates（forge_math/logic/regex/eprover/system/repair/run/fs/net）、dsh-evidence-first、dsh-review（adversarial-review）、dsh-command-code-review（/code-review）、dsh-multi-candidate；现均未装，使用前先装回。
