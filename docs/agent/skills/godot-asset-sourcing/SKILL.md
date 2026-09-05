---
name: godot-asset-sourcing
description: 游戏资产获取（source/fetch）技能：成熟渠道矩阵（Poly Haven 全程序化 API、Kenney zip、Godot Asset Library、OpenGameArt、game-icons、OFL 字体通道）+ 可达性探测 + 端到端下载校验 + external/ 目录规范 + 许可台账（CC0/OFL/CC-BY CREDITS.md）。用于项目需要外部纹理/图集/图标/字体资产，或用户要求"从互联网获取资产/找素材"时；也用于新项目初始化时评估资产可获取性。
whenToUse: 出现"资产获取/素材下载/找纹理/外部资产/贴图来源/字体下载/CC0 素材"等需求；用户要求资产从互联网获取；本地想用外部纹理替代程序化效果；或有人准备宣称"外网不可达/只能程序化"之前（必须先跑本技能渠道探测）。
---

# Godot 资产获取（Asset Sourcing）

把"获取外部游戏资产"做成可复制流程：**先实测渠道，再决定获取方式**；禁止在未探测前宣称"外网不可达"。

## 硬规则（违反即打回）

1. **先探测再断言**：宣称任何渠道"不可达/被墙/404"前，必须用 curl 实测并记录 HTTP 码；失败先对照 §6 失败对照表定原因（区域封锁 / 站级反爬 / URL 错误 / 参数错误），换渠道或换参数，不得直接放弃。
2. **只入合法许可**：CC0、OFL、MIT 类免署名；CC-BY 必须保留署名文件（external/CREDITS.md 记录作者+许可+URL+日期）；许可不明禁止入库。
3. **下载即校验**：`size > 0` + 魔数（jpg=255,216,255 / png=137,80,78,71 / zip=80,75,3,4）；校验失败视为文件损坏，删除重下。
4. **命名与落盘**：外部资产统一放 `assets/<game>/external/<category>/`（可与现有目录约定合并），纹理保持原名+许可信息；不覆盖程序化实现，无必要时不动 shader。
5. **Godot 导入纪律**：`.import` 由编辑/headless 扫描生成（`godot --headless --editor --quit`）；代码引用一律 `res://`；4.4+ 记得 `update_project_uids` 或重存资源。

## 渠道矩阵（2026-08 实测；时过境迁以 §2 探测流程复核）

| 渠道 | 许可 | 获取方式 | 状态备注 |
|---|---|---|---|
| **Poly Haven** | CC0 | **全程序化 API**：`/assets?t=textures&categories=<词>` 清单 → `/files/<slug>` 直链 → `dl.polyhaven.org` 下载 | 首选自动化源；1k JPG ~600KB；含 PBR 通道（normal/roughness） |
| **Kenney.nl** | CC0 | 页面 `kenney.nl/assets/<slug>` → 正则提取 `media/pages/assets/<slug>/<hash>/<pkg>.zip` → 解压 | zip 直链可达（实测 439KB 200）；图集/像素/UI 用材天堂 |
| **Godot Asset Library** | 混合 | 编辑器内 **AssetLib 面板（零代码人工）**；REST `godotengine.org/asset-library/api/asset?filter=<词>&godot_version=4.x`；新商店 `store-beta.godotengine.org` | 旧 API 条目数少（~63）；Godot 专用资源用它 |
| **OpenGameArt** | CC0/CC-BY | 站内高级搜索（`art-search-advanced?keys=<词>&field_art_type_tid[]=<tid>&field_art_licenses_tid[]=<tid>`） | tid 数值必须先从页面表单抓（贴图 tid=9 之类不可靠）；社区散件好去处 |
| **game-icons.net** | CC0 | 直链 `/icons/{fg}/{bg}/{size}x{size}/{name}.png` | 文件名/大小写敏感，先站内搜索确认 slug |
| **字体（OFL）** | OFL | jsdelivr `cdn.jsdelivr.net/gh/<repo>@main/...` 或 `raw.githubusercontent.com/<repo>/main/...`；可走 npm 包（`cdn.jsdelivr.net/npm/<pkg>`） | 霞鹜文楷/思源宋体为水墨/中文首选；全字库 ~20MB 可按需子集化（fonttools pyftsubset） |
| ~~itch.io~~ | — | — | **区域封锁**（实测 000 超时），不依赖 |
| ~~Google Fonts / Google 系~~ | — | — | 同上（000 超时）；OFL 字体改走 GitHub/jsdelivr |
| ~~ambientCG / pixabay / unsplash / openclipart API~~ | — | — | 站级反爬/需 token（404/400/503/401），已废弃，不再尝试 |

