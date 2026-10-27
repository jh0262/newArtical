# 2PPaPaR机构优先的MO-PACPO参数测试（第三轮）

本轮按工程目标选择参数。DTLZ3提供多峰收敛机制的辅助证据。模型、原创算法机制、搜索预算及旧程序/结果保持不变。

已完成416次筛查与180次独立确认，每次25,100次搜索评价。两个筛查候选在30个新种子的工程确认中没有获得改善，保留默认参数B：η=0.05、σ下限=0.02、停滞窗口5、脉冲上限0.20。

## 阅读顺序

1. `PROTOCOL.md`：运行前冻结的参数、种子、指标、候选选择与统计规则。
2. `data/selection.json`：筛查完成后由机构结果自动选出的候选；确认开始前保存。
3. `机构优先参数测试报告.md`：完成后生成的结果、机制解释和参数建议。
4. `audit/independent_verification.json`：数据与统计的独立核算及旧文件保留检查。

## 运行与复现

环境：MATLAB R2025b、Statistics and Machine Learning Toolbox、Parallel Computing Toolbox。主要统计和全部图形由MATLAB重现。独立核算及报告生成使用Python、NumPy、pandas。

在本目录执行下列命令，直接重现保存数据的7张统计CSV和7组PNG/PDF：

```matlab
reproduce_derived
```

该入口不启动搜索。精简复现包的内容、依赖与完整轨迹位置见`PACKAGE_README.md`。

完整试验的执行流程如下：

```matlab
futures = resume_experiments('screen');
% 等全部运行完成并核查status，再执行：
addpath('scripts'); ERAnalysis.collect('screen');
ERAnalysis.summarize('screen'); ERAnalysis.statistics('screen');
ERAnalysis.select(); % 只允许第一次选择，保留已冻结的selection.json
futures = resume_experiments('confirm');
% 等全部运行完成并核查status，再执行：
ERAnalysis.collect('confirm');
reproduce_derived;
```

独立核算：`python scripts/independent_verify.py`；报告生成：`python scripts/report.py`。移至其他电脑后可用`python scripts/independent_verify.py --portable`核算数据，跳过原电脑旧目录的文件校验。

单条真实搜索重跑：

```matlab
rerun_search('PPAR','B',951001,'F:\existing_output_folder\new_run.mat');
```

该入口仅进行25,100次搜索并保留原始轨迹；两级最终档案复评由完整试验执行器负责。选择新的输出路径，避免覆盖原记录。

## 目录

- `code/`：上一轮算法的类名前缀副本、原机构模型及新参数执行器。
- `tests/`：轨迹等价、预算、门控/幅值及统计对照验证。
- `results/screen`、`results/confirm`：原始MAT、细积分MAT与每次状态。
- `data/`：逐种子指标、完整HV曲线、阶段机制诊断、统计与候选冻结记录。
- `figures/`：从保存数据直接生成的图形。
- `failures/`：失败现场，保留原始评价、RNG、history及堆栈。
- `audit/`：冻结来源、预算、测试、独立核算、旧文件SHA256与复现检查。

搜索评价、最终复评和审计抽样评价分别计数。机构最终HV衡量计算模型内的解集质量；几何参数和误差假设沿用原研究。本轮不修改论文。
