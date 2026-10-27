# I3/CVGR S6-I1–I4 数学合同缺口审计 v0.1

状态：`STATIC_AUDIT_COMPLETE_NO_PRODUCTION_OR_TEST_CHANGE`

## 结论

已冻结实现仍是有效的“46 项既定单元合同绿相”历史证据，但尚不具备进入完整优化器实验的数学充分性。当前 9 个源文件和 11 个测试文件与冻结清单 20/20 哈希一致，46 项测试可完整收集；因此本次发现属于冻结测试未覆盖的语义边界，而非后续代码漂移。

审计识别 5 项 critical、5 项 major。前五项足以继续阻断 S6-E0：

1. 稳定性实际只比较阈值后边，而冻结公式要求比较完整权重矩阵；确定性反例中实现值为 1.0，完整矩阵值为 0.632653。
2. NMI 只在预测/真值节点交集上计算；只恢复 4 个真值节点中的 2 个仍可得到 NMI=1.0。
3. relief pool 按总种群而不是排除 target/p-best 后的 eligible population 计算 30% 分位。
4. 父代 generation trace 要求所有 trial 的 improvement>0，因而不能诚实表示被拒绝的零增益 trial。
5. 评价器回调返回后才增加 FFE；回调异常会形成“调用过但未计数”的隐藏预算差异。

此外还存在：只违反非活跃约束的目标被记为 `FEASIBLE_TARGET`、数值 stable ID 使用字符串 `repr` 排序、degree-preserving rewire 可静默原样返回、cache 结果缺有限性与不可变保护、未来运行路径 ID 未使用可移植语法。

## 关键证据

| ID | 等级 | 冻结要求 | 当前实现 | 可影响的论文证据 |
|---|---|---|---|---|
| MCG-01 | Critical | 对全部 (j<k) 权重计算 weighted Jaccard | 只把 `graph.edges` 输入 Jaccard | 激活率、H1、机制归因 |
| MCG-02 | Critical | 在固定真值节点全集评价 block recovery | 只用 observed/truth 交集 | NMI kill criterion |
| MCG-03 | Critical | relief pool 为 eligible population 的最低30% | 分母为完整 population profile 数 | 实际 donor domain、算法身份 |
| MCG-04 | Critical | 全代包含成功与失败 trial，只有成功项更新 memory | 所有 trial 进入比较前都必须有正 improvement | 完整 optimizer 忠实度 |
| MCG-05 | Critical | 每次 oracle 调用按统一口径计 FFE/失败 | 成功返回后才加 1 | 等 FFE 公平性、失败恢复 |
| MCG-06 | Major | 全约束向量决定可行性 | 活跃社区 profile 为零即记 feasible | fallback/activation 诊断 |
| MCG-07 | Major | lower stable ID 解决完全平局 | `(type, repr)` 字典序 | 跨适配器复现 |
| MCG-08 | Major | rewired 控制必须提供实际替代拓扑 | 不报告成功 swap，可能原样返回 | 图特异负对照 |
| MCG-09 | Major | cache 结果有限且不可变 | 可缓存非有限/可变数组 | 原始证据与复现 |
| MCG-10 | Major | 稳定、可移植、无穿越的运行路径 | 仅禁止 `|`，路径组件可含分隔符 | run bundle 完整性 |

## 纯函数反例

- 阈值后 Jaccard：两个图保留同一条 0.30 边，另一个子阈值权重从 0.19 变为 0.01。当前 caller 得 1.0；完整 (W) 得 ((0.30+0.01)/(0.30+0.19)=0.632653)。
- NMI：observed=`{{0,1}}`，truth=`{{0,1},{2,3}}`；当前实现仅取公共节点并返回 1.0。
- Relief pool：总数4，排除 target/p-best 后 eligible=2，(\lceil0.3\times2\rceil=1)，当前实现却让两个 eligible ID 都进入正供体集合。
- Rewire：三节点路径请求40次 swap，函数原样返回但没有失败或 achieved-swap 记录。
- Stable ID：完全平局时比较数值 ID 2 与10，当前结果认为10更小。
- Inactive-only violation：完整向量 `[0,0,0,1]` 在活跃社区投影为 `[0,0]`，最终记为 `FEASIBLE_TARGET`。

以上诊断没有调用目标函数或约束函数；失败 trial 仅调用预评价记录验证逻辑。

## 测试覆盖裁决

现有 46 项测试覆盖了代表性图恢复、重排/正缩放不变性、声明的八种图回退、RNG 隔离、单个正向 parent trace、cache hit 和 dry-run 禁止 callable 等。但没有任何测试同时覆盖上述十个具体边界。`46/46 green` 因而只能继续解释为冻结合同的既有覆盖，不是完整数学实现证明。

## 必要修订顺序

1. 先冻结 full-matrix Jaccard、fixed-node NMI、eligible-pool quantile、失败 trial/增益语义和 attempted-FFE 口径。
2. 再补 inactive-only fallback、typed stable-ID、rewire 成功遥测、cache 不可变/有限性和可移植 path ID。
3. 对每项先建立加法规格、确定性夹具与 expected-red 测试；未获后续授权前不修改生产代码。
4. 修订冻结并生产实现绿相后，才可恢复 S6-E0 规格与完整 optimizer 工作。

最终裁决：`FROZEN_CONTRACT_GREEN_BUT_NOT_MATHEMATICALLY_EXECUTION_READY_VERSIONED_AMENDMENT_REQUIRED`。

本审计没有修改冻结包、生产代码或测试，没有安装依赖，没有运行优化器/评估器，正式 FFE 为 0。
