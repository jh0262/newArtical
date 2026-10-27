# PADE 补充实验分析接口

`pade_analyze.m` 只读取已经保存的真实运行，不调用目标函数或优化器，不绘图。

```matlab
comparisons = readtable('config/comparisons.csv', TextType='string');
report = pade_analyze('results/raw', 'results/analysis', comparisons, ...
    ExpectedRuns=30, ExpectedSeeds=(1:30)', ...
    ExpectedProblems=string({problems.id}), ExpectedFE=15030);
```

上例种子和 FE 只是接口示例，正式调用须使用冻结协议中的实际值。`comparisons.csv` 必须含 `family_id,a_id,b_id`，可附 `problem_id` 每行指定一个问题；`*` 表示所有指定问题。直接用 CSV 的每问题行方式最便于复核 Holm family。也可由 MATLAB 构造 `problem_ids` cell 列按行限定问题集合。

每个 MAT 文件必须含名为 `result` 的标量结构，必要字段为：

| 字段 | 含义 |
|---|---|
| `problem_id,variant_id,seed` | 唯一运行键；同题比较按 seed 配对 |
| `FE,best_f,best_cv,best_x` | 已消耗 FE 和终态最优解；最小化问题 |
| `trace_fe,trace_f,trace_cv` | 严格递增 FE 处的真实 incumbent；最后一点等于终态 |
| `status` | 可选；正式结果必须为 `complete` |
| `budget_FE,pulseFE,run_seconds` | 可选审计指标；所有调用都计入总 FE |
| `events` | 可选标量结构；数值标量字段展开为 `event_*`，并汇总均值 |
| `config_hash,code_hash,problem_hash,rng_scheme` | 可选运行溯源信息 |

原始改进日志和检查点可共同构成 `trace_*`，但同一 FE 必须去重并保留该 FE 最终 incumbent。分析器用最近真实点前向保持到 FE 网格，不进行线性插值或拟合收敛曲线。

默认 `FeasibilityTolerance=0`，与原代码严格 `CV==0` 一致。每题所有种子配对均可行时，以目标差 `b-a` 做配对 Wilcoxon 符号秩检验；全部不可行时改用 CV 差；混合可行性时，以 Deb 顺序产生的胜/负符号做精确配对符号检验。双可行子集的目标符号秩保留为探索指标，不替代混合情形的主检验。

符号秩去掉零差值，对绝对差相同的值取平均秩；有效样本数不超过50时用精确符号随机化动态规划，包含 ties，无需统计工具箱。更大样本用 ties 方差和格点连续性校正近似。符号秩检验以配对差的对称性为假设。正效应表示 `a_id` 更好；全零差时 `p=1,effect=0`。未检出显著差异不解释为等效。

Holm 在每个 `family_id` 的全部预设问题/对比之间校正。默认严格要求完整30次、相同种子集合和配对 FE 一致；`AllowPartial=true` 仅用于运行中描述性检查，部分结果不输出正式显著胜负，未得到的预设检验仍计入 family 大小。

输出包括完整逐运行 CSV、逐种子成对观察、汇总 Mean/Std/Best/Worst/Median、可行率、CV、FE、事件均值、主检验与效应量、Holm 胜平负，以及 CSV/JSON/MAT。`raw.mat` 保留所有读取结构，`runs.csv` 保留原始文件路径与索引。

`test_pade_analyze.m` 使用明确标记的合成夹具验证统计实现，结果位于 QA，不属于论文的优化实验。已验证精确 DP 与穷举一致、ties、零差、混合可行性、Holm、FE trace 和缺失运行报错。
