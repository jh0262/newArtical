# MO-PACPO机构模型修正版

保留原论文研究对象、原创算法思路及此前纠正的搜索实现。本版用2PPaPaR闭环运动学替换工程代数代理目标，并重新运行工程比较。原稿、原始两个MATLAB程序和此前版本均未覆盖。

## 本版交付

- `MO_PACPO_机械工程学报_机构模型与真实结果修正版.docx`：13页修订论文，36个编号公式、6幅图、7张表、27条参考文献。
- `修订与验证报告.md`：模型与代码修正、测试记录、真实实验结果和表达检查。
- `completion_summary.json`：最终完成状态及论文哈希。
- `physical_run_manifest.json`：120个新机构原始运行文件的SHA-256。

78项MATLAB测试通过；120次机构实验共3,012,000次搜索评价。此前810次基准、消融与扫描结果通过同种子回归核对后保留。文献几何和限位已采用；驱动、几何误差标准差按仿真假设标注。

## 模型依据

蒲志新、郭建伟、潘玉奇、白杨溪：《2PPaPaR并联机构性能分析及优化设计》，中国机械工程，2023，34(19)：2304–2312。DOI：10.3969/j.issn.1004-132X.2023.19.004。

全文保存在 `sources/Pu2023_2PPaPaR.pdf`；尺寸、行程和主动角限位来自该文。驱动误差与八个几何参数的标准差是可调整仿真假设，详见 `MODEL_SPEC.md`。原文式(14)的转角由闭环相减后采用q1−q2；对照文献表2核验。

## 主要文件

- `MO_PACPO_2PPaPaR_Optimization_Physical.m`：工程实验入口，四算法各30次、每次25 100 FE。
- `MO_PACPO_Benchmark_Suite_Physical.m`：基准入口，默认执行新旧核心的同种子回归；也支持main/all/ablation/sensitivity重跑。
- `PPaPaRModel.m`：正逆解、隐式雅可比、几何灵敏度、误差传播与工作域积分。
- `PACPOPhysical.m`：保留原搜索算子、添加真实机构评价分支的共享求解器。
- `PhysicalExperiment.m`：冻结核验、运行、逐次保存与恢复。
- `TestPPaPaRModel.m`、`TestPhysicalSolver.m`、`TestPACPOPhysical.m`：模型和算法测试。
- `benchmark_reference/`：此前冻结的共享基准代码副本，用于回归和独立复跑。
- `results/runs/`：本轮120次运行的原始MAT；包含全部搜索评价、最终档案与逐代历史。
- `results/physical_evidence.json`、`physical_summary.csv`、`physical_statistics.csv`：加密复算后的论文数值和统计。
- `results/physical_candidates.csv`、`physical_representatives.csv`：完整精度候选、来源种子及评价编号。
- `validation/`：积分收敛、非线性误差仿真、同种子回归及测试结果。
- `code_freeze.json`、`results/configuration.mat`：冻结代码、模型积分点及配置。
- `build_physical_manuscript.py`：在保留原边界的稿件上生成新Word；`manuscript_audit/`记录最终核验。

## MATLAB复现

MATLAB R2025b；使用Statistics and Machine Learning Toolbox及Parallel Computing Toolbox。进入本目录后运行：

```matlab
addpath(pwd, fullfile(pwd,'benchmark_reference'));
validate_model;                         % 模型、积分、Monte Carlo核验
freeze_and_run;                         % 核验通过后执行/恢复120次机构实验
summarize_physical;                     % 统一加密复算，统计和TOPSIS
make_physical_figures;                  % 原始数据生成图表
```

已有同配置运行将直接复用。冻结后改动核心代码时，应使用新的输出目录；不能把改动后结果混入已有批次。`freeze_and_run`会检查已有结果保存的源代码。

仅重做测试：

```matlab
runtests({'TestPPaPaRModel.m','TestPhysicalSolver.m','TestPACPOPhysical.m'})
MO_PACPO_Benchmark_Suite_Physical('regression')
```

重新运行全部810次基准、消融和参数扫描：

```matlab
MO_PACPO_Benchmark_Suite_Physical('all')
```

本次保留此前已完成且通过同种子回归的810次结果；其路径和哈希记录在来源清单中。旧120次工程代理模型结果留在此前版本，不进入本版机构统计。

单独使用机构模型：

```matlab
m = PPaPaRModel.config(32768);
s = [400 700 1000 150];                 % a,b,c,d，mm
[F,CV] = PPaPaRModel.evaluate(s,m);     % F=[-体积,位置RMS,-GCI]
g = PPaPaRModel.geometry(s,m);
p = [1000 100 -1250 20*pi/180];         % x,y,z，mm；theta，rad
[u,reachable] = PPaPaRModel.inverse(p,g,m);
[p_check,valid] = PPaPaRModel.forward(u,g,m);
[J,S,A,B,C] = PPaPaRModel.differential(p,u,g);
```

改变误差输入时修改 `m.sigmaQ`、`m.sigmaAlpha`、`m.sigmaG`；转动输入标准差必须使用弧度。改变工作域余量时用 `PPaPaRModel.config(32768,zeros(1,3),eta)`，以同步更新积分变换。

## 指标与统计口径

- 工作空间：对全偏航区间取平均的平移可达体积，cm³。
- 误差：对同一工作域作体积加权的位置RMS，mm。
- 灵巧度：固定1000 mm特征长度下，归一化Frobenius条件指标的体积平均。
- 搜索积分32768点；全部最终档案统一复算262144点；报告代表方案用1048576点和独立偏移检查。
- 最终HV统计使用加密后的目标；逐代曲线保留搜索时原值。
- 120次工程搜索共3012000 FE。后处理加密复算不反馈搜索，另记计算量；与保留的810次基准合计930次搜索、23343000 FE。
- 配对双侧Wilcoxon符号秩检验，三个工程HV对比为一组Holm校正。数值和统计来自保存的运行记录。

误差传播核验采用文献几何下的非线性闭环仿真，误差标准差不是样机测量值。论文按此模型条件解释计算结果。
