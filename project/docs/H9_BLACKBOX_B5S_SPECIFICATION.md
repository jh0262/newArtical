# H9 无真值黑盒 B5S 规格

## 1. 目的

`mdt.runB5SparseBlackBox` 将 B5S 搜索内核与 `enumerateTruth`、参考 Pareto 前沿、PCR 和 IGD+ 计算解耦。它面向不知道全局真值的连续—离散混合多目标黑盒问题，并保留 SparseLedger 的已访问状态稀疏存储。

本规格只支持以下结论：

1. 在冻结的小 Q 对照中，剥离真值指标层不改变搜索状态；
2. 异构离散基数乘积为 `1e12` 时，可在不创建 Q 尺度数组的条件下完成固定预算；
3. 同 MATLAB 环境、同输入和同随机种子可确定性重放。

它不证明 B5S 优于其他算法，也不构成工程模型的物理验证。

## 2. 调用接口

```matlab
result = mdt.runB5SparseBlackBox( ...
    evaluator, variableSpec, op, seed, N, budget, archiveCapacity);
```

`evaluator` 必须满足：

```matlab
[objectives, constraints] = evaluator(X)
```

- `X`：`N×D` 决策矩阵；
- `objectives`：`N×M` 有限矩阵，`M>=2`，全部目标按最小化解释；
- `constraints`：`N×C` 有限矩阵，逐项 `<=0` 表示满足约束；
- 评价器应为确定性函数；若内部含随机过程，应由调用者冻结其随机状态。

## 3. 变量规格

```matlab
variableSpec = struct( ...
    'continuousLower', [0, 0], ...
    'continuousUpper', [1, 1], ...
    'discreteCardinalities', [1000, 1000, 1000, 1000], ...
    'orderedDiscreteCount', 2, ...
    'constraintScales', 1);
```

- 连续变量位于决策向量前部；上下界必须有限且逐维 `lower<upper`。
- 离散变量使用零基整数编码，第 `j` 维取值为 `0:(q_j-1)`。
- 前 `orderedDiscreteCount` 个离散变量采用有序空间 DE 与随机舍入；其余离散变量按类别标签处理，不对标签码做算术。
- `constraintScales` 与约束列一一对应，用于不可行解的归一化总违反度；必须为正有限值。
- 离散状态总数 `prod(discreteCardinalities)` 当前必须不超过 `flintmax`；它只作为混合进制秩和审计标量，不作为数组长度。

## 4. 算法流程

```text
规格校验
  → 局部 RandStream 初始化
  → 黑盒评价
  → SparseLedger 记录访问/可行状态
  → 类型保持 DE 与固定随机调度
  → 隐式仿射排列选择最少访问状态并注入
  → 黑盒评价
  → 可行性优先的非支配排序与拥挤度选择
  → 有限非支配外部档案
  → 固定 NFE 停止并输出原始审计轨迹
```

为保持与 B5-Ref 精确比较，当前 `budget` 必须是 `N` 的整数倍，且 `N>=4`。

## 5. 输出合同

- `finalPopulation`：最终 `X/obj/con`；
- `finalArchive`：去重后的可行非支配有限档案；
- `trace`：检查点、代数、NFE、可行率、重复率、档案规模、累计已访问离散状态和新可行状态数；
- `audit`：初始种群、调度种子、实际评价次数、真值使用标志、SparseLedger 存储量、状态总数和覆盖率；
- `metrics`：固定预算、最终可行率、平均重复率、最终档案规模和运行时间。

`audit.truthUsed=false` 的含义是 runner 内部不调用真值枚举或参考前沿；它不能审计用户提供的评价器内部实现。

## 6. 异常合同

非法变量规格、预算、种子、档案容量、评价器输出维数、NaN/Inf、变量越界或同一表型冲突评价都会显式报错。实现不静默吞掉评价器异常，也不把非法输出自动改写成惩罚值。

## 7. 复现命令

```matlab
addpath('matlab');
summary = mdt.runH9FunctionalVerification();
assert(summary.allPassed);
```

全回归：

```matlab
run_tests
```

