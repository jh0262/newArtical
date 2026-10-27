# I3/CVGR 新颖性碰撞增量审计 v0.1

状态：`STATIC_AUDIT_COMPLETE_NOT_A_NOVELTY_CERTIFICATE`

检索截止：2026-08-31

边界：本文件只追加证据，不改冻结 Stage 4 文件，不授权代码、测试、依赖安装、优化器/评估器或正式 FFE。

## 结论先行

当前创新性论证必须降级并收窄。新增检索仍未在已查来源中找到与 I3 三项 target 条件完全相同的论文，但发现了一个高风险历史先例和一个概念先例：

1. Ray、Tai 与 Seow（GECCO 2000）已经按个体的约束满足集合选择“非重叠”的互补配偶。这与 I3 的互补约束签名配对目的高度邻近。
2. Ming、Wang 与 Zhang（CEC 2021，arXiv:2010.04445）已经显式研究成对约束的冲突、和谐与独立关系，并讨论关系识别与分组。

因此，不能再写“首次利用个体约束模式进行互补配对”或“首次研究/利用约束间关系”。目前仅能提出一个条件性、可证伪的窄假设：

> 在相同 SHADE 父机制和 FFE 下，在线种群共违反关系形成的约束社区，是否能通过改变差分供体拓扑，产生超过非图式互补约束签名配对及多样性匹配控制的机制增益。

客观新颖性仍为 `UNKNOWN`；论文结果与优越性结论均不成立。

## Target 等价性判据

只有同时满足以下三项才记为项目内 target 等价：

1. 约束是节点，并由在线种群共违反信息形成约束—约束边或社区；
2. 图或社区输出直接改变 DE/SHADE 的互补差分供体配对或重组拓扑；
3. 该机制作为连续黑箱约束进化优化器进行评价，而不是仅用于景观刻画、问题分解、修复或目标—约束相关性。

该判据只用于判定“是否精确撞车”。不满足三项交集不等于文献不相关，更不构成新颖性证明。

## 检索范围与边界

本地按项目顺序检索 `04_index/literature.db`、`03_notes`、`05_evidence`、`02_text`。新增结构化与全文检索未发现 target 等价记录；宽查询“constraint + graph + differential evolution”只返回 P00133、P00745、P00777、P00922、P01838 五篇不相关文献。既有 120 位语义排序仍是当前最强本地近邻证据。

在线使用 14 组词汇/机制查询，覆盖 co-violation graph、constraint relationship、constraint community mating、non-overlapping constraint satisfaction、constraint-signature partner selection、constraint correlation DE、direct mating constrained MOEA/D 等，并核对公开原文或主记录。未执行 Web of Science、Scopus 或 CNKI 订阅检索，故结果严格限定为“在已检索来源中”。

## 新增关键近邻

| 文献 | 直接事实 | 与 I3 的重合 | 关键差异 | 裁决 |
|---|---|---|---|---|
| Ray, Tai & Seow, *An Evolutionary Algorithm for Constrained Optimization*, GECCO 2000, 771–777 | 用每个解的约束满足/违反向量；不可行候选间按与第一父代的约束满足集合最小重叠选择伙伴，称为 non-overlapping constraint satisfaction | 已有基于逐约束签名的互补配偶选择思想 | 非 DE；没有约束节点图、共违反社区或图控制的差分向量拓扑 | 高风险邻接先例，非三项交集精确撞车 |
| Ming, Wang & Zhang, *Investigating Constraint Relationship in Evolutionary Many-Constraint Optimization*, CEC 2021, 1179–1184 | 研究成对约束的冲突、和谐与独立关系；用约束值比较、Pareto 支配和梯度识别，并讨论关系分组 | 已有约束—约束关系建模与分组 | 未见在线共违反图直接控制 DE 供体 | 概念先例，非三项交集精确撞车 |
| MMDE-EKT-ANM, arXiv:2407.00386 | 用领域约束耦合构造任务，并采用自适应邻域 DE 变异 | 约束耦合与 DE 邻域均相关 | 未见在线约束节点共违反社区控制互补差分供体 | 不同 target |
| Correlation-Based Dynamic Allocation, IEEE TEVC, DOI 10.1109/TEVC.2023.3302897 | 用目标—约束相关性调配评价或优先准则 | 使用在线相关性信号 | 不是约束—约束图，也不控制互补供体 | 不同 target |
| Direct mating constrained MOEA/D, DOI 10.1007/s00521-024-10908-6 | 在约束 MOEA/D 中使用直接/局部配对 | 配对策略相关 | 未见逐约束共违反社区及差分供体拓扑 | 不同 target |

公开原始/主来源：

- Ray 等：<https://gpbib.pmacs.upenn.edu/gecco2000/ES004.pdf>
- Ming 等：<https://arxiv.org/abs/2010.04445>
- MMDE-EKT-ANM：<https://arxiv.org/abs/2407.00386>
- 相关性动态调配：<https://doi.org/10.1109/TEVC.2023.3302897>
- 直接配对约束 MOEA/D：<https://doi.org/10.1007/s00521-024-10908-6>

## 禁止与可保留的论文表述

禁止：

- 首次利用个体约束满足/违反模式进行配对；
- 首次进行互补约束配偶选择或非重叠约束满足配对；
- 首次建模、识别、分组或利用约束间关系；
- 首个图式约束处理方法；
- 新颖性已被证明。

可保留但必须以实验为条件：

> 本研究检验一种更窄的机制增量：在线种群共违反社区是否能为约束 SHADE 的差分供体拓扑提供超出非图式互补约束签名和等多样性控制的信息。

## 必须新增的控制

1. `RAY_STYLE_SET_OVERLAP`：仅按公开数学机制 clean-room 实现集合重叠互补配对，并嵌入同一父算法、相同初始化/选择/停止/FFE。
2. `DEGREE_PRESERVING_REWIRING`：保持度信息但打乱拓扑。
3. `DIVERSITY_MATCHED_NON_GRAPH_SELECTOR`：不使用图，但匹配供体距离或多样性。
4. `RANDOM_COMMUNITY_LABELS`：保持激活频率和社区规模分布，随机化社区身份。

第一项目前不在冻结计划中。任何加入都必须经过版本化修订、作者哈希确认和后续冻结；本审计不授权规格、红测、生产实现或执行。

## 拒稿预演

1. **“Ray 2000 已经提出逐约束非重叠互补配对，CVGR 只是图装饰。”** 只有在等 FFE、同父算法的 Ray-style 控制下，图机制仍改变预注册机制终点，反驳才成立；当前无此证据。
2. **“Ming 2021 已经形式化约束关系与分组，本文只是换表示。”** 论文必须只主张对差分供体拓扑的干预，并用图特异负对照隔离该干预；当前无此证据。
3. **“收益只是一般多样性、随机分组或噪声。”** 需要度保持重连、等多样性选择、随机标签、精确回退及图稳定性/激活率分析；当前无此证据。

## 最终裁决

`REVISE_HIGH_RISK_PRECURSOR_FOUND_NO_EXACT_COLLISION_WITHIN_SEARCHED_SOURCES_NOVELTY_UNKNOWN`

这不是否定 I3，也不是新颖性证明。它把可发表问题收窄为一个更严格的机制比较，并把 Ray-style 非图互补配对提升为必须控制。正式 optimizer run、目标/约束评估、运行包和 FFE 均保持 0。
