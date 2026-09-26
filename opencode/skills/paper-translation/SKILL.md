---
name: paper-translation
description: 把英文学术论文（PDF 或 LaTeX 源码）按分阶段流水线译成中文，产出双语对照文档。Use when the task mentions 翻译论文, 论文中译, 英译中, 把这篇论文译成中文, paper translation, translate this paper to Chinese, or asks to build a Chinese version of a paper.
---

# Paper Translation

把英文学术论文按 0–6 阶段流水线译成中文并产出双语对照交付文档；阶段定义、术语口径与校验清单一律以《论文中译规范》为准，本 skill 只规定 opencode 落地方式。

## When to use

- 用户要求翻译论文、论文中译、英译中、把某篇论文译成中文
- 输入为 PDF 或 LaTeX 源码，期望输出双语对照文档（Word/Markdown）
- 任务提到 "paper translation"、"translate this paper to Chinese"、构建论文中文版

## Normative spec

规范正文与三附录随本 skill 一同发布，位于本目录下的 `references/`（相对本 SKILL.md），是唯一权威：

- `references/README.md` — 0–6 阶段定义、代理分工、校验清单、DoD、常见坑
- `references/附录A-各阶段Prompt模板.md` — 各阶段 prompt 模板、占位符/上下文摘要/块编号约定
- `references/附录B-术语表与样例.md` — 术语表三列结构与填写规则
- `references/附录C-校验清单与脚本接口.md` — 机械化校验项 C01–C09 与脚本接口契约

阶段定义、验收标准、术语表结构、校验规则均以规范为准；本 skill 只负责把它们映射到本仓库的 subagent 执行。规范未尽处不得自行发明规则。

## Pipeline → agent mapping

| 阶段 | subagent（角色） | 写权限 | 产物 | 校验归属 |
| --- | --- | --- | --- | --- |
| 0 术语表预建 | `explore` 检索术语草稿（只读）＋ `light-orchestrator` 落盘 | 只写术语表 | 术语表文件（三列＋备注） | `reviewer` |
| 1 获取与解析 | `deep-worker`（LaTeX 优先 / PDF 按版面 block 回退） | 写结构化文本 | 结构化文本（block 编号/栏序/结构标记） | `oracle` |
| 2 清洗 | `deep-worker` | 写清洗文本 | 清洗文本 ＋ 问题块清单 | `oracle` |
| 3 分块翻译 | 拆为多个 `deep-worker` 小任务，各写独立文件 | 各写自己的分块译文文件 | 分块译文（占位符完整、术语命中） | `reviewer` |
| 4 合并 | `deep-worker` | 写合并译文 | 合并译文（编号完整、无漏译重复） | `reviewer` |
| 5 输出重建 | `deep-worker` | 写交付文档 | 双语对照文档（无软换行） | `reviewer` |
| 6 终审 | `reviewer`（只读，产出结论）＋ `light-orchestrator` 归档报告 | 不写产物 | 校验报告（C01–C09 逐项结论） | 自审后交主代理关闭 |

要点：

- `oracle`/`reviewer`/`explore`/`librarian` 只读，绝不改文件；写者互不重叠（阶段 3 各块独立文件）。
- 每个 delegation 必须指定验收方：写者交回后由对应校验方核对产物，未过验收不得流入下一阶段。
- 术语/编号错误回阶段 0/4 修复后重跑，禁止跨级就地改稿。

## Hard constraints

- 禁止按 `(y,x)` 行级坐标排序抽取 PDF 文本 —— 双栏会串栏；必须按版面 block 与栏顺序。
- 图内文字（坐标轴刻度、图例、水印）必须过滤并归入图内文字区，不得混入正文。
- 输出 Word 正文段落软换行（`<w:br/>`）计数必须为 0；对齐宜左对齐，禁止两端对齐制造字间大空白。
- 跨页被截断的句子属正常现象：忠实对应、由下一块续接，严禁臆造补全。
- 术语表硬约束：译文中术语 100% 命中术语表；未收录新词先补表、后翻译，禁止临时起名；单位/变量/专名不译。
- 公式、图表编号、文献条目、交叉引用等不译物以 `⟦…⟧` 占位符隔离，合并阶段原位还原，全文不得残留 `⟦`/`⟧`。
- 默认双语对照输出；图表引用统一「（图 N）」「（扩展数据图 N）」「（扩展数据表 N）」，图注行以「图 N | …」起首。
- 缩写首现写作「中文名（English Full Name, ABBR）」，此后统一用缩写。

## Run recipe

1. **建术语表**（阶段 0）：`explore` 通读源文件抽术语，`light-orchestrator` 写入三列术语表；`reviewer` 评审后锁定，覆盖率 ≥95% 专有名词与高频学术词。
2. **取源**（阶段 1）：LaTeX 源码优先；无源码则 PDF 按版面 block/栏序解析。`deep-worker` 产出带 `Bxxxx` 块编号的结构化文本。
3. **清洗**（阶段 2）：`deep-worker` 滤图内文字、缝合跨页断段、去重；输出问题块清单。
4. **分块翻译**（阶段 3）：**拆成多个小任务**，每个任务译一个或几个块、写入独立分块文件（避免超大 delegation 空结果）；每块注入「前块末句译文＋本块首句原文＋后块首句译文」上下文摘要与术语表；不译物占位符化。
5. **合并**（阶段 4）：`deep-worker` 按块编号顺序拼接、查编号连续、检测漏译/重复/错位。
6. **重建**（阶段 5）：`deep-worker` 生成双语对照交付文档，占位符原位还原，无软换行。
7. **校验**（阶段 6）：`reviewer` 按 references/附录C-校验清单与脚本接口.md 逐项核查（见下），任一 fail 回溯对应阶段出具缺陷单，修复后重跑直至全过；`light-orchestrator` 归档校验报告与各阶段产物快照。

每阶段结束保留产物快照（命名含阶段号与版本），便于回溯与审计。

## Verification

按 `references/附录C-校验清单与脚本接口.md` 执行，校验归属 = `reviewer`（只读产物、只写报告）：

- C01 软换行：解析 docx `word/document.xml`，正文段落 `<w:br/>` 计数 = 0（自动）
- C03 图注编号：正则 `^(图 \d+|扩展数据图 \d+|扩展数据表 \d+) \|`，自 1 起连续无缺（自动）
- C07 术语命中：术语表逐项在译文命中率 100%（自动命中 ＋ 人工语境核）
- C05 漏译粗筛：译文 CJK 字数 / 原文词数落在约 1.4–2.2（自动 warn ＋ 人工逐页抽查）
- C09 跨页续接：页尾完句必须来自原文，无臆造补全（人工）

任一项 `fail` 阻断交付，按 references/附录C-校验清单与脚本接口.md「失败处置」列回溯阶段；报告按 references/附录C-校验清单与脚本接口.md §2.2 输出 JSON，退出码 0=全过 / 1=有 fail / 2=运行错误。