## 首选流程：Poly Haven 程序化三步（PowerShell 5.1 兼容模板）

```powershell
# 0) 探测（先于一切；200 后再继续）
curl.exe -sS -I -L -m 15 "https://api.polyhaven.com/assets?t=textures&categories=water" | Select-String "HTTP/"

# 1) 清单 → 挑 slug（ConvertFrom-Json；数组逐元素遍历）
$assets = curl.exe -sS -L -m 20 "https://api.polyhaven.com/assets?t=textures&categories=water" 2>$null | ConvertFrom-Json
$assets | ForEach-Object { $_.PSObject.Properties.Name + " | " + $_.PSObject.Properties.Value.name }

# 2) 直链（结构：Diffuse -> {1k|2k|4k|8k} -> jpg -> {url,size}；非 resolutions！）
$f = curl.exe -sS -L -m 20 "https://api.polyhaven.com/files/<slug>" 2>$null | ConvertFrom-Json
$dl = $f.Diffuse["1k"].jpg.url

# 3) 下载 + 校验（Start-Job 避免超时卡死；`$var: 冒号紧邻必须用 ${var}: 写法`）
$job = Start-Job -ScriptBlock { param($u) curl.exe -sS -L -m 90 -o "<dest>" -w "code %{http_code} got %{size_download}" $u } -ArgumentList $dl
Wait-Job $job | Out-Null; Receive-Job $job; Remove-Job $job
$b = [System.IO.File]::ReadAllBytes("<dest>")[0..2]; Write-Output ($b -join ",")   # 255,216,255 = jpg 有效
```

**PS 5.1 避坑**（本技能沉淀）：`ForEach-Object -Parallel` 不可用（按顺序测）；`$var: $x` 会被解析成变量作用域 → 用 `${var}:`；curl 每次 `-m` 限时；长下载用 `Start-Job` 后台；`curl.exe` 返回码用 `$LASTEXITCODE`。

## Kenney zip 流程

```powershell
$page = curl.exe -sS -L -m 15 "https://kenney.nl/assets/<slug>" 2>$null
$zip = ($page | Select-String -Pattern 'https?://[^"'']+\.zip' -AllMatches).Matches.Value | Select-Object -Unique -First 1
curl.exe -sS -L -m 120 -o "$env:TEMP\k.zip" $zip
# 校验魔数 80,75,3,4 后解压：tar.exe -xf k.zip -C <dest>（Win10+ 自带）
```

## 落地与台账

- 落盘：`assets/<game>/external/`；同目录 `CREDITS.md` 记录：来源 slug/URL、许可、作者、下载日期、用途（CC-BY 必填）。
- shader 采样替换：外部纹理仅作可选项时，shader 先留 `uniform` 入口（如 `paper_tex`/`water_tex`），拿到纹理后以 `texture()` 采样混合程序化层，零破坏回退（删除文件即回程序化）。
- 字体：`fonts/` 放 ttf（中文需含中文字符集），Theme `default_font` 指向；标题/HUD 换字体时保持字重与现有风格一致性（见审美技能）。

## 失败对照表（先定因，再行动）

| 现象 | 定因 | 行动 |
|---|---|---|
| `000` 超时 | 区域封锁（itch/Google 系） | 换镜像（jsdelivr/rawgh）或换渠道；不硬刚 |
| 400/403/503 | 站级反爬/风控 | 换渠道；不要重试超过 2 次 |
| 404 | URL/slug/文件名错误 | 先站内搜索（search 页/表单）拿真实 slug |
| 200 但空结果（total 0） | 搜索参数错（tid/category/filter 词） | 用页面表单实际提交抓参数；换关键词 |
| 下载后过大/过小或魔数错 | 文件损坏/代理污染 | 删除重下；校验失败即记录 `$LASTEXITCODE` |

## 交付前验证清单

- [ ] 渠道探测证据（HTTP 码+大小）写入交付说明
- [ ] 文件魔数校验通过
- [ ] CREDITS.md 台账完整（含许可）
- [ ] Godot 导入零报错（headless `--editor --quit` 扫 `.import` 无 ERROR）
- [ ] 截图/运行目视确认（替代程序化的部分视觉达标；未达标回退程序化并说明）

## 参考

- `create-game-assets`（gamedev-skills 系列）：sourcing 理念（先盘点再获取、asset manifest、许可白名单）
- 本项目实测证据文档：`docs/assets-sourcing.md`（渠道矩阵+逐条测试记录，作为历史证据留存；本技能为通用可移植版）
