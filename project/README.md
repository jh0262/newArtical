> **适用范围纠正（2026-10-15）：** 本文件记录另写的PADE-FE v4分支，不是原始PADE代码的原样复现。其中性能结果不替换原论文PADE–DE比较或文献表；由该分支推广到原论文创新性、发表潜力及改题要求的判断已撤回。本分支单独归档，不再执行优化实验。当前依据见[评审范围纠正](F:/暑假原始资料/论文总项目_20261013/新论文/论文修订_20261015/评审范围纠正与原稿修订依据.md)。

# PADE同父等评价预算比较与机制消融

本目录落实2026-10-15用户授权的补充实验与论文修订。接受作者原始数据来自真实运行；原稿和三份源代码保留在上级目录。本轮使用统一的PADE-FE v4实现，检验新增机制相对于实际自适应DE父算法的增量，原代数实验与新FE实验分别保存。

**已完成5640次正式运行、194577300 FE及全量审计。** Holm校正后，完整PADE相对同父算法为0有利/20未显著/6不利，相对经典DE为14/12/0；核心消融没有校正后正向增益。上述结论仅限本PADE-FE v4实现，不用于判断原始PADE论文的发表潜力。

该分支历史交付（不作为当前原稿主稿）：[24页完整v4 Word](manuscript/PADE_Mechanical_Optimization_Full_Paper-v4.docx)、[更新评审与必改项台账](必改项落实与更新评审.md)、[最终交付与哈希清单](DELIVERY_MANIFEST.json)。原始观测及原输入均未改。

## MATLAB入口

在MATLAB R2025b中执行：

```matlab
cd('F:\暑假原始资料\论文总项目_20261013\新论文\补充实验_20261015');
addpath('code');
report = pade_reproduce;
```

入口先验证冻结文件SHA-256，再恢复缺失运行，审计全部记录，完成配对统计、工程解回代和图表导出。已有同版本完整运行直接复用。需要六进程Parallel Computing Toolbox；统计与图表在同一MATLAB环境中完成，不要求用户安装Python。论文构建所用Python与OfficeCLI仅用于Office交付，不参与优化搜索。

只作后处理时，可分别调用：

```matlab
audit = pade_audit_runs(pwd);
cfg = jsondecode(fileread('CONFIG.json'));
cmp = readtable('comparisons.csv','TextType','string');
stats = pade_analyze('raw','results',cmp, ...
    ExpectedRuns=30,ExpectedSeeds=1001:1030, ...
    ExpectedProblems=string({cfg.problems.id}), ...
    FeasibilityTolerance=0,RequireEqualFE=true,AllowPartial=false);
engineering = pade_engineering_details('raw','results');
plots = pade_plot_results('results','figures');
```

## 比较范围

- 26个问题：F01—F23及焊接梁WB、悬臂梁CB、压力容器PV。
- 几何G0/G1/G2分别为原坐标、主轴交叉、主轴交叉加谱尺度；P为双锁脉冲；PV另有普通trial邻网格抖动J0/J1。连续问题六配置，PV十二配置，均另加经典DE。
- 自适应父算法为G0P0J0；完整连续PADE为G2P1J0，完整PV为G2P1J1。经典DE为固定F=0.5、CR=0.9的DE/rand/1/bin。
- 同一问题30种子1001—1030，完全相同初始种群。初始化、每次trial和每个pulse候选均计1 FE，严格在预算处停止。
- 单次预算：F01—F13为30030 FE；F14—F23为15030 FE；工程问题为100040 FE。188单元、5640成功运行、194577300正式搜索FE。
- 五个26题比较家族与PV六对J比较均在运行前写入`comparisons.csv`；各家族内Holm校正。精确配对检验、效应量、逐对观测和未显著/不利结果一并导出。

详见`PROTOCOL.md`。当前数据不用于选择新超参数、删种子或选择性重跑。

## 文件说明

| 位置 | 内容 |
|---|---|
| `code` | 同父求解器、问题库、运行入口、审计、统计、绘图、工程回代与实现诊断 |
| `raw/问题ID` | 每题每配置每种子的独立MAT结果，包含完整精度解、FE、共同检查点、改进事件、初始/最终种群及机制记录 |
| `results` | 188配置统计、预设比较、Holm、逐对观测、共同FE轨迹与工程约束残差 |
| `figures` | 正式结果的中英文PNG、PDF、可编辑FIG及各图源数据 |
| `manuscript` | 完整v4 Word正文及可追溯构建材料 |
| `qa` | 实现诊断、软件信息、独立全量审计、失败重启记录和Word版面核对 |
| `failures/attempt01` | 首次保存路径错误的367份失败日志，保留但不纳入成功样本 |
| `FROZEN_MANIFEST.json` | 冻结求解器、模型与协议文件哈希 |
| `INPUT_MANIFEST.json` | 原始输入哈希 |
| `LITERATURE_COMPARISON.md` | 最接近原始工作的全文/预览证据及机制差异 |
| `必改项落实与更新评审.md` | 根据本轮实际完成结果更新的评审与修改台账 |

## 结果版本与开销

v4以实际FE比例控制暖启动/脉冲截止，使用统一精确可行优先排序、即时最佳记录及正确的变量下界修复。它是本轮公平比较的明确实现版本，不把新结果混写为原稿原设置的同一批重复运行。

新统计采用锚点中心化计算均值和样本标准差，常量样本精确返回原值及Std=0，避免普通浮点归约产生“均值小于最小值”等末位残差。该修复不修改raw、比较秩和p值；原稿历史统计独立保留。

首次并行保存层错误已修复并通过真实并行写盘诊断；求解器、配置和种子没有据此改变。失败尝试中已完成但未保存的搜索开销推得为11651400 FE，取消中部分开销未完整捕获。失败与诊断另记，详见`qa/IO_RETRY_RECORD.md`。194577300 FE是正式成功样本的精确总额，不冒充全部开发尝试总开销。

原始五张数据表继续保存在上级`论文修订_20261015/analysis`及v2/v3稿中。文献报值为各来源设置下的参照，不并入本轮同预算显著性检验；F15与PV采用作者实际常数版本。
