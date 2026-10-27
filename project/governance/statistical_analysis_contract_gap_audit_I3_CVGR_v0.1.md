# I3/CVGR 统计分析合同缺口审计 v0.1

状态：`STATIC_AUDIT_COMPLETE / NO PLAN OR CODE CHANGE / ZERO FORMAL FFE`

## 审计结论

冻结方案具备研究问题、主要终点、问题级推断单位、三分支判据与失败树，结构门也已通过；但它还不能唯一决定同一批不可变运行包应产生什么主终点、p 值和论文分支。静态审计确认 **5 项 critical + 6 项 major** 分析合同缺口，因此结论为：

> `STRUCTURALLY_PREREGISTERED_BUT_NOT_STATISTICALLY_EXECUTION_READY_VERSIONED_AMENDMENT_REQUIRED`

本审计没有否定原冻结方案的历史效力，也没有读取任何结果。它说明原方案还需要一个加法、版本化、事前冻结的统计分析层。S6-E0 继续 HOLD；正式优化器运行、评估器调用和正式 FFE 均为 0。

## 五项 critical 缺口

1. **H1/H2 的 30-seed 聚合路径未唯一化。** H1 没有规定“四检查点中位数”和“30 seeds”的先后聚合；H2 没有规定是跨运行池化全部供体事件，还是先算每个 seed 的运行比例再等权聚合。几种做法对活跃频率不同的运行给出不同权重。
2. **H3 在 common random numbers 下的 A12 未唯一化。** 全部 900 个跨算法对、仅 30 个同 seed 对，以及排除 30 个相关对角对，估计的是不同量。当前文本只说“30 个输出估计 A12”，不足以生成唯一实现。
3. **“精确 Wilcoxon”尚无零差/并列合同。** H1/H2 主动制造零值，A12 又是离散量；不同库和版本可能自动退化为渐近算法或采用不同 zero method，从而改变 Holm 分支。
4. **多重性只在单个 H 内处理。** 最终论文门允许 H1/H2 中“至少一个”成功后与 H3 组合，这构成跨假设选择；当前没有全局 claim family，也没有统一解决 H3 对“非 failure”与“正向支持”的不同要求。
5. **基础设施失败不超过 5% 时怎么分析未定义。** 30 runs 下 1 次未恢复失败为 3.33%，2 次为 6.67%。当前只定义“超过 5%”的动作，没有规定 1 次失败时是否删除配对 seed、保留不等样本或怎样形成 A12/H1/H2。

## 六项 major 缺口

- 12 个合成问题是固定的 3×2×2 析因全集，16 个 CEC2006 问题是固定资格子集；把它们表述为随机独立的外推总体需要收紧。
- 30 seeds 没有 Monte Carlo 精度、区间估计或 CRN-aware uncertainty 合同。
- 算法自身失败在 H3 有“最差终值”，但 H1/H2 的 NMI、激活和方向比例没有对应 fail-closed 值。
- H4 同时出现 240 个配对比较和 480 个单算法 trace，完成分母需分别锁定。
- NMI、方向比例和 A12 阈值是项目决策阈值，不是已有证据支持的通用 SESOI；需要预声明敏感性图且不得用来补救失败主分析。
- 25% 墙钟开销门没有计时边界、配对比值和聚合顺序，不能形成唯一 guardrail。

## 推荐的最小修订结构

建议后续由作者裁决并单独授权准备以下分析合同，但本审计不替作者落锤：

- H1：先对每个 seed 的四个固定检查点取中位数，再对 30 个 seed-run 值取问题级中位数；控制差采用同 seed 的 run-level 差后再取问题级中位数。
- H2：每个 seed-run 先形成方向成功比例，零激活运行为 0；问题级等权聚合 seed-run，事件池化只作探索性分析。
- H3：明确 conventional all-pairs A12、paired-seed superiority 或 CRN-aware off-diagonal A12 中的一种；同时锁 tie=0.5、方向、pair set 和区间方法。
- 精确检验：用库无关的枚举符号翻转实现 signed-rank，写死 zero method、midrank、单侧方向、全零动作及人工可算夹具。
- 全局 family：为 H1/H2/H3 各先形成一个 intersection-union 全局统计量，再对三个全局假设做预定 Holm，或采用作者另选且能控制选择性错误率的 gatekeeping。
- 缺失：把 5% 转成确切整数和配对 complete-case 规则，规定最小可分析 seed 数和整项 hypothesis 的 inconclusive 动作。

## 与现有五个候选的边界

本审计不处理 M/H 预算与检查点选择、父算法身份、现代基准/外部基线、Ray-style 新颖性控制或已发现的图数学/FFE/cache 缺口。它只处理运行记录如何变成 seed 统计量、问题级 effect、跨问题检验、全局多重性和三分支结论，因此需要作为第六个独立候选，不能从前五项授权中推断。

## 证据边界

本轮只读取冻结/活动计划工件并做静态数学审计。未运行分析脚本处理正式数据，未执行优化器、benchmark、objective、constraint 或 evaluator；未创建运行包，正式 FFE 保持为 0。这里没有性能、优越性、新颖性、稳健性或论文就绪结论。
