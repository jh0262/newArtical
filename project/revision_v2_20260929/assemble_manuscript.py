"""Fill manuscript numerical passages directly from retained result tables."""
from pathlib import Path
import json,csv,re
ROOT=Path(__file__).resolve().parent
def rows(name):return list(csv.DictReader((ROOT/'results'/name).open(encoding='utf-8-sig',newline='')))
summary=rows('summary.csv');metrics=rows('metrics.csv');selected=json.loads((ROOT/'results/selected.json').read_text());conv=rows('integration_convergence.csv')
def mean(m,g):return float(next(r['mean'] for r in summary if r['model']==m and r['regime']==g))
def sd(m,g):return float(next(r['sd'] for r in summary if r['model']==m and r['regime']==g))
def val(m,s,g):return float(next(r['nrmse'] for r in metrics if r['model']==m and int(r['seed'])==s and r['regime']==g))
def change(a,b,g):return 100*(mean(a,g)/mean(b,g)-1)
def positive_count(a,b,g):return sum(val(a,s,g)<val(b,s,g) for s in [9,19,29])
def cv(model,step):return float(next(r['error_nrmse'] for r in conv if r['model']==model and int(r['substeps'])==step))
def pc(step):return 100*(1-cv('history',step)/cv('capacity_control',step))
names={'velocity':'V','capacity_control':'D','history':'H','history_removed':'H0'}
replacements={}
replacements['FOLD']='3.11×10⁻¹⁵'
replacements['PC_RANGE']='99.899%–99.928%'
replacements['ABSTRACT_RESULTS']=(f"在4 ms积分协议下，历史模型完整轨迹和低速位置归一化均方根误差分别为{mean('history','all'):.6f}和{mean('history','low_speed'):.6f}，相对重参数化对照下降{-change('history','capacity_control','all'):.2f}%和{-change('history','capacity_control','low_speed'):.2f}%；同一历史网络移除延迟差分后误差回升。但固定50个起点的局部步长细化，使完整轨迹相对降幅由{pc(1):.2f}%变为{pc(8):.2f}%，显示收益幅度受数值积分影响")
replacements['ENGLISH_RESULTS']=(f"Under the 4 ms integration protocol, history augmentation yields mean position NRMSEs of {mean('history','all'):.6f} overall and {mean('history','low_speed'):.6f} at low speeds, reductions of {-change('history','capacity_control','all'):.2f}% and {-change('history','capacity_control','low_speed'):.2f}% relative to the duplicated-input control. Removing delayed differences from the same trained networks increases these errors. However, step refinement at 50 fixed origins changes the overall relative reduction from {pc(1):.2f}% to {pc(8):.2f}%, indicating numerical sensitivity")
replacements['GEOMETRY_RESULTS']='128 ms历史矩阵的第一主成分解释比为99.899%–99.928%，条件数约2.86×10⁹至5.80×10¹⁰。由训练集当前速度及截距作线性投影，过去输入剩余能量占比在训练、验证和测试记录上分别为0.143%–0.202%、0.136%–0.285%和0.149%–0.245%（图1）。这表明短历史列具有强相关性；但非零残差仍保留了运动趋势差异，不能据此断言不存在可用的历史信息。该条件数属于输入设计矩阵，不是机器人惯性参数辨识矩阵。'
candidates=rows('training_candidates.csv')
replacements['OPTIMIZATION_RESULTS']=(f"27个候选共执行{sum(int(r['updates']) for r in candidates)}次更新，其中{sum(r['termination']=='budget_exhausted' for r in candidates)}个达到预算上限。9个最终模型均选择10⁻³学习率，最佳检查点位于4500至8000步（表2）。选中候选均满足既定早停条件，其中V的一次运行在10000步时恰好满足早停；这不是训练收敛证明。全部选中学习率位于候选集合上端，说明固定10⁻⁴设置不足以代表本任务的最佳可得性能，也说明当前网格尚未包围学习率最优区间。'")
replacements['OPTIMIZATION_RESULTS']=replacements['OPTIMIZATION_RESULTS'].rstrip("'")
t='|模型|初始化|学习率|最佳步|验证加速度NMSE|实际更新数|\n|---|---|---|---|---|---|\n'
for r in selected:t+=f"|{names[r['model']]}|{r['seed']}|{r['learning_rate']:.0e}|{r['best_step']}|{r['best_validation_acc_nmse']:.4f}|{r['updates']}|\n"
replacements['SELECTION_TABLE']=t.strip()
t='|模型|完整轨迹NRMSE|低速NRMSE|换向NRMSE|\n|---|---|---|---|\n'
for m in names:
 t+='|'+names[m]+'|'+'|'.join(f'{mean(m,g):.6f} ± {sd(m,g):.6f}' for g in ['all','low_speed','reversal'])+'|\n'
