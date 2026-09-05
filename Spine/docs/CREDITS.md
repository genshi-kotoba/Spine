# CREDITS — 外部资产许可台账

本目录记录本项目（Spine / C3 层）引入的外部资产来源与许可。遵循 godot-asset-sourcing 规范：外部资产必核许可并联证。

## Kenney Input Prompts — 「E」交互提示键帽图标

- **资产名**：Input Prompts（Kenney Input Prompts，1.5A 版本包）
- **文件**：`assets/ui/e_key.png`（取自包内 `Keyboard & Mouse/Default/keyboard_e.png`）
- **来源**：https://kenney.nl/assets/input-prompts
- **下载校验**：https://kenney.nl/media/pages/assets/input-prompts/8de120163f-1783763952/kenney_input-prompts_1.5.zip（HTTP 200，5070075 bytes）
- **作者**：Kenney（www.kenney.nl）
- **许可**：Creative Commons Zero（CC0，public domain）—— 免署名；来源/作者为可追溯性记录，非署名要求。
  - 许可原文见包内 `License.txt` 与 https://creativecommons.org/publicdomain/zero/1.0/
  - 用途：C3 前置需求①「E 提示」——角色靠近可交互 item 时头顶显示的键盘风「E」键帽图标（纯视觉提示，不新增输入映射）。
- **CC0 说明**：可自由用于个人/教育/商业用途，无需署名；本台账为合规可追溯而保留记录。

## Kenney Particle Pack — 呼吸气泡爆裂环

- **资产名**：Particle Pack 1.1（仅使用 `circle_03.png`）
- **文件**：`assets/fx/bubble_pop_ring.png`
- **来源**：https://github.com/Calinou/kenney-particle-pack/tree/master/addons/kenney_particle_pack
- **下载校验**：SHA-256 `5c0d9704ed222df863a6a8602dca952ffcd04421136ea439a0be2f257ebb8c73`
- **作者**：Kenney Vleugels（Kenney.nl）
- **许可**：Creative Commons Zero（CC0 1.0，public domain）；许可原文见来源仓库 `LICENSE.txt` 与 https://creativecommons.org/publicdomain/zero/1.0/
- **用途**：C3 呼吸机制中气泡容量耗尽后的环形闪光。液体填充、惯性漂浮与液滴爆散均由本项目 `Bubble.gd` 程序化生成。

## 用户提供 — C3 单图主场景

- **资产名**：`c3.png`
- **原始文件**：`/Users/kragcola/Downloads/c3.png`（源文件保留在下载目录，未覆盖）
- **文件**：`assets/background/c3_main.png`
- **处理**：裁切原图 `y=117..544`（含端点），去除上下白边及边界抗锯齿行，输出 `2172×428` 单张横向场景；不再拆分房间。
- **许可/来源说明**：由用户在本地下载目录提供；本记录不将其声明为外部公共许可资产。后续对外分发前需由项目方确认原始来源与授权。
