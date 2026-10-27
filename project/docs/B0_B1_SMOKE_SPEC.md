# B0/B1 Offspring Kernel and PCR Smoke Specification

状态：`FROZEN_FOR_SOFTWARE_SMOKE / NOT_CONFIRMATORY`

## 1. Scope

本阶段只实现：

1. 公平共享的DE供体、交叉掩码和随机数调度；
2. B0：连续数值DE后对离散变量执行截断和MATLAB round；
3. B1：连续变量DE、整数/序数随机无偏舍入、类别变量按供体角色采样；
4. 已评价候选集的PCR、重复率、两类约束无效率和PCR-AUC；
5. 一个固定种子、一个实例、单代后代生成smoke。

不实现环境选择、档案更新、在线连通分量估计、B2/B3、循环优化或正式性能统计。

## 2. Common schedule

对每个目标个体 \(i\)，调度器产生互异且不含 \(i\) 的 \(r_1,r_2,r_3\)，以及：

- 相同的binomial crossover mask；
- 整数/序数随机舍入所需的均匀数；
- 类别供体角色采样所需的均匀数。

B0和B1必须使用同一调度对象，从而保证连续变量后代完全一致，并把差异限制在离散生成机制。

## 3. B0 DE-round

全部维度先按

\[
\mathbf v_i=\mathbf x_{r_1}+F(\mathbf x_{r_2}-\mathbf x_{r_3})
\]

生成数值mutant，截断到变量边界后执行binomial crossover。整数、序数和类别列最后统一使用MATLAB `round`。

## 4. B1 type-preserving kernel

- 连续变量：与B0相同；
- 整数/序数变量：在相应有序空间计算DE mutant，截断后以小数部分为概率执行随机舍入；
- 类别变量：不做标签加减。若供体角色为 \(a=r_1,b=r_2,c=r_3\)，当 \(b=c\) 时输出 \(a\)；否则以 \(1-F_c,F_c/2,F_c/2\) 的角色概率选择 \(a,b,c\)。角色抽样只依赖供体位置和相等关系，因此应满足类别标签置换等变性；
- 交叉掩码为false时保留target表型。

## 5. PCR diagnostic

对截至检查点已评价的全部候选：

1. 以 \(g_j\le0\) 判断可行；
2. 在可行候选中重新计算非支配关系；
3. 按真实离散状态映射到连通分量；
4. 只统计真实Pareto相关分量；
5. 输出PCR、命中向量、重复率、离散约束无效率和连续带约束无效率。

PCR-AUC使用冻结规范中的梯形公式，NFE必须严格递增且起点为0、终点不超过预算。

## 6. Smoke configuration

- 实例：D-3-3-L；
- \(q=3,L=3,\rho=0.15,\lambda=1\)；
- \(N=30\)，只生成一代30个后代；
- seed：20260829；
- \(F=0.5,CR=0.9,F_c=0.5\)；
- 初始表型由局部`RandStream('mt19937ar')`产生；
- B0/B1共享完全相同的初始表型和调度；
- 输出仅作为软件smoke，不比较优劣、不检验H2—H4。

## 7. Failure conditions

- 调度器改变MATLAB全局RNG；
- 供体重复或包含target；
- B0/B1连续列不一致；
- B1产生越界、非整数或类别域外值；
- B1不满足类别标签置换等变性；
- PCR不在 \([0,1]\) 或无关分量被计入；
- 同固定seed两次smoke原始结果不同。

