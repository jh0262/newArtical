# TA-TPDE Benchmark V0.1

状态：`H12_PUBLIC_COMPARISON_EXECUTION_VERIFIED / FORMAL_PUBLIC_BATCH_NOT_AUTHORIZED`

本项目面向断裂可行域上的混合离散约束多目标优化，已从确定性基准验证推进到独立确认实验。当前论文候选算法为：

> **B5：固定 5% 注入率的最少访问离散状态注入 + 类型保持差分进化 + 可行性优先环境选择。**

推荐题目：**面向断裂可行域的评价均衡混合离散约束多目标差分进化算法**。

英文题目：*Evaluation-Balanced Mixed-Discrete Constrained Multiobjective Differential Evolution for Disconnected Feasible Regions*。

## 研究结论

H6 消融表明，B4 的主要有效机制是“最少访问状态定向”，而不是自适应注入率：

- B4 相对随机目标版本 B4R 的 Hodges–Lehmann 效应为 `0.009284`，Holm 校正 `q=0.003240`；
- B4 相对固定注入率版本 B4F 的效应为 `0.000780`，95% CI `[-0.000520, 0.003290]`，`q=0.219596`，不支持保留自适应注入率；
- 因此将 B4F 简化并重命名为最终候选 B5。

H7 使用新的问题规模组合、20 个独立种子和冻结分析方案，对 B5 进行了独立确认：

- B5 对混合变量 NSGA-II 本地适配 N2：效应 `0.492163`，95% CI `[0.443056, 0.509722]`，Holm `q=0.000040`；
- B5 对类型保持 DE 基线 B1：效应 `0.020620`，95% CI `[0.014000, 0.030860]`，Holm `q=0.000040`；
- B5 对原自适应版本 B4：总体非劣，效应 `-0.000800`，95% CI `[-0.003000, 0]`，预注册非劣界 `-0.005`；
- 证据边界：DM2-7-4 上 B5 相对 B4 的实例效应为 `-0.046658`，说明极端双模约束拓扑中自适应率可能仍有局部价值，不能宣称逐实例非劣。

这些结论仅由自建解析合成基准支持，尚不等同于公开基准普适性、真实工程有效性或物理验证。

## H8开发状态

- 权威冻结版本：`releases/B5-Ref-v1.0.1`，独立恢复测试103/103通过；
- `B5-Ref-v1.0.0`因遗漏早期规格和E2契约文件被恢复门拒绝，仅保留为失败证据；
- 已开发SparseLedger、混合进制状态编码、legacy兼容调度和隐式仿射调度；
- 已增加独立算法标识`B5S`。B5S是开发版本，不属于H7已验证的B5-Ref；
- 技术边界见`docs/SPARSE_LEDGER_SPECIFICATION.md`。

## H9开发状态

- 已新增无真值通用入口 `mdt.runB5SparseBlackBox`，runner 内部不再调用 `enumerateTruth`、参考前沿、PCR 或 IGD+；
- 支持连续变量边界、异构离散基数、有序/类别离散变量和任意正约束尺度；
- 小 Q 冻结对照中，初始种群、调度、最终种群、档案和 SparseLedger 轨迹与原 B5S 搜索路径逐字段相等；
- `Q=10^12`、100 次评价 smoke 中存储 97 个已访问状态，无 dense visit-count 字段；
- H9 是功能与尺度开发证据，不是新的算法性能比较或工程验证。

## H10停滞诊断状态

- 冻结运行：2个压力实例×6个seed，12/12完成、0失败、固定12,000次评价；
- 联合停滞判据：连续8代同时无新可行离散状态、PCR无增长、HV无增长、档案无增长；
- 结果：0/12触发，最长连续长度7代，判决`NOT_CONFIRMED`；
- 因修复触发条件未满足，未修改B5S，也未创建B5SR；
- 报告见`evidence/H10_STAGNATION_DIAGNOSTIC_REPORT.md`。

## H11公开基准接入状态

- 已将2021-RW-MOP中的RCM06速度减速器设计接入B5S：6个连续变量、1个整数变量、2个目标、11个显式约束；
- 内部零基整数码`0...11`可逆映射为公开问题齿数`17...28`，未改变目标与约束；
- 适配器在3个冻结点与哈希绑定官方MATLAB快照逐项相等，目标/约束最大绝对误差均为0；
- 解析可行哨兵满足全部11个约束，同种子小预算运行可确定性重放，`truthUsed=false`；
- 已冻结“双轨基准”边界：LIR/DAS/MW用于连续复杂约束拓扑，RWCMOP用于原生混合工程问题；不得把派生离散化版本写成原始公开基准；
- H11只形成接口与数值一致性证据，尚未执行公开算法性能比较。

## H12公开比较执行状态

