# SparseLedger v1.0 技术规格

## 定位

SparseLedger解决B5显式访问计数向量需要`O(Q)`持久内存的问题。它只保存已经被评价的离散状态，因此当评价次数`E << Q`时，持久内存为`O(V)`，其中`V≤E`为已访问状态数。

SparseLedger不判断可行性、不读取真实连通分量，也不改变B5的目标函数、约束处理、DE算子或环境选择。

## 数据契约

```matlab
ledger = mdt.makeSparseLedger(stateCount);
ledger = mdt.observeSparseLedger(ledger, evaluatedRanks);
counts = mdt.querySparseLedger(ledger, queryRanks);
[ranks, audit] = mdt.selectLeastVisitedSparse( ...
    ledger, selectionCount, seed, "affine");
```

账本由以下字段组成：

- `stateCount`：总离散状态数，要求不超过MATLAB `flintmax`；
- `ranks`：严格递增的已访问零基状态编号；
- `counts`：对应的正整数评价次数；
- `totalObservations`：累计评价数；
- `storedStateCount`：已访问状态数。

状态编号使用通用混合进制编码，允许每个离散变量具有不同基数：

```matlab
ranks = mdt.encodeMixedRadixState(states, cardinalities);
states = mdt.decodeMixedRadixState(ranks, cardinalities);
```

## 两种调度器

### legacy

使用与B5-Ref相同的`randperm(Q)`随机tie-break。它可以在小Q场景逐位复现B5-Ref的注入行和状态，但仍产生Q长度临时排列，因此不用于大Q。

### affine

使用隐式排列

`rank(p) = (offset + p × step) mod Q`

其中`gcd(step,Q)=1`，所以在`p=0,…,Q−1`范围内每个状态恰好出现一次。模乘使用`uint64`加倍法，避免`p×step`超过双精度精确整数范围。每次选择仍检查全局最小访问次数，但不物化Q长度排列。

## 复杂度边界

- 持久内存：`O(V)`；
- 批量观测合并：当前排序数组实现为`O((V+B)log(V+B))`，`B`为批量新增评价数；
- 单状态查询：二分查找`O(log V)`；
- 仿射调度：若大量未访问状态存在，通常只扫描排列前部；最坏仍可能扫描`O(Q)`候选；
- 当所有Q个状态最终都被访问时，任何精确逐状态计数方法仍需保存`O(Q)`信息。

因此，SparseLedger解决的是`E << Q`阶段的内存问题，不是对组合爆炸的理论消除。

## 算法身份边界

- `B5-Ref`：H7验证过的稠密计数版本；
- `B5S`：SparseLedger与隐式仿射tie-break的开发版本；
- `legacy`兼容模式：用于小Q回归，不用于大Q运行；
- B5S的优化性能必须经过新的冻结比较后才能形成论文主张。

当前`mdt.runOptimizer("B5S",...)`仍使用自建基准真值生成指标，因而完整runner仍受真值枚举规模限制。SparseLedger模块本身已与真值解耦，可供后续通用黑箱runner使用。
