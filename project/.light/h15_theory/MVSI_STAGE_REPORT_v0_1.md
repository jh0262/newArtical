# MVSI理论合同与测试设计阶段报告 v0.1

## 阶段结论

H15已经从简单的`Q`截断覆盖控制器，推进为一个可估计、可停止、可证伪的**边际价值状态干预候选**。本阶段允许结论为：数学合同和研究设计结构闭合；不允许结论为：算法有效、优于B5P或优于公开基线。

## 关键修正

1. 修正了上一阶段的示意公式：普通子代机会成本必须是自然提案流在全部状态上的总期望价值，而不是单个目标状态的`p_i`项。
2. 将原`q_i`未探索概率吸收到显式不确定性奖励`kappa*SD(delta)`，避免对稀疏性重复计量。
3. 把不可行阶段的约束改善与可行阶段的Pareto效用按决策前可行比例连接，避免无可行解时所有状态价值均为零。
4. 自然流与强制流分层估计，执行prequential时间纪律，禁止当前结果泄漏进当前决策。
5. 明确B5P只在强退化覆盖效用下与MVSI选择方向一致；`I*=Q`不是MVSI的一般最优停止点。

## 已完成验证

| Gate | Result | Evidence boundary |
|---|---|---|
| MVSI deterministic contract | PASS, 8/8 | 仅代数、单调性、选择、停止及输入拒绝fixture |
| Experiment matrix lint | 100/100 | 13行四要素、可量化判定、指标对齐、消融与负对照结构闭合；评分非科学真值 |
| Fair-baseline gate | PASS | 公平性声明齐全；真实调参质量仍需后续核验 |
| Falsifiability gate | PASS | H1-H5均有量化反证条件 |
| Target-chain gate | PASS | question→estimand→endpoint→analysis→falsifier→action闭合 |
| Failure-tree gate | PASS | success/failure/inconclusive、guardrail和停止规则闭合 |
| Statistical power | SKIPPED | 独立landscape数、SESOI敏感性、算力和存储预算尚未冻结 |

## 当前算法合同

\[
V^{inj}_{i,t}=a^{inj}_{i,t}\left[(1-\rho_t)c^{inj}_{i,t}+\rho_t\phi^{inj}_{i,t}\sigma^{inj}_{i,t}u^{inj}_{i,t}\right],
\]

\[
V_t^{nat}=\sum_k p_{k,t}V^{nat}_{k,t},\qquad
M_{i,t}=E[V^{inj}_{i,t}-V_t^{nat}\mid D_{t-1}]+\kappa_t SD[V^{inj}_{i,t}-V_t^{nat}\mid D_{t-1}].
\]

仅当`max_i M_i,t>0`时强制干预。该规则是myopic单步资源分配，不是全局收敛或长期regret最优性结论。

## 当前证据状态

- 已完成：理论合同、估计量规格、确定性验证、13行候选实验矩阵、目标链、失败树和公平/可证伪门。
- 未完成：估计器代码、平稳/变点合成流校准、稀疏状态共享策略、landscape级功效模拟、资源预算、公共基线版本冻结。
- 未执行：任何正式优化器性能实验。当前失败树将正式优化器评价数锁为`0`。

## 下一候选阶段

`ESTIMATOR_TDD_AND_SYNTHETIC_CALIBRATION_ONLY`：开发分源SparseLedger估计器及EST01/EST02受控合成流验证；同时完成landscape级MDE/功效与运行资源测算。只有这些门闭合并获得新的正式实验授权后，才可实现或运行耦合优化器性能路径。
