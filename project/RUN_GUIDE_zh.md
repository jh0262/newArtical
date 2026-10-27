# MATLAB 多机制 MODE 实验使用说明

优化算法、消融机制、统计分析和图表均由 MATLAB 实现。Python 只用于文件哈希、独立数值复核、统计交叉核对和报告组装。

## 已固定的实验

- 13 个算法/消融配置，8 个双目标问题，每项 20 个随机种子，共 2,080 次正式运行。
- 每次种群 100，初始化后再进化 500 代，优化阶段严格使用 50,100 次函数评价。最终目标值重算属于独立核验，不向优化器反馈。
- `Gabc` 的三位开关分别表示 A 耳切删减、B 几何选亲、C 自适应算子分配。八个 G 组都使用相同的 F/CR 成功历史适应规则。
- `MODE_FIXED` 使用固定 F=0.5、CR=0.9，两个 DE 策略各以 0.5 概率调用。它是本研究明确定义的基础 MODE，并不声称是唯一标准 MODE。
- `NSGAII`、`SPEA2`、`MOEAD` 使用存档的 PlatEMO 源文件；MOEAD 明确采用 Tchebycheff 聚合选项。`G111_SHUFFLE` 打乱几何权重和引导解的对应关系。

## 复现现有结果和图表

在项目目录打开 PowerShell：

```powershell
.\reproduce_results.ps1
```

该命令重新读取全部原始 MAT 文件进行独立数值复核，再用 MATLAB 重算统计表与图，并生成报告；不会重新优化或改动原始运行记录。

## 单独运行或修改策略

在 MATLAB 切换到此项目目录：

```matlab
ec_setup;
c = ec_config('formal');
% 第1个问题ZDT1，第8个算法G111；输出目录必须尚不存在。
r = ec_run_one(c,1,8,41001,fullfile(pwd,'verification','my_independent_G111'));
```

独立复跑两次完整500代并自动检查一致性：

```matlab
ec_reproduce500;
```

全部测试：

```matlab
ec_setup; addpath('analysis');
results = runtests('tests');
assert(all([results.Passed]));
```

继续尚未完成的原始实验：

```powershell
.\run_study.ps1 -Workers 8
python scripts\audit_results.py --status
```

已完成的运行会跳过。失败记录保留在独立 attempt 目录；更改优化器或预算后不得继续写入旧的 `formal_v1` 实验，必须另建版本并登记变更。完全重做整个矩阵时，可建立项目副本，仅复制源代码、vendor、provenance和运行脚本，不复制原有 runs 目录；冻结源文件内容保持一致即可。

## 文件位置

- `src/GECMODE.m`：优化主循环；`ec_offspring.m`：两类 DE 变异、交叉和参数采样。
- `src/ec_earclip.m`：含累计离散覆盖损失约束的耳切删减。
- `src/ec_guide_weights.m`：几何选亲权重；`ec_credit.m`：固定观察窗口下的收益；`ec_adapt.m`：F/CR 和策略分配更新。
- `provenance/experiment_matrix.csv`：全部正式运行计划；`code_manifest.json`：冻结身份。
- `runs/formal_v1/<问题>/<算法>/<种子>/<attempt>/raw.mat`：初始/最终决策、每代目标值、指标、适应轨迹和随机数状态。
- `analysis/results/`：完整表格、独立核验、统计结果和图；`RESULTS_zh.md`：中文研究分析。

## 环境与可解释边界

已运行环境为 Windows、MATLAB R2025b。本地 MATLAB 启动需正常用户文件系统权限；沙箱内启动曾失败，正常用户环境已验证可用。经典 PlatEMO 实现依赖 Statistics and Machine Learning Toolbox 的部分函数。Python 审计需要 NumPy 和 SciPy；实际版本与文件哈希保存在验收工件中。

F/CR、算子调用概率和几何删减容差具有数据适应机制，但记忆长度、采样宽度、学习率、概率下限等仍是固定超参数。所有这些值已记录在配置中，未根据正式结果进行调参。

本轮仅证明所列解析双目标问题上的实现和实验结果，不代表多于两个目标、离散变量、工程约束、有限元或物理实验验证。高维目标需要重新定义邻接和删减机制。

## 统计分辨率说明

跨问题推断以8个问题为单位，不能把20个种子当成额外的独立问题。对8对非零差值，双侧精确Wilcoxon的最小p值为2/2^8=0.0078125；12项比较的Holm第一步最小校正值为0.09375，7项交互检验为0.0546875。因此这两组校正在本设计下不能达到0.05。报告保留这一结构性限制，展示逐问题效应、置信区间和Friedman总体差异，不把未达到显著性解释成算法等价，也不事后换检验追求显著。
