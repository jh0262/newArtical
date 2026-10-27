# H14 本地预注册草案

Registration status: LOCAL-ONLY / DRAFT。该文件未提交到外部 registry，不能表述为已注册。

## Primary

Primary family 为 H1–H3。primary endpoint 是景观层 paired FSCAUC difference；景观实例是独立单位，算法 seed 嵌套在景观内。Holm FWER=0.05。

每个景观先对10个配对算法 seed 与 L={1,4} 求均值，再在16个景观上计算算术平均效应。每个主假设使用20,000次固定种子的景观重采样得到双侧95% percentile CI，并对 `effect−0.01` 做16个景观的单侧精确符号翻转检验；三个原始 p 值用 Holm 调整。景观 seed 是独立分析单位，算法 seed 和 L 不增加独立样本量。

H4 不属于 primary family。它是 Q=2 次要伤害边界：分别计算 B5S−B5R 与 B5S−B1 的终点归一化可行 HV 景观 bootstrap CI。两个 CI 下界均不低于−0.005时只能写“未检出预设伤害”；任一 CI 上界低于−0.005时记录失败边界；其余为无结论。任何分支均不得声明等效。

## Exploratory

连续分量覆盖 AUC、首次可行 NFE、重复状态提议率、运行时间、Q=256 曲线形状和 L interaction 均为 secondary/exploratory；不得升级为 primary。

## Stopping

固定 16 个景观、每景观 10 个配对算法 seed、每 run 10,000 NFE。正式批量开始后不以显著性、排名或中期趋势提前停止；基础设施失败只允许恢复相同 run ID。

## Guardrail

终点归一化可行 HV 的 B5S−baseline 景观层 95% CI 下界必须 >=−0.005。该阈值沿用 H7 项目内 guardrail，并非外部验证的最小实际重要差异。

## Exclusions and missingness

预先不排除任何有限、协议合规的 run。NaN/Inf、NFE 不等于 10,000、seed/source hash 不匹配、truthUsedByAlgorithm=true 均属于协议失败，不能静默删掉；修复后以同 run ID 重跑并保留失败日志。无法恢复则对应 contrast 报告不完整/无结论。

## Amendment policy

正式数据产生后只允许 append-only deviation；指标、阈值、seed、Q、布局、L、预算和 primary family 的任何变化都必须建立新版本并降级为 exploratory，且需要用户新授权。
