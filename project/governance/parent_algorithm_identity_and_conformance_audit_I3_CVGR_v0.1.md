# I3/CVGR 父算法身份与符合性审计 v0.1

状态：`PARENT_IDENTITY_UNRESOLVED_AND_CURRENT_KERNEL_NOT_FULLY_CONFORMANT`  
方式：本地索引→笔记/证据→全文→项目源码→原始出版物/作者参考实现的静态审计。未改生产代码、未运行测试、优化器或评估器，正式 FFE=`0`。

## 结论

`FR-SHADE` 目前只能视为项目工作代号，不能写成已核验的标准外部算法名。可核验的两部分来源分别是：

1. Tanabe 与 Fukunaga 的 SHADE；
2. Deb 2000 的可行性优先约束处理规则。

二者组合后属于项目定义的复合父算法，必须注明具体 SHADE 版本、约束聚合、等式容差和完全相同的随机规则。当前 `shade_kernel.py` 只是预评价记录上的状态转移合同，不是完整 SHADE 优化器。

## 可追溯文献事实

- SHADE 原始论文：Tanabe, R.; Fukunaga, A., *Success-History Based Parameter Adaptation for Differential Evolution*, CEC 2013, 71–78, DOI `10.1109/CEC.2013.6557555`。
- SHADE 算法说明论文：Tanabe, R.; Fukunaga, A., *Evaluating the performance of SHADE on CEC 2013 benchmark problems*, DOI `10.1109/CEC.2013.6557798`。
- Deb 约束处理：Deb, K., *An Efficient Constraint Handling Method for Genetic Algorithms*, CMAME 186 (2000) 311–338, DOI `10.1016/S0045-7825(99)00389-8`。
- 作者官网提供 SHADE 1.1.1 C++ 包；本次仅下载到临时目录静态查看。ZIP SHA-256=`12D444A5B37D8E2C0A00514713B4584BD4AA00FA4D154D0227E381F874E13491`。包内未观察到许可证文本，因此不得复制进项目或公开再分发。

本地库全文支持上述来源链，但没有观察到项目外的 `FR-SHADE` 精确名称命中。该结果只表示当前检索没有建立该名称的标准算法身份，不构成全世界不存在同名用法的证明。

## 版本差异必须先裁决

2013 论文与作者 SHADE 1.1.1 参考实现并不完全相同：

| 合同项 | 2013 论文 | 作者 SHADE 1.1.1 源码快照 |
|---|---|---|
| `M_CR` 更新 | 加权算术均值 | 加权 Lehmer 均值 |
| `M_F` 更新 | 加权 Lehmer 均值 | 加权 Lehmer 均值 |
| p-best | 每个个体随机 `p∈[2/N,0.2]` | 主配置固定率 `0.1` |
| archive 容量 | `N` | 主配置 `2N` |
| archive 溢出 | 随机删除 | 随机替换 |
| 内存大小 | 论文按 `H` 定义 | 主配置 `H=D` |

因此，“符合 SHADE”必须绑定版本，不能从若干组件相似推断。

## 当前实现的阻断性差异

1. `select_shade_donors` 把 p-best 从 `r1/r2` 候选域排除；作者 1.1.1 源码只要求 `r1≠target`、`r2≠target,r1`。当前不能声称对某一外部 SHADE 版本“精确回退”。
2. 冻结合同要求 archive 最旧优先淘汰；论文和 1.1.1 源码均为随机淘汰/替换。
3. `ParentShadeState` 的 archive 保存 `CandidateRecord`，但没有强制保存 archive 向量；完整变异式无法仅凭该状态从 archive 取得 `x_r2`。
4. 参数采样、p-best 选择、变异、二项交叉、初始化、评估循环、停止规则仍不存在；46/46 绿测不等于完整 SHADE 或完整 CVGR 优化器已经实现。
5. 当前可行性比较器增加了稳定 ID 等确定性平局规则，并允许评估器提供综合违反值；这是需要冻结说明的项目扩展，不是从 Deb 论文自动继承的全部细节。

## 推荐裁决

推荐把父算法明确命名为“`SHADE 1.1.1 mechanics + Deb-2000 feasibility-rule project composite`”，代码 ID 继续使用 `PARENT`，论文中不要把 `FR-SHADE` 写成外部标准算法。随后只准备增量规格与红测，至少覆盖：

- 完整参数采样、p-best、变异、二项交叉和中点修复；
- 选定版本的 donor distinctness 与 archive 随机淘汰；
- archive 记录—向量一致性；
- 约束归一化、等式容差和完全确定的平局规则；
- 同 `base_rng` 下父算法与 CVGR 全部回退路径的逐代等价。

在该修订冻结并另行授权生产实现之前，不应改现有生产代码；在完整实现包、外部基线、基准许可和运行合同冻结之前，不应执行优化器或评估器。

详细机读证据、哈希和八项 finding 见同名 JSON。
