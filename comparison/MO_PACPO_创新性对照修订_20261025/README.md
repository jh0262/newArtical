# MO-PACPO方向触发对照及MOCPO文献复现

本目录保留原研究边界：多目标冠豪猪搜索机制改进及2PPaPaR刚体3T1R机构四尺寸三目标设计。原稿、原程序、原实验保持原位，新文件全部另存。

## 实验与复现

- 四组同框架比较：DL（原Full）、DR、SL、SR。新增810次搜索；270个Full结果逐点重放验证并复用。
- 最近文献MOCPO：根据Adalja等2025的公式及伪代码复现。F/R两种IFM标量解释，共540次搜索。原文未明确细节、固定参数和固定种群适配见BASELINE_PROTOCOL.md。实现不是作者发布源码。
- 每次25100次评价，全部1350次新增搜索共33885000次评价。每配置30次，种子配对。中间CPO与反馈后解均计数；两种算法的代数不同，按FE比较。
- 机构最终档案采用共同262144和1048576积分点复核。

入口：MATLAB R2025b，Statistics and Machine Learning Toolbox、Parallel Computing Toolbox。

```matlab
cd('F:\暑假原始资料\论文总项目_20261013\MO_PACPO_创新性对照修订_20261025')
reproduce_innovation
```

已有匹配源码结果复用；缺失运行才执行。原Full重放需要相邻保留的P1、机构消融和搜索机制改进目录。禁止以重放次数增加独立重复数。

MATLAB统计完成后，独立复核使用本机已有Anaconda环境（Python 3.8、NumPy 1.24.3、SciPy 1.10.1、pandas 2.0.3）：

```powershell
& 'C:\ProgramData\anaconda3\python.exe' -X utf8 .\verify_analysis.py
```

Word构建及渲染页处理使用Codex文档运行时的Python；统计复核和文档构建使用不同环境，环境记录见`audit/independent_runtime.json`。论文构建入口`build_revision.py`要求独立统计检查已通过，并读取`editorial.json`中的已核实正文；`render_word.ps1`以只读方式使用Word导出内部校对PDF，`render_pages.py`生成页图，`final_check.py`检查数字、结构及原件保全。

## 文件

- PROTOCOL.md、BASELINE_PROTOCOL.md：运行前冻结的设计与文献复现细节。
- code/：新MATLAB实现；tests/：方向、范数、门控、Full轨迹、公式、IFM及预算测试。
- results/runs/：完整评价、最终种群/档案、历史、随机种子、配置、源码和成功/失败状态。
- validation/：机构最终整个档案的共同积分复核。
- data/：逐次指标、五项方向/触发/交互检验、MOCPO比较、bootstrap索引与曲线。
- analyze_innovation.m、verify_analysis.py：MATLAB统计和独立Python复核。Python重读MAT完整精度数据，避免CSV舍入改变秩检验。
- figures/：由真实结果生成的PNG、矢量PDF及可编辑MATLAB图。
- audit/：原件哈希、验证记录、文档保全、表达检查及Word原生渲染。
- sources/：核实后的出版社文献HTML/PDF与公式页。

## 已完成的交付

- [24页单栏修订稿](MO_PACPO_创新性对照修订稿_单栏.docx)
- [修改说明](修改说明.md)
- [补充材料S7](补充材料S7_机制对照与MOCPO复现.md)
- [S1—S6原补充材料](../MO_PACPO_王联国范文写法修订_20261024/MO_PACPO_实验与数值验证补充材料.docx)

程序、真实实验、独立统计复核、正文更新、24页视觉检查及anti-defensive-writing全文检查均已完成。实际状态见STATUS.json。完整算法与文献复现配置的比较支持条件下的性能收益；方向与触发的独立增益未显著，正文据实保留。
