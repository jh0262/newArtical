# MO-PACPO P1修正版

本目录依据2026-10-24复审报告另存。保留MO-PACPO主轴投影、超体积双锁、面积档案维护及2PPaPaR四尺寸三目标研究范围。原论文、原程序与历次实验目录均保留。

## 程序入口

MATLAB R2025b，依赖Statistics and Machine Learning Toolbox；批量运行另需Parallel Computing Toolbox。

```matlab
cd('F:\暑假原始资料\论文总项目_20261013\MO_PACPO_P1修正版_20261024')
% 一个基准运行：100个体、250代、25100次评价
r = MO_PACPO_Benchmark_Suite_P1('ZDT1','revised',711001);
% 一个机构运行及262144点档案复核
r = MO_PACPO_2PPaPaR_Optimization_P1('revised',400001);
% 全部实验、验证及结果图复现，已有同源结果按缓存复用
reproduce_p1
```

变体：revised、oldArea、Diagonal、noNoise、noLock、noEC、Fixed、GDE3。模型参数、误差假设和统一预算见PROTOCOL.md与reference/PPaPaRModel.m。

## 修改与证据位置

- PACPOP1.m：逐次面积删除、邻域重算及间距并列规则；保留三目标维护与搜索机制。
- P1Stats.m：统一有限配对掩码、有效/缺失配对数、Holm校正与结果标签。
- P1GDE3.m：公开GDE3结构的矩阵适配，来源及适配差异见sources。
- P1Experiment.m、freeze.mat：预设运行列表、冻结源码、逐次原始结果与失败记录。
- P1Numerics.m：共同积分点/偏移下的完整档案重评价、TOPSIS近优组、非线性扰动与误差分组。
- P1ExtendGDE.m：补齐GDE3全部30档案的百万点与共同偏移复核；不重新搜索。
- P1Replay.m：完整25100评价预算的精确序列回归。物理重放用于检查仪器化日志，不计入独立重复数。
- results：逐次结果、汇总、统计及收敛数据；validation：数值验证原始数据；audit：核对与原文件保护记录。

复用输入位于同级的MO_PACPO_搜索机制改进_20261024、MO_PACPO_机构模型修正版_20261023及MO_PACPO_论文同步修订_20261024。运行记录保存源代码快照，派生结果保存输入路径。不要单独搬走本目录后假定复用输入仍存在。

优化与数值验证使用不同进程批次，运行耗时不作为算法优越性的证据。正负结果均保留；统计显著性、效应幅度和积分敏感性分别报告。

论文与记录：`MO_PACPO_机械工程学报_P1问题修正与真实结果修订稿.docx`、`P1逐项修订与验证记录.md`。全部搜索结果已完成；`reproduce_p1`会校验并复用保留结果，重新生成派生表图。
