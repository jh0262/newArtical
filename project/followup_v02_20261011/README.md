# 第二轮复核入口

已批准并完成：120 次，3,847,680 FE，单 MATLAB 进程，批次 242.614 s。报告见 RESULTS_zh.md。原 420 次未改动，新旧统计不合并。

在上一级 10_dynamic_mode 目录执行：

```powershell
python -X utf8 followup_v02_20261011/prepare.py --check
python -X utf8 followup_v02_20261011/analyze.py
python -X utf8 followup_v02_20261011/verify_results.py
```

analyze.py 需要 Python/NumPy/SciPy，并复用上一级 analysis_formal/analyze_formal.py 的已验证精确统计函数。它重建派生统计，不重新优化。verify_results.py 需要已经存在的 MATLAB 重放结果；重新生成时按以下顺序运行 MATLAB：

```matlab
addpath(fullfile(pwd,'followup_v02_20261011'));
counterfactuals();
plot_results();
```

counterfactuals 读取保存目标，不调用物理模型。verify_results 再独立检查其 CSV 恒等式。原优化入口 v2_study 会拒绝覆盖已有 MAT/日志；查看或复核结果不应重启优化。

图注：final_HV 每点对应一个独立种子，竖线为四分位范围，黑线为中位数；paired_effects 为均值差的逐项 95% bootstrap 区间，非同时区间；history_vs_final 的每点对应一次运行，无界历史不是公平在线算法，虚线为相等线。两面板坐标范围不同。三张 PNG 已打开目视核查，均可读；PDF 已生成但未独立逐页渲染。

MATLAB R2025b；Python 3.14.7、NumPy 2.5.2、SciPy 1.18.0 沿用本机。Python 启动器会输出 real location 提示，但实际分析及审计成功；该提示不作数据错误处理。

结果包含完整评价历史、约束及种群/档案 ID。累计代际增益和损失会重复计入曾经恢复的区域，不能作净区域损失。所有工程输出是显式假设模型预测，没有实物、FEM 或伺服闭环验证。
