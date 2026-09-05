# 字体 — 文字也是图像

字体不是"选个好看的字" — 是给文字以**形体、节奏、温度**.

文字一旦上屏就成了图像. 设计字体 = 设计这张图像.

---

## 1. 衬线 vs 无衬线 vs 等宽 — 语义负载

每类字体携带历史和语义, 不是中性的.

| 类别 | 例子 | 携带的语义 | 用途 |
|---|---|---|---|
| Old Style Serif | Garamond, Caslon, Bembo | 文艺复兴 / 文学 / 历史 / 优雅 | 长正文, 文学 / 文化项目 |
| Transitional Serif | Baskerville, Times | 启蒙时代 / 报刊 / 知识 | 新闻 / 教育 |
| Modern Serif | Bodoni, Didot | 时尚 / 高对比 / 装饰 | Vogue / 奢侈品 |
| Slab Serif | Rockwell, Archer | 工业 / 美式 / 友善 | 海报 / 友好型 |
| Humanist Sans | Gill Sans, Frutiger, Inter, Newsreader | 现代 + 一点温度 | UI 主力, 现代 web |
| Geometric Sans | Futura, Avenir | 包豪斯 / 极简 / 工业 | 极简 / 工业品牌 |
| Grotesque / Neo-grotesque | Helvetica, Akzidenz | 瑞士设计 / 中立 / 商业 | 公司 / 系统 / "everything" |
| Mono | JetBrains Mono, IBM Plex Mono | 代码 / 工程 / 工具感 | 代码, 数字, 技术信息 |

**误用例**:
- 一个**文学项目用 Helvetica** — 太工业, 失温
- 一个**银行 App 用 Bodoni** — 太炫, 失稳重
- 一个**消费品官网用 Times New Roman** — 太学院, 失活泼

一个"克制现代 + 一点学院温度" 的组合举例: Newsreader (humanist serif 大标) + Inter (humanist sans 正文) + JetBrains Mono (代码/数字). 适合开发工具 / 文档站 / 偏严肃的 SaaS.

---

## 2. 字号阶梯 — 不要太多

**法则**: 一个项目 **3-5 个字号** 足够. 6 个起就开始混乱.

**典型阶梯**:
- H1: 28-32px (页标题)
- H2: 20-22px (区块标题)
- Body: 14-15px (正文)
- Small: 12-13px (metadata)
- Caption: 11px (注释 / 标签)

阶梯比例可选:
- **1.25 (Major Third)**: 温和, 适合密集 UI
- **1.333 (Perfect Fourth)**: 标准
- **1.5**: 跳跃感强, 适合 hero / 大字landing
- **1.618 (Golden Ratio)**: 优雅但激进

**反例 (烂)**: 13px / 14px / 15px / 16px / 17px / 18px / 20px — 太多相近字号, 视觉无区分.

---

## 3. 字重 — 也是 3-4 档

**法则**: Regular (400) + Medium/Semibold (500-600) + Bold (700) — 三档基本够.

**避免**:
- 同时用 Light + Regular (300 vs 400) — 太相似
- 同时用 Bold + Black (700 vs 900) — 太相似
- 用 6 个字重 — 没必要

**字重 vs 字号的层级权衡**:
- 想突出 → 优先**加重**, 不优先放大. 加重不占空间, 放大破坏 layout.
- 字号已经定了 → 用字重做次级区分 (同字号 H3 + 卡片标题, 用 600 vs 500).

---

## 4. 行高 (Leading) — 比字号本身更重要

Bringhurst 法则: 正文行高 = 字号 × 1.2 ~ 1.5.

- 短行 (40 字以内) → 行高可以紧 (1.2-1.3)
- 长行 (60+ 字) → 行高必须松 (1.5-1.7), 否则眼睛在换行时找不到下一行起点

**标题行高**: 1.1-1.2 (紧, 凝聚力)
**正文行高**: 1.5-1.6 (松, 可读性)
**caption / metadata**: 1.4 左右

**反例**:
- 长正文行高 1.2 — 眼睛跳行
- 短标题行高 1.6 — 标题散架, 不像一个单元

---

## 5. 行宽 (Measure) — 45-75 字

Bringhurst: 一行**约 45-75 个字符** (英文) / **20-35 个汉字** 时最易读.

- 太短 → 频繁换行, 累
- 太长 → 换行时找不到下一行起点, 累