- 新增 RCM19 与 RCM25 原生混合变量适配器，并与 RCM06 组成非冗余三问题集；RCM01、RCM15、RCM29 因定义冲突或转录风险显式排除；
- 新增 B1/B5S/N2 统一黑箱比较入口，以及 PlatEMO v4.15 官方 NSGA-II、CCMO(type=GA) 的精确 NFE 接口；
- 3问题×5算法的 smoke 矩阵 15/15 完成，每个组合精确 36 次评价、输出有限；RNG/path 恢复和同种子重放测试通过；
- RCM06/RCM19 在 36 NFE 下无可行解仅属于小预算诊断，不能解释为算法失败或性能差异；
- 30 配对种子、450 次正式运行仍为 `PLANNED_NOT_AUTHORIZED`，当前没有公开算法优越性结论。

## 证据规模与完整性

- H6：`300/300` 算法运行、`60/60` 配对集合、零失败；
- H7：`400/400` 算法运行、`100/100` 配对集合、零失败；
- H7：`400/400` 运行清单通过哈希审计，`100/100` 配对集合通过 truth-free 审计；
- 当前开发主线 MATLAB 回归测试：`135/135`；MATLAB Code Analyzer：`115`个文件、`0`问题；B5-Ref冻结包独立恢复测试：`103/103`；
- 所有正式比较均使用相同评价预算、成对种子、冻结问题设计和 Holm 多重比较控制。

## 权威入口

- 算法规格：`docs/B5_ALGORITHM_SPECIFICATION.md`
- H6 消融报告：`evidence/H6_GENERALIZATION_AND_ABLATION_REPORT.md`
- H7 独立确认报告：`evidence/H7_SIMPLIFIED_CONFIRMATION_REPORT.md`
- 论文实验包：`evidence/PAPER_EXPERIMENT_PACKAGE.md`
- 结论—证据表：`evidence/FINAL_CLAIM_EVIDENCE_TABLE.md`
- H7 统计结果：`evidence/h7_statistics.json`
- H7 统计严谨性门：`evidence/h7_stat_gate_report.json`
- H7 运行审计：`evidence/h7_artifact_verification.json`
- H7 冻结方案：`.light/h7/H7_SIMPLIFIED_CONFIRM_SPEC.md`
- H7 原始结果：`runs/H7_SIMPLIFIED_CONFIRM/h7-a/h7_results.csv`
- B5-Ref权威冻结：`releases/B5-Ref-v1.0.1/`
- SparseLedger技术规格：`docs/SPARSE_LEDGER_SPECIFICATION.md`
- SparseLedger交付报告：`evidence/B5_REF_AND_SPARSE_LEDGER_DELIVERY_REPORT.md`
- H9无真值规格：`docs/H9_BLACKBOX_B5S_SPECIFICATION.md`
- H9验证报告：`evidence/H9_BLACKBOX_B5S_VERIFICATION_REPORT.md`
- H9原始摘要：`evidence/h9_functional_verification.json`
- H11公开基准规格：`docs/H11_PUBLIC_BENCHMARK_SPECIFICATION.md`
- H11证据矩阵：`evidence/H11_PUBLIC_BENCHMARK_EVIDENCE_MATRIX.md`
- H11机器审计：`evidence/h11_public_benchmark_audit.json`
- H12执行规格：`docs/H12_PUBLIC_COMPARISON_EXECUTION_SPEC.md`
- H12执行报告：`evidence/H12_PUBLIC_COMPARISON_EXECUTION_REPORT.md`
- H12证据矩阵：`evidence/H12_PUBLIC_COMPARISON_EVIDENCE_MATRIX.md`
- H12机器审计：`evidence/h12_public_comparison_audit.json`
- H12 smoke 原始结果：`evidence/h12_public_comparison_smoke.json`

## 主要 MATLAB 接口

```matlab
cfg   = mdt.makeInstance(family, q, L, rho, lambda);
truth = mdt.enumerateTruth(cfg);
[obj, con] = mdt.evaluate(X, cfg);

design = mdt.makeH7Design();
summary = mdt.runH7Batch(outputDir);
stats = mdt.computeH7Statistics(resultsTable, statSpec);

result = mdt.runB5SparseBlackBox( ...
    evaluator, variableSpec, op, seed, N, budget, archiveCapacity);
summary = mdt.runH9FunctionalVerification();

benchmark = mdt.makeRWMOP6Benchmark();
[obj, con] = benchmark.evaluator(X);
h11 = mdt.runH11PublicBenchmarkVerification();

registry = mdt.makeH12PublicBenchmarkSet();
h12smoke = mdt.runH12PublicComparisonSmoke();
```

## 运行验证

```powershell
matlab -batch "cd('F:/暑假原始资料/06_projects/TA_TPDE_Benchmark_V0_1'); run_tests"
```

完整正式实验只应在冻结设计和独立输出目录下执行；不得覆盖 `runs/H6_GENERALIZATION/h6-a` 或 `runs/H7_SIMPLIFIED_CONFIRM/h7-a`。

## 下一证据层级

若继续向投稿级证据推进，仍需另行冻结并完成：

1. 为连续复杂约束拓扑轨冻结LIR/DAS/MW最小不冗余子集；
2. 为混合工程轨增加至少2个无定义冲突的公开问题；
3. 经核验的现代约束多目标算法官方实现对比；
4. 复杂度与超参数敏感性扩展；
5. 至少一个具有可追溯模型、参数和高保真复核的工程案例。
