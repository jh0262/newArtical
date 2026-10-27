# H14 实验矩阵

| 实验ID | 对应假设 | 数据集 | baseline | 指标 | 已控混淆/负对照 | 完成判定 |
|---|---|---|---|---|---|---|
| EXP01 | H1 | H14 Q=4096 dispersed, L=1/4, 16 landscapes | B5R，同注入频率与随机预算 | FSCAUC；终点归一化可行 HV | B5R 仅把 least-visited targeting 换成 uniform targeting；同 seed/NFE/参数 | FSCAUC 差的 95% cluster-bootstrap CI 下界 >0.01、Holm q<0.05，且 HV 差 CI 下界 >=-0.005 |
| EXP02 | H2 | H14 Q=4096 dispersed, L=1/4, 16 landscapes | B1，无 novelty injection | FSCAUC；终点归一化可行 HV | 同 evaluator、seed、NFE、种群、DE 参数 | FSCAUC 差的 95% cluster-bootstrap CI 下界 >0.01、Holm q<0.05，且 HV 差 CI 下界 >=-0.005 |
| SEN01 | H3 | H14 Q=16/256/4096 dispersed, L=1/4 | B5R | FSCAUC cardinality interaction | Q 外其余生成分布与算法协议冻结 | Q4096 与 Q16 的 B5S-B5R FSCAUC 增益差 95% CI 下界 >0.01 且 Holm q<0.05 |
| ABL01 | H1 | H14 Q=4096 dispersed | B5R vs B5S | FSCAUC protocol audit、注入行与注入次数审计 | 单变量消融；同 selected rows、schedule seed、injection count | 仅当 100% run 满足 targeting 外字段相同时才分析 FSCAUC；任一不一致即停止正式比较 |
| ABL02 | H2 | H14 Q=4096 dispersed | B1、B5R、B5S | FSCAUC 效应分解 | B5R 隔离 targeting，B1 隔离整个 injection | FSCAUC 同时报告 B5S-B1、B5R-B1 与 B5S-B5R；缺任一 contrast 禁止归因 |
| ABL03 | H3 | H14 Q=16/256/4096 dispersed | B5R vs B5S | FSCAUC cardinality profile | 每个 Q 使用相同 targeting 消融协议 | 3/3 个 Q 的 FSCAUC paired contrast 均完整，否则 cardinality interaction 报无结论 |
| NEG01 | H3 | H14 fixed Q/layout, L=1 vs L=4 | B5R | FSCAUC、连续分量覆盖 AUC | 连续分量数变化但离散可行状态集合不变 | L 变化不得被写成 ledger 因果证据；若 FSCAUC interaction 95% CI 排除 0 则降级机制解释 |
| BND01 | H4 | H14 Q=2 boundary, L=1/4 | B5R、B1 | FSCAUC、终点归一化可行 HV | 仅一个可行离散状态，作为低基数伤害检测边界 | 两个 B5S−baseline HV 95% CI 下界均 >=−0.005 时仅报告“未检出预设伤害”；任一 CI 上界 <−0.005 记失败边界；其余为无结论，不声明等效 |
| ABL04 | H4 | H14 Q=2 boundary, L=1/4 | B5R vs B5S | FSCAUC、终点归一化可行 HV | 相同 injection count 与 targeting 单变量消融 | FSCAUC 上限为1且只作描述；HV 按 H4 三分支判定，禁止从不显著结果推断等效或无差异 |

正式 run 数为 6720；当前阶段只执行解析单元测试和非性能 smoke，不从 smoke 输出算法排名。