replacements['SUMMARY_TABLE']=t.strip()
replacements['COMPARISON_RESULTS']=(f"在4 ms积分步长下，H相对D在完整轨迹、低速和换向上的均值变化分别为{change('history','capacity_control','all'):.2f}%、{change('history','capacity_control','low_speed'):.2f}%和{change('history','capacity_control','reversal'):.2f}%。完整轨迹和低速均为三个初始化方向一致，换向仅{positive_count('history','capacity_control','reversal')}/3次较低；其中初始化19的H换向误差略高于D。D与V的完整轨迹均值分别为{mean('capacity_control','all'):.6f}和{mean('velocity','all'):.6f}，相差{100*(mean('capacity_control','all')/mean('velocity','all')-1):.2f}%，小于固定学习率设置下的差距。表3的“±”为三个初始化的样本标准差，不代表独立物理轨迹的置信区间。\n\n纯物理和纯神经网络背景参照的完整轨迹NRMSE分别为0.070605和0.043877。两类参照未采用相同的候选搜索设置，故这些数值仅用于描述背景性能；本文主表不能支持H在全部模型类别中最优的结论。'")
replacements['COMPARISON_RESULTS']=replacements['COMPARISON_RESULTS'].rstrip("'")
replacements['ABLATION_RESULTS']=(f"冻结H权重并将正延迟输入全部替换为当前速度后，H0的完整轨迹和低速均值分别为{mean('history_removed','all'):.6f}和{mean('history_removed','low_speed'):.6f}。H相对H0在三个工况的均值降幅分别为{-change('history','history_removed','all'):.2f}%、{-change('history','history_removed','low_speed'):.2f}%和{-change('history','history_removed','reversal'):.2f}%，逐初始化方向均为H较低（图3）。H0完整轨迹均值与重新训练D非常接近，但二者权重来源不同，不能据接近的汇总值宣布其函数或每个工况完全等价。这些消融结果仍是在4 ms积分下观察到的，数值敏感性见4.4节。")
point=rows('pointwise_dependence.csv');rr=[r for r in point if r['stage']=='supplementary' and r['split']=='test'];hm=sum(float(r['history_acc_nmse']) for r in rr)/3;zm=sum(float(r['removed_acc_nmse']) for r in rr)/3
replacements['POINTWISE_RESULTS']=(f"不经过滚动积分，在测试参照状态上直接比较加速度输出，候选搜索选出的H模型加速度NMSE均值为{hm:.4f}，移除历史后为{zm:.4f}；三个初始化均为保留历史较低。两种输入产生的加速度差异RMSE为0.2665–0.2753 rad/s²。固定学习率设置下H模型的对应差异为0.0091–0.0380 rad/s²。点态结果不受后续积分步长影响，支持候选搜索选出的网络实际利用了延迟差分；它仍不能区分这些差分究竟代理了加速度趋势、物理参数失配还是摩擦隐状态。")
replacements['HORIZON_RESULTS']='采用相同起点，H相对D在0.1、0.3和0.6 s区间内的平均位置NRMSE分别下降15.04%、13.20%和10.48%（图4）。相对降幅随预测时长变化，表明单一时窗不足以描述模型行为。这里报告的是各区间内所有步的误差，不是仅在末端时刻取值的指标；也没有将相邻时窗视为独立试验。'
replacements['SENSITIVITY_RESULTS']='低速阈值取训练速度95分位数的2.5%、5%和10%时，H相对D的均值降幅分别为17.31%、15.63%和14.68%（图5），在这三个评价设定下方向一致。该检查限定于4 ms积分步长的预测，说明低速结论并非只在一个掩码比例上出现，但不能据此把上述降幅当作步长无关或跨工况的性能参数。'
t='|积分步长/ms|D位置NRMSE|H位置NRMSE|H相对D变化/%|\n|---|---|---|---|\n'
for step in [1,2,4,8]:t+=f'|{4/step:g}|{cv("capacity_control",step):.6f}|{cv("history",step):.6f}|{-pc(step):.2f}|\n'
replacements['REFINEMENT_TABLE']=t.strip()
replacements['REFINEMENT_RESULTS']=(f"表4只使用初始化9、每12个预测起点取1个得到的固定50起点，不能与表3的593起点均值直接混用。独立子步实现在4 ms基准网格上复核，与既有预测的最大状态差异小于1.4×10⁻¹²。随后D在步长由4 ms缩至0.5 ms时，误差从{cv('capacity_control',1):.6f}降至{cv('capacity_control',8):.6f}；H从{cv('history',1):.6f}变为{cv('history',8):.6f}。H相对D的降幅由{pc(1):.2f}%缩至{pc(8):.2f}%，方向在这一子集仍保持，但4 ms积分步长会放大量化差距。\n\n进一步看相邻网格的预测差异，而不仅是对参照的总误差：1 ms与0.5 ms之间，D和H的预测差异NRMSE分别为0.002987和0.000199。D仍表现出可见的状态轨迹差异。因此，这一检查揭示了数值敏感性，没有完成全部模型、初始化及起点上的积分收敛验证，不能将表3的百分比作为已验证的步长无关增益。其来源可能涉及学习补偿的局部斜率与动力学反馈，但本文没有计算雅可比谱，不能直接将其定性为已证明的刚性机制。")
replacements['DISCUSSION_CORE']='采用候选学习率搜索设置时，H在完整轨迹和低速区间的误差均低于D，冻结模型的历史移除及点态加速度比较也支持网络利用了真实延迟差分。固定学习率设置下H与D的误差则较为接近，表明历史收益的判断依赖训练设置。两种设置同时改变了学习率选择范围与最大更新预算，尚不能分离两者各自的贡献。不过，局部步长细化同时降低了H/D差距，说明“观察到改善”与“准确确定改善幅度”是不同证据层级。当前较稳妥的结论是，这一训练和数据条件下存在有用的历史依赖迹象；其多步增益大小仍受数值积分影响。'
replacements['CONCLUSION_RESULTS']='在候选学习率搜索与4 ms积分设置下，H相对D的完整轨迹和低速NRMSE均值分别降低10.48%和15.63%，三个初始化方向一致；冻结权重移除历史以及不经过积分的点态比较支持网络确实使用了延迟差分。但固定50起点的步长细化将完整轨迹相对降幅由13.14%缩至6.74%，且仍未完成全量积分收敛核验。因此，现有证据支持条件性历史作用，其误差降幅尚不能视为与积分步长无关的性能保证。'
refs=json.loads((ROOT/'literature/references.json').read_text(encoding='utf8'))
replacements['REFERENCES']='\n\n'.join(f"[{r['id']}] {r['bibliography']}" for r in refs)
text=(ROOT/'manuscript_template.md').read_text(encoding='utf8')
for key,value in replacements.items():text=text.replace('@'+key+'@',value)
assert not re.search(r'@[A-Z_]+@',text)
(ROOT/'论文修订稿.md').write_text(text,encoding='utf8')
(ROOT/'numerical_passages.json').write_text(json.dumps(replacements,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(dict(characters=len(text),references=len(refs),placeholders_remaining=0),ensure_ascii=False))