**UI 应用**: 全屏宽正文 (1920px 宽) 一行 200 字 — 错. 限制 `max-width: 680px` 或类似. 即使屏幕大, 正文不应铺满.

---

## 6. 大小写 — All Caps 慎用

ALL CAPS 失去字母轮廓 (每个字母变成均匀的方块), 阅读速度变慢约 13%-20%.

**适合 All Caps**:
- 短词 (3-5 字) 的小标签 / 章节名 / nav (字距要拉大 letter-spacing 0.05-0.1em)
- 设计强调 / 海报用语

**不适合**:
- 句子 / 段落 / 中长文本
- 数据表格行

中文没有大小写问题, 但中文字体的 **字重 + 字号** 是同等问题: 4-5 个粗细层级太多.

---

## 7. 字距 (Tracking & Kerning)

- **Tracking**: 全局字距, 整段统一调.
- **Kerning**: 个别字母对的微调 (Va, To, Wo 这种).

**法则**:
- 标题大字 → 字距可以收紧一点 (-0.01em ~ -0.02em), 视觉更紧凑
- All caps / 小字 → 字距要拉开 (+0.05em ~ +0.1em), 否则糊在一起
- 正文 → 别动, 字体设计师已经给好默认值

---

## 8. 文字作为纹理 (Type as Texture)

远看一段排好的文字, 会形成一片"灰色调"(text color) — 文字的密度决定它在画面里的视觉权重.

- 紧密排版 (短行高 + 小字距) → 深灰纹理 → 视觉重
- 松散排版 (大行高 + 大字距) → 浅灰纹理 → 视觉轻

**应用**: 一篇长文章如果在页面上太"重" (压抑), 不一定是字体问题 — 把行高 1.4 拉到 1.6 试试.

---

## 9. 数字字体 — 容易忽视

数字有两套排版:

**Lining vs Old-Style (旧式数字)**:
- Lining: 1234567890 (全高, 像大写字母) — 表格 / 数据 / 现代 UI 默认
- Old-style: 数字有上下伸出 (类似小写字母) — 文学 / 优雅排版 (Newsreader 默认就是)

**Tabular vs Proportional**:
- Tabular: 每个数字占同样宽 — 表格 / 等宽对齐
- Proportional: 1 比 8 窄 — 正文 / 阅读

**应用**:
- 仪表板数据列 → tabular lining (JetBrains Mono 默认就是)
- 长文中嵌入年份 / 价格 → old-style proportional (更优雅)

---

## 10. 跨文字 (中英文混排)

中英文混排时, **字体匹配** 比单语言重要.

- 中文字体高度高, 英文字体高度低 — 混排时英文显得小
- **解决**: 给英文部分单独设置稍大字号 (105-110%), 或选搭配好的字体对 (思源宋 + Source Serif Pro, Inter + Noto Sans SC)
- 中英文之间留半个空格 (CSS: text-spacing 或手动 `&nbsp;`)

---

## 11. 反审美陷阱

- **字体满天飞**: 一页 5 种字体 — 杂. 修法: 1-2 种字体家族, 用大小/字重做层级.
- **粗细一刀切**: 所有文字都 normal 400 — 没层级. 加 600 做强调.
- **字号近视**: 13 / 14 / 15px 三档 — 用户分不出. 阶梯拉大.
- **All Caps 长句**: 看不下去. 改 Sentence Case.
- **居中长段**: 每行起点不固定, 阅读累. 长段必左对齐 (英文) / 左对齐 (中文).
- **行宽 100% 视口**: 大屏上一行 200+ 字符. max-width 限制.
- **数字不等宽**: 表格列 "1245" vs "8888" 不对齐. 用 tabular figures (font-variant-numeric: tabular-nums).

---

## 12. 大师参照

- **Jan Tschichold** *Die neue Typographie* (1928) → *Asymmetric Typography* (1935) → 后期回归古典对称. 一个人的两次转向, 都对.
- **Robert Bringhurst** *The Elements of Typographic Style* — typography 的圣经, 21 章, 但前 5 章 (尺度 / 节奏 / 和谐 / 结构) 是核心.
- **Massimo Vignelli** — 极限主义: 一个项目只用 6 种字体 (Helvetica, Bodoni, Garamond, Times, Optima, Futura) 就够你一辈子.
- **Ellen Lupton** *Thinking with Type* — 当代美国 typography 教学经典.
- **Hara Kenya 原研哉** — 不写 typography 但 MUJI 的字体使用是教科书.
