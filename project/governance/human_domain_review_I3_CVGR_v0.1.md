# I3-CVGR 作者领域差异审查表 v0.1

日期：2026-08-30  
状态：`SUPPLEMENTAL / NOT A FREEZE / NOT AN AUTHOR VERDICT`  
关联决策包：`author_decision_packet_v0.2.json`，SHA-256 `DEA87E5647D1844CFF03150BCAE07D14149DBD4559CFA51E3C829396E56F031E`

## 1. 待审的唯一窄机制

I3-CVGR拟研究的不是一般意义上的“图”“聚类”“相关性”或“动态供体”，而是下面三个条件的交集：

1. 图节点是原问题中的各个约束；
2. 边或社区由种群在运行过程中对约束的共同违反行为在线估计；
3. 图/社区输出直接改变DE的差分供体配对或重组拓扑，以尝试形成约束层面的互补搜索方向。

只有文献同时覆盖以上三点，才按`TARGET_EQUIVALENT`处理。仅覆盖其中一至两点属于近邻或强负对照，而不是自动撞车。

## 2. 最高风险公开近邻逐项核验

符号：`Y`=明确具备；`N`=明确不具备；`U`=当前公开证据不足。

| 近邻 | 约束作节点 | 共违反作边/社区 | 图结果控制DE供体 | 当前关系 |
|---|---:|---:|---:|---|
| Constraint Consensus Mutation-Based DE, 2016, DOI 10.1109/TEVC.2015.2477402 | N | N | N | 用约束一致性估计修复/变异方向；`DIFFERENT` |
| IUCDE, 2025, DOI 10.1016/j.ins.2024.121863 | N | N | N | 约束—目标相关性、动态可行性规则和子种群；`DIFFERENT` |
| CCOC-DE-DBmax, 2025, DOI 10.1016/j.asoc.2025.113383 | N | N | N | 分组对象是决策变量，DBmax作用是可行性移动；`DIFFERENT` |
| DPSDE, 2024, DOI 10.1109/TETCI.2024.3367809 | N | N | N | 根据全局探索/开发状态切换种群结构模块；`DIFFERENT` |
| Nearest-Better Network, 2024, DOI 10.1109/TEVC.2024.3478825 | N | N | N | 图节点是采样解，用于适应度景观刻画；`DIFFERENT` |
| Growing Neural Gas offspring generation, 2023, DOI 10.1109/TETCI.2023.3313412 | N | N | U | 网络学习解分布并辅助约束多目标后代生成；不是约束节点图；`DIFFERENT` |
| Landscape-assisted MODE, 2020, DOI 10.1016/j.eswa.2019.113033 | N | N | N | 景观指标选择DE算子；`DIFFERENT` |
| CACDE cluster replacement, 2018, DOI 10.1016/j.ins.2018.01.014 | N | N | N | 聚类对象是解，服务于不可行档案替换；`DIFFERENT` |

精确反向检索还使用了以下查询：

- `"constraint co-violation graph" optimization`
- `"co-violation" constraints evolutionary optimization`
- `"constraint interaction graph" differential evolution donor selection`
- `("constraint graph" OR "constraint network") recombination donor "differential evolution" constrained optimization`

检索结果主要落入约束多目标协同进化、聚合违反度、SAT/CAD约束依赖图和数据库一致性共违反等非等价主题；没有发现同时满足三项target条件的优化算法论文。该事实仍受搜索引擎覆盖与索引滞后限制。

## 3. 作者必须判断的问题

请不要判断“这个想法看起来是否新颖”，而是逐项判断：

1. 你是否知晓一篇未被本包覆盖、且同时满足三个target条件的论文、专利、学位论文或代码？
2. 你是否同意“约束一致性方向/修复”与“共违反社区控制供体配对”在干预对象和搜索算子上可区分？
3. 你是否同意“解图/种群图/目标空间聚类”与“约束节点图”不是同一表示层？
4. 你是否接受把“未检出target等价方案”作为继续做预注册证伪的理由，而不是作为“已证明创新”的结论？

## 4. 可记录的领域判断

- `REVIEWED_AND_AGREE_DIFFERENTIATED`：当前没有已知target等价碰撞，同意进入冻结准备；仍不等于确认客观新颖性。
- `COLLISION_IDENTIFIED`：作者提供具体题名/DOI/链接，并指出同时满足三项target条件的位置；I3停止冻结并回到idea-generation。
- `UNSURE_REQUIRE_MORE_SEARCH`：暂不选择I3，继续补指定数据库、关键词或专家意见。

## 5. 即使同意也不能跳过的证伪

1. 共违反相关不一定代表互补的可行方向；
2. 图可能在少约束、极低可行率或强非平稳阶段不稳定；
3. 观察到的收益可能仅来自一般供体多样性，而不是图结构。

因此后续预注册必须包含度数保持随机重连、随机社区/标签置换、仅多样性匹配及严格SHADE回退等强负对照，并保持相同FFE预算。当前文件不授权这些实验运行。
