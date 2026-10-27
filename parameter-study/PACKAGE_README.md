# 精简复现包使用说明

## 主要结果

416次参数筛查及180次独立确认均为本轮新运行。筛查仅按2PPaPaR工程结果选择N31与N32；DTLZ3作为辅助测试。30个新种子的确认没有支持换用候选参数，保留B（η=0.05、σ下限=0.02、窗口5、脉冲上限0.20）。详细结果见《机构优先参数测试报告》。

## 一条命令重现统计和图形

解压到新文件夹，在MATLAB中将该文件夹设为当前目录，执行：

```matlab
reproduce_derived
```

从保存的逐运行结果表重建：筛查和确认各自的汇总、统计、bootstrap索引，共6张CSV；确认稳定性1张CSV；7组PNG/PDF图形。该步骤只处理保存数据，不调用优化器。

验证环境为MATLAB R2025b。统计代码使用Statistics and Machine Learning Toolbox；完整试验并行执行还需Parallel Computing Toolbox。

Python独立核算和中文报告生成：

```text
python -X utf8 scripts/independent_verify.py --portable
python -X utf8 scripts/report.py
```

Python核算需要NumPy、pandas；已在Python 3.12.14、NumPy 2.3.5、pandas 3.0.1环境验证。独立实现复算HV、DTLZ3目标与IGD、AUC、达标次数、符号秩检验、Holm校正及bootstrap区间。portable模式跳过原电脑的旧目录校验；原电脑核查记录保留在audit中。报告生成后图形链接指向当前解压目录。

## 包内数据与本地完整数据

- `data/`：596次运行的逐种子指标、最终解集与目标/约束、完整HV曲线、阶段机制诊断、候选选择、统计表和bootstrap索引。
- `results/confirm/`：两个问题各一条B组完整原始轨迹（PPAR种子951001、DTLZ3种子952001），以及对应状态和工程复评。
- `code/`：本轮参数执行器、原算法的类名前缀副本及未改变的机构模型。
- `scripts/`、`tests/`：统计、图形、独立复算、参数生效诊断和13项MATLAB测试。
- `PROTOCOL.md`、`freeze.mat`、`audit/`：运行前规则、冻结来源、数值核对、旧文件保留检查和包内清单。

596条完整搜索轨迹及最终档案复评保留在原电脑：

`F:\暑假原始资料\论文总项目_20261013\MO_PACPO_机构优先参数测试_第三轮_20261027\results`

精简包提供重建全部主要统计和图形的数据；完整的逐决策点机制复查使用上述本地全量轨迹。`audit/package_contents.json`列出包内文件SHA256。

## 重跑一条真实搜索

```matlab
rerun_search('PPAR','B',951001,'F:\existing_output_folder\new_run.mat');
```

父文件夹需已存在，目标文件需为新路径。该命令执行25,100次真实搜索评价。完整两级积分复评由`ERStudy.one`执行器处理。所有历史程序、结果和论文均另行保留。
