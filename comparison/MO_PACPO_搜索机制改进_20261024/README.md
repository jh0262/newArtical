# MO-PACPO搜索机制修正版（2026-10-24）

本目录另存修正版，保留前轮论文、代码、机构模型及全部旧结果。算法配置名`candidate`对应冻结的搜索修正版；`legacy`对应上一轮MO-PACPO。

先读`搜索机制修正与验证报告.md`，公式见`SEARCH_EQUATIONS.md`，事先制定的预算、种子和判据见`PROTOCOL.md`。

## MATLAB入口

进入本目录后：

```matlab
% 原5函数，5算法，每算法30次；现有文件完整时校验并复用
MO_PACPO_Benchmark_Suite_SearchRevised('confirmation');

% 冻结后扩展检查 / 机制消融
MO_PACPO_Benchmark_Suite_SearchRevised('external');
MO_PACPO_Benchmark_Suite_SearchRevised('ablation');

% 2PPaPaR，30次搜索，最终档案提高积分分辨率后重新评价
MO_PACPO_2PPaPaR_Optimization_SearchRevised;
```

测试：

```matlab
addpath(pwd,fullfile(pwd,'reference'),fullfile(pwd,'tests'));
checks=runtests('tests'); assertSuccess(checks);
```

单次使用：

```matlab
addpath(pwd,fullfile(pwd,'reference'));
c=SearchVariants.config('candidate',42);
p=PACPOSearch.problem('DTLZ1');
r=PACPOSearch.solve(p,'PACPO',c);
```

`PACPOSearch.config()`的默认机制仍为`legacy`，用于与旧实现逐项校验。调用修正版时使用`SearchVariants.config('candidate',seed)`或上面两个入口。

## 文件与结果

- `SearchMechanism.m`：局部档案引导、稀疏差分更新、主轴噪声与双锁脉冲。
- `PACPOSearch.m`：共享目标函数、约束支配、选择、档案、评价及诊断。
- `SearchVariants.m`：冻结的正式配置、消融和开发配置。
- `SearchExperiment.m`：种子计划、原始评价保存、续跑和源代码核对。
- `freeze.mat/json`：确认实验前冻结的源码、配置、软件版本和测试通过记录。
- `results/dev01`、`dev02`、`dev03`：全部开发结果与各自源码快照，分别175、200、225次完成运行。
- `results/confirmation`：750次独立确认；`external`：450次扩展检查；`ablation`：750次额外消融；`physical`：30次机构运行及原120次结果的同条件比较。
- `results/external_ablation`：看到扩展脉冲记录后追加的450次机制分析，提出时间与目的见`FOLLOWUP_ABLATION.md`。重算入口：`f=start_external_ablation(); wait(f); SearchExperiment.collect('external_ablation'); analyze_search('external_ablation');`。
- 各阶段的`runs.csv`、`summary.csv`、`paired_statistics.csv`分别提供逐次指标、统计量、配对检验；MAT文件保留全部评价、档案索引、收敛历史和诊断。
- `figures`：PNG预览、矢量PDF和可编辑MATLAB FIG。
- `reference`：旧版核心与已验证机构模型的原样副本。

运行环境为MATLAB R2025b、Statistics and Machine Learning Toolbox、Parallel Computing Toolbox，使用8个本地进程。物理比较复用同级目录`MO_PACPO_机构模型修正版_20261023/results`内的120次基线和原始评价；请连同该目录保存项目。

## 复现与解释

正式运行检查当前源码与`freeze.mat`完全一致；缓存同时核对源码和配置。全部实验N=100、G=250、总评价25,100次。改变算法时应另建实验目录和新种子批次，保留这份冻结记录。

指标中的HV按固定参考盒体积归一化，IGD也使用固定目标缩放。主图为30次运行的中位数和四分位带；`time_to_target.csv`给出共同HV目标的到达次数，以及到达者的首次命中FE中位数。未到达者以NaN记录，不以最终预算假充收敛时间。

配对Wilcoxon使用近似分布；同一阶段、同一指标的所有函数与对照组成一个Holm校正族。`CandidateEffect`为方向统一的配对秩二列相关，正值有利于修正版。机构比较的每个指标单独校正4个对照。

开发批次dev02首次启动时出现MATLAB并行透明工作区中的`which`调用错误；已改为显式路径读取后重启。该失败启动没有形成完整结果批次，完成运行数以保存并审计的记录为准。dev01的新机制边界命中诊断发生在内部截断之后，其该列不能用于边界行为比较；dev02起修正。正式确认的该列记录截断前越界比例。

主轴扰动、成功反馈和双锁的贡献以消融为准。三目标问题的面积裁剪不启用。差分进化与二项交叉的来源见公式文档；这些已有部件不单独作为原创点。

最终日志审计发现，冻结版本的`diagnostic(:,6)`在档案仅一个解时调用`cov`，会得到该行内部的坐标方差。搜索用的`principal`已独立处理单点档案，搜索与全部性能指标不受影响。`audit_variance_diagnostic('confirmation')`及`audit_variance_diagnostic('external')`把该诊断的正确值0另存为派生数据，保留原始日志；`analyze_search`优先读取修正的诊断。逐项改动见各目录的`variance_diagnostic_corrections.csv`。
