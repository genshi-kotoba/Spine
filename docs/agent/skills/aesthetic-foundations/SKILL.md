---
name: aesthetic-foundations
description: Inject aesthetic principles from painting, photography, graphic design, and Eastern visual tradition into any visual/design decision. Use when reviewing UI/UX, making typography/color/layout/spacing choices, evaluating a screenshot, or when user asks "does this look good" / "how to improve this design" / "审美". Loads composition theory (rule of thirds, visual weight, leading lines), color theory (Munsell, Albers, Itten 7 contrasts), grid systems (Müller-Brockmann, 8pt), Gestalt hierarchy, ma/negative-space, and references masters (Vermeer, Mondrian, Rothko, Hopper, Sargent, Bresson, Avedon, Saul Leiter, 杉本博司, Rams, Vignelli, Tschichold, Saul Bass, 原研哉, 八大山人, 倪瓒). Not a web/CSS framework checklist — complements rather than replaces frontend-design.
license: MIT (see LICENSE)
---

# Aesthetic Foundations

这个 skill 在你接到视觉判断任务时, **先把审美词汇激活**, 然后再开始评审或建议.
没有它的话默认会滑回"通用 web 风格": 圆角、Material 阴影、彩虹色 badge — 那不是审美, 那是肌肉记忆.

---

## 触发后第一件事

**别立刻给答案. 先做一次 [critique-protocol](critique-protocol.md) 7 步走**:

1. 三秒第一印象 — 眼睛先落在哪?
2. 眯眼测试 — 层次还在吗?
3. 灰度测试 — 转黑白还能不能用?
4. 留白测试 — 空白是"意味" 还是"没填满"?
5. 裁剪测试 — 能砍掉什么?
6. 大师参照 — 哪条原则被违反 / 被尊重?
7. 改动清单 — 3-5 个具体动作, 不要"再干净一点"

详见 [critique-protocol.md](critique-protocol.md).

---

## 加载哪些 reference (按主题)

| 任务 | 必看 |
|---|---|
| 布局 / 构图 | [references/composition.md](references/composition.md) + [references/grid-and-rhythm.md](references/grid-and-rhythm.md) |
| 色彩 | [references/color.md](references/color.md) |
| 字体 / 排印 | [references/typography.md](references/typography.md) |
| 信息层级 | [references/visual-hierarchy.md](references/visual-hierarchy.md) |
| 空 / 留白 | [references/ma-and-negative-space.md](references/ma-and-negative-space.md) |

---

## 加载哪些 master (按情境)

| 情境 | 看谁 |
|---|---|
| 光与窗 / 单光源场景 | Vermeer (painters.md) |
| 平衡 + 非对称 | Mondrian, Bada Shanren (painters.md / 中式审美.md) |
| 用色块情绪 | Rothko (painters.md) |
| 决定性瞬间 / 几何瞬间 | 布列松 (photographers.md) |
| 隔离主体 / 极简肖像 | Avedon (photographers.md) |
| 工业克制 / 功能美 | Dieter Rams (designers.md) |
| 网格 + 极少字体 | Vignelli (designers.md) |
| 留白 / 东方极简 | 原研哉 + 中式审美.md |
| 中式语境 / 项目用中文 | [masters/中式审美.md](masters/中式审美.md) **优先于** Bauhaus |

---

## 不变量 (别忘了)

- **审美不是规则集** — 是张力. 三分法 vs 居中, 网格 vs 破格, 都对, 看情境.
- **先看后说** — 任何"建议"前必须先描述眼睛实际看到的 (眼动 / 焦点 / 层次), 不要直接跳到 "建议把 padding 加到 16px".
- **不要逃进 hex** — "把 ink3 改成 ink2" 是 token 操作, 不是设计判断. 判断是: "这里需要更弱的灰让标题更突出".
- **数量级而非数值** — "留白翻倍" 比 "padding 24→48" 更靠近设计语言. 像素是结果, 不是输入.
- **不与 frontend-design 抢活** — 那个 skill 管"web UI 是否符合工程规范". 这个 skill 管"为什么这样组合好看".

