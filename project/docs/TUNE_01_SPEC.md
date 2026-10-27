# TUNE-01 隔离调参执行规范

状态：`AUTHORIZED_FOR_TUNE_01_ONLY`  
授权记录：`.light/e2/tune_authorization.json`  
日期：2026-08-30

## 1. 授权与科学边界

本阶段只在未进入 E2 确认集的 held-out 实例上，为 B0、B1 各冻结一个参数配置。调参结果不回答 H2，不进入 P1/P2 统计，不支持算法优越性或通适性表述。P1/P2 仍未授权。

## 2. 输入、输出与流程

### Input

- 实例：`D-5-3-L`；`family=D, q=5, L=3, rho=0.25, lambda=1`；
- 解析真值：25 个 Pareto 相关分量；
- 种群规模：`N=max(100,4Kp)=100`；
- 评价预算：`B=500N=50000`，含初始种群；
- 外部档案容量：100；
- 调参 seed：`2026083001:2026083005`；
- 数值环境：MATLAB R2025b、CPU、double、局部 `RandStream('mt19937ar')`。

### Output

- 240 个不可覆盖的 run bundle：`24 configs × 5 seeds × 2 algorithms`；
- 每 run 的 config、环境、源码/输入 hash、raw metrics、最终种群、最终档案、guardrails、stdout/stderr 和 manifest；
- B0/B1 各一个冻结 winner；
- 同 seed 独立复跑证据、资源计量、失败清单和 coverage；
- `tune_results.csv`、`winner_b0.json`、`winner_b1.json`、`tune_manifest.json`。

### Process

冻结规范与源码 → 全量测试/静态检查 → 为每个算法逐配置、逐 seed 固定预算运行 → 保留所有成功/失败 run → 按算法分别聚合 → 冻结 winner → winner 同 seed 复跑 → hash/manifest 门 → 阶段报告。

### Flow logic

初始化 held-out 实例和真值 → 同 seed 生成初始表型 → 每代使用 `seed+generation` 共享调度 → B0 或 B1 生成后代 → 同一评价、约束处理、环境选择和有限档案 → 到 50000 NFE 停止 → 写 run bundle → 完成全部 coverage 后按预注册规则选择配置。

## 3. 冻结网格

### B0：24 个配置

- `F ∈ {0.30,0.45,0.60,0.75,0.90,1.05}`；
- `CR ∈ {0.20,0.45,0.70,0.95}`；
- `FCategory=0.50` 仅为接口占位，不参与 B0 计算。

### B1：24 个配置

- `F ∈ {0.30,0.50,0.70,0.90}`；
- `CR ∈ {0.20,0.50,0.80}`；
- `FCategory ∈ {0.25,0.75}`。

两个算法配置数、seed 数、NFE、N、档案容量、评价器和选择机制完全相同。B0 在 F/CR 上更密，B1 用相同总配置数覆盖新增的 FCategory 维度。

## 4. 配置选择规则

对 B0、B1 分别选择，不比较两算法调参结果。按下列顺序作确定性字典序选择：

1. 最大化 5 seeds 的 median AUC_PCR；
2. 最大化 worst-seed AUC_PCR；
3. 最大化 median final PCR；
4. 最大化 median final HV；
5. 最小化 median offspring duplicate rate；
6. 仍并列时选择字典序最小的 config ID。

缺少任一 config×seed 的成功 run 时不得冻结 winner；先分类失败并补齐同一冻结配置的独立 attempt。不得删除较差结果，不得查看 P1/P2 outcome 后回改调参规则。

## 5. 指标与 guardrails

- 调参 primary：AUC_PCR；
- tie-break：worst AUC_PCR、final PCR、final HV、duplicate rate；
- G-SOFTWARE：全量测试 0 failed，Code Analyzer 0 issues；
- G-PAIR：固定相同实例、N、B、档案、seed 规则和指标；
- G-FEAS：记录 no-feasible checkpoint rate；不删除无可行解 run；
- G-HV：仅记录，TUNE 阶段不据此作 H2 判决。

## 6. 停止与失败

- 每 run 固定 50000 NFE；禁止因当前指标好坏提前停止；
- timeout、异常或写盘失败均保留 failure artifact，不标 completed；
- 资源上限：本地 CPU，零外部费用；若累计 walltime 超过 60 分钟或磁盘增量超过 2 GB，停止新增 run 并报告，不自动缩减配置/seed；
- 本阶段最多 240 个 selection runs，另允许 winner 的固定 seed 复跑验证，不扩展到 P1。

## 7. 证据边界

TUNE-01 只能给出“后续 P1 应使用的冻结参数”。即使 B1 的调参 AUC_PCR 数值更高，也不得称 B1 优于 B0，因为 held-out 调参实例及同一数据上的配置选择会产生选择偏差。

