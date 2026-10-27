import json,csv
from pathlib import Path
ROOT=Path(__file__).resolve().parent;OUT=ROOT/'results'
def read(name):
    with (OUT/name).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
summary=read('summary.csv'); comps=read('paired_comparisons.csv');coverage=read('coverage.csv');runs=read('training_runs.csv')
audit=json.loads((OUT/'audit.json').read_text());phys=json.loads((ROOT/'physics_run/manifest.json').read_text());cfg=json.loads((ROOT/'config.json').read_text())
labels={'physics':'共同拟合后的纯物理模型','velocity':'瞬时速度补偿','capacity_control':'同参数量的瞬时速度对照','history':'历史速度补偿','ann_only':'纯神经网络'}
reg={'all':'完整轨迹','low_speed':'低速区间','reversal':'换向区间'}
def value(model,regime):return next(x for x in summary if x['model']==model and x['regime']==regime)
def show(model,regime):
    r=value(model,regime)
    return f"{float(r['nrmse_mean']):.6f}"+(f" ± {float(r['nrmse_sd']):.6f}" if int(r['n_runs'])>1 else '（单次）')
table='\n'.join('| '+labels[m]+' | '+' | '.join(show(m,r) for r in reg)+' |' for m in labels)
ctable='\n'.join(f"| {r['seed']} | {reg[r['regime']]} | {float(r['history_change_vs_velocity_percent']):+.2f}% | {float(r['history_change_vs_capacity_percent']):+.2f}% |" for r in comps)
better={r:sum(float(x['history_over_capacity'])<1 for x in comps if x['regime']==r) for r in reg}
guard=sum(x['overall_guardrail_pass']=='True' for x in comps if x['regime']=='all')
hist=float(value('history','all')['nrmse_mean']);vel=float(value('velocity','all')['nrmse_mean']);cap=float(value('capacity_control','all')['nrmse_mean']);ann=float(value('ann_only','all')['nrmse_mean'])
coverage_table='\n'.join(f"| {r['joint']} | {float(r['low_threshold_rad_s']):.6f} | {r['low_speed_samples']} | {r['reversal_events']} |" for r in coverage if r['split']=='test')
termination={k:sum(r['termination']==k for r in runs) for k in sorted(set(r['termination'] for r in runs))}
recovery=', '.join(audit['recovered_exports'])
text=f'''# 第4步：重跑分析与结果

研究对象：Retzler等（2024）公开重载机器人数据。研究问题沿用第2步：加入过去速度能否改善低速/换向预测，并保持完整轨迹表现？

## 结果判断

**本轮已实际完成数据处理、共同物理参数拟合、四类模型的三种子对照、离线多步预测及结果汇总。运行可行性已获得本机证据；历史信息是否构成独立、稳定的改进，要看同参数量对照，不能只看它相对小输入模型的变化。**

完整轨迹上，历史模型平均NRMSE为{hist:.6f}，瞬时速度模型为{vel:.6f}，同参数量对照为{cap:.6f}，纯神经网络为{ann:.6f}。历史模型相对瞬时速度模型的均值变化为{100*(hist/vel-1):+.2f}%，相对同参数量对照为{100*(hist/cap-1):+.2f}%。负值表示误差下降。

历史模型优于同参数量对照的种子数：完整轨迹{better['all']}/3、低速{better['low_speed']}/3、换向{better['reversal']}/3。预设完整轨迹2%容忍保护条件通过{guard}/3个种子。

这些是同一测试轨迹上的算法初始化重复，不是3次独立机器人试验，也不是充分的统计显著性证据。{'历史相对同参数量对照的方向没有在所有区间和种子中保持一致，当前不能把收益稳定归因于历史信息。' if min(better.values())<3 else '三个区间相对同参数量对照的方向一致，但仍需独立轨迹与更充分重复验证。'} {'此外，纯神经网络的完整轨迹误差更低，本轮不能声称历史融合模型全面优越。' if ann<hist else '纯神经网络参照及分层结果见下表，不能由单个总体指标推断所有工况优势。'}

## 1. 五行骨架落地结果

| 骨架 | 实际执行 | 产物 |
|---|---|---|
| 数据 | 使用三个realization的首周期，分别训练、验证、测试；FFT独立处理，训练集确定尺度 | [处理后数据](../preflight/prepared.npz)、[划分来源](split_lineage.json) |
| 变量 | q、v、a、输入力矩；过去0/1/2/4/8/16/32点速度；训练阈值定义低速/换向 | [变量字典](variable_dictionary.csv)、[工况覆盖](coverage.csv) |
| 分析动作 | 5000次共同物理批更新；4种网络×3种子，另1次相同种子独立复跑；150步RK4预测 | [运行记录](training_runs.csv)、[配置](../config.json)、[协议](../实验协议.md) |
| 图表 | 总体、分层、每关节、训练损失、预测曲线、事件覆盖及误差随时域变化 | 下列6组PNG/SVG/PDF图和结果CSV |
| 论证 | 同时检查整体、困难区间、参数量对照及纯ANN；保留不支持假设的结果 | 本报告及[逐种子配对比较](paired_comparisons.csv) |

## 2. 核心结果表

指标为整个0.6秒窗口的位置NRMSE，按训练轨迹各关节位置标准差归一化，六关节等权。越低越好。表中为3个初始化种子的均值±样本标准差；纯物理模型为共同一次拟合。

| 模型 | 完整轨迹 | 低速区间 | 换向区间 |
|---|---:|---:|---:|
{table}

![总体和分层结果](figures/01_overall_and_regimes.png)

同时保留了带单位的RMSE（rad）和150步终点NRMSE，见[汇总表](summary.csv)、[每次运行](run_metrics.csv)、[每关节结果](joint_metrics.csv)。原代码采用的终点NMSE形式另存在各运行的metrics文件中，未与本表混用。

## 3. 是否是历史信息本身的贡献

同参数量对照把当前速度重复为7列，使用与历史模型相同的网络参数数量和训练预算。其有效输入信息仍然只有当前速度，因此它主要检查参数化与优化自由度的影响，不代表增加了7个独立传感量。

| 随机种子 | 区间 | 历史相对瞬时速度误差变化 | 历史相对同参数量对照误差变化 |
|---|---|---:|---:|
{ctable}

负值为改善，正值为变差。相对瞬时速度的改善不能全部归因于历史；必须同时看最后一列。历史模型和同参数量对照共享相同初始当前速度映射，多出的历史输入权重初始为0。

![每关节变化](figures/02_joint_changes.png)

## 4. 训练与预测是两个问题

共同物理阶段的最低验证加速度NMSE为{phys['validation_acc_nmse']:.6f}，出现在第{phys['best_step']}次更新。网络按照验证加速度误差选取参数；轨迹误差通过独立RK4重放得到。加速度损失较大或继续下降，都不能直接替代预测结果。

网络/参照运行终止原因统计：{json.dumps(termination,ensure_ascii=False)}。预算耗尽的模型保留结果，但未宣称训练收敛；共同物理阶段也达到预设预算。源论文的5000轮与本次5000次小批更新不是等价计算量。

![验证损失](figures/03_validation_curves.png)

下面以第1关节5秒后首次参考速度换向附近为展示例，固定使用种子9，未按预测好坏挑选。这是解释性例图，总体结论来自全部固定起点。

![换向例图](figures/04_example_reversal.png)

![预测时域误差](figures/06_horizon_errors.png)

## 5. 数据覆盖与适用范围

三条记录各15000点。统一预热32点，以25点间隔选取有完整150步未来输入的起点，共593个起点；所有模型相同。重叠窗口不是独立试验重复。

| 测试关节 | 低速阈值 rad/s | 低速时间点数 | 换向事件数 |
|---|---:|---:|---:|
{coverage_table}

![工况覆盖](figures/05_coverage.png)

低速和换向可重叠；分层误差按预测目标时刻及关节筛选。低速不等于已确证的预滑动，换向误差也不能被唯一解释成摩擦滞回。数据没有独立真实摩擦标签。

## 6. 验证、失败及恢复记录

- 输入实机文件SHA256：`{audit['raw_sha256']}`，与前期下载核验一致。
- 所有{audit['prediction_rows']}个运行的原始预测均已读取并重新计算指标；有限值检查：{audit['all_finite']}。重算直接消费predictions.npz，不重新训练模型。
- 同种子两次独立运行的预测数组逐位相同：**{audit['same_seed_reproduction']['bitwise_equal']}**。只支持这台机器和当前环境，不能外推为跨平台绝对一致。
- 数学/程序检查覆盖解析正弦的一阶二阶导数、指标手算与缩放/关节置换不变性、空工况、历史索引、匹配初值、RK4解析解、预测历史更新、物理正反动力学一致性、惯性正定性与事件序列化。详见测试脚本及日志。
- 首批{len(audit['recovered_exports'])}个运行的JSON导出因NumPy整数类型失败；原始预测已生成。已从这些预测恢复指标，未重训、未重跑积分，原failure与manifest状态保留。恢复记录：{recovery}。
- 静态安全/种子扫描的未识别项保留在[更改与审查记录](../amendments.md)，不冒称自动扫描全部通过。当前目录非Git仓库，采用文件hash和逐运行源码快照。
- 样本上的惯性矩阵正定性和正反动力学数值一致性是计算核查，不是制造商参数验证或实机物理验证。

## 7. 与原文的差异及结论边界

这是按已选迁移轴执行的受控重跑，**不是原论文表4的严格数值复现**。共同调整包括：使用现有PyTorch重实现训练外壳、训练集拟合归一化、统一明确NRMSE、物理参数有限范围校准、小批更新与预算、稀疏但固定的评价起点；只运行与当前问题有关的模型，而非原文全部8结构。每项对所有对应对照一致施加，并在拟合前写入协议。

原文的预测指标、模型编号、截止频率和选模描述存在第3步记录的不一致。本报告不用原表4数值计算本轮提升率。滤波按源代码索引200实现，频率约3.333 Hz。

位置/速度经过整条轨迹的FFT平滑，且重放使用已记录输入力矩。因此本轮支持的是**离线平滑参照下、给定输入序列的预测比较**。网络过去索引的使用不自动证明整套预处理在线因果。未验证跨机器人、跨负载、温度变化、真实摩擦辨识或MPC闭环改善。

**这轮结果应作为筛选依据：保留可复跑的实现与对照结果，暂不将“加入历史速度”写成已证实的创新贡献。** 下一阶段若继续，应围绕已暴露的机制归因、共同物理底座及独立轨迹证据提出明确的新问题，不能只追加算法直至出现有利结果。

## 文件入口

- [全部运行与原始预测](../runs)
- [核验记录](audit.json)
- [项目说明与复跑方法](../README.md)
- [原论文选文证据](../../../05_evidence/20260928_robot_paper_selection/四篇论文选文评估.md)
- [第3步技术骨架](../../../05_evidence/20260928_robot_paper_selection/第三步_技术骨架表.md)
'''
# Derive rather than hard-code coverage in prose.
sample_run=npz_path=ROOT/'runs/velocity_seed9_a/predictions.npz'
import bootstrap
import numpy as np
with np.load(sample_run) as p: count=len(p['starts'])
text=text.replace('共593个起点',f'共{count}个起点')
(OUT/'第4步_重跑分析报告.md').write_text(text,encoding='utf-8')
print('Report written; origins=',count)
