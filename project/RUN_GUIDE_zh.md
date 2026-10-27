# 运行与复核

## 环境

实际使用 MATLAB R2025b；Python 3.14.7、NumPy 2.5.2、SciPy 1.18.0。Sobol 对照使用 Statistics and Machine Learning Toolbox。ODE 核验与数据审计只依赖 NumPy/SciPy，不依赖 pandas/matplotlib。原始目录 PDF 的可视检查使用本机 PyMuPDF，运行优化不需要 PDF 包。

项目目录可整体移动；目录参数和 4 个依赖函数已存入本目录。引用的原 v2.4 稿件和 EarClip 原研究用于来源追溯，不是本包运行时依赖。

## 重现模型检查

MATLAB 中将工作目录切换至本目录，再执行：

```matlab
addpath(fullfile(pwd,'matlab'));
addpath(fullfile(pwd,'matlab','vendor'));
bs_model_pilot();     % 21,601 次模型结构筛查评价，不是正式算法比较
bs_preflight();       % 数学性质、约束排序和重复运行检查
```

PowerShell 中执行：

```powershell
python -X utf8 .\verification\verify_ode.py
python -X utf8 .\verification\audit_package.py
```

注意：模型/图表复现会更新对应生成文件；原始 v0.1 与 before_mating_audit 文件保留用于历史追溯。不要把不同版本结果合并。

## 复现当前短程结果

```matlab
bs_algorithm_pilot();
p=bs_config(); p.cycle_limit_s=3;
result=bs_qmc(92102,64,100,p);
save(fullfile(p.root,'pilot_v02','CAT-QMC_seed92102.mat'),'result');
bs_two_mode_check(); bs_plot_screening(); bs_export_pilot();
```

7 个当前试算均为 64 个体、100 代、6,464 FE，合计 45,248 FE。它们不替代正式协议的 500 代、20 次重复。

## 正式实验（已获准并完成）

用户“继续实验”已授权原定单进程、最多 30 分钟、420 次/13,466,880 FE 的预算；原生 ARIS 和 `provenance/FORMAL_AUTHORIZATION.md` 已记录。420 次全部完成，日志耗时 374.5 s。冻结协议中的待答复句子是历史状态，保留原文以维持哈希；当前授权与完成状态以原生记录为准。

原执行入口为 `bs_run_study(1800)`。已有完整结果，无需为查看结果重新优化。脚本不覆盖正式文件；独立复现须保留本包并明确新的输出位置与预算，不应删除现有结果重来。时限按运行间检查。

## 只复核已保存结果

在本目录运行以下命令，不产生新优化评价。派生分析文件将更新，原始 MAT/CSV 不变。

```powershell
python -X utf8 .\freeze_manifest.py --check
python -X utf8 .\analysis_formal\analyze_formal.py
python -X utf8 .\analysis_formal\diagnose_nested_cases.py
python -X utf8 .\analysis_formal\verify_delivery.py
```

其他诊断、工程选点、绘图与稿件重建见 `analysis_formal/README.md`。ODE 校核是模型实现 verification，最终点同模型复算是结果一致性检查，均不构成实体 validation。
