"""Rebuild manuscript from completed, frozen numerical outputs; no solver or training."""
from pathlib import Path
import sys,json,csv,re,hashlib
R=Path(__file__).resolve().parent;B=R.parent;OLD=B/'jme_review_20260929';D=R/'delivery';A=R/'adaptive'
sys.path.insert(0,str(B));import bootstrap
import numpy as np

def read(p):
 with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def dump(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
for p in A.glob('case_execution_*.json'):
 v=json.loads(p.read_text());assert v['status']=='complete' and v['input_hashes_unchanged'],p
 assert hashlib.sha256((R/'run_adaptive_case.py').read_bytes()).hexdigest()==v['wrapper_sha256']
 assert v['algorithm_signature']==json.loads((A/'implementation_checks.json').read_text())['algorithm_signature']
 for c in v['cases']:
  prefix=f"{v['model']}_{v['seed']}_{c['tolerance']}"
  assert hashlib.sha256((A/(prefix+'.npz')).read_bytes()).hexdigest()==c['prediction_sha256']
  assert hashlib.sha256((A/(prefix+'_stats.json')).read_bytes()).hexdigest()==c['stats_sha256']
rows=[]
for seed in [9,19,29]:
 done=json.loads((A/f'completion_seed{seed}.json').read_text());assert done['status']=='complete' and done['input_hashes_unchanged']
 hashes=json.loads((A/f'inputs_seed{seed}.json').read_text())
 for p,h in hashes.items():assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==h,p
 rows+=read(A/f'metrics_seed{seed}.csv')
assert len(rows)==54,len(rows)
for r in rows:
 r['seed']=int(r['seed'])
 for k in ['nrmse','rmse_rad','tolerance_prediction_difference_nrmse','max_tolerance_normalized_position_difference']:
  r[k]=float(r[k]) if r[k] else None
models=['capacity_control','history','history_removed'];labels=['D','H','H0'];regs=['all','low_speed','reversal']
summary=[]
for tol in ['loose','tight']:
 for reg in regs:
  vals={m:float(np.mean([r['nrmse'] for r in rows if r['model']==m and r['tolerance']==tol and r['regime']==reg])) for m in models}
  summary.append(dict(tolerance=tol,regime=reg,**vals,reduction_percent=100*(1-vals['history']/vals['capacity_control'])))
st={r['regime']:r for r in summary if r['tolerance']=='tight'}
checks=[]
for m in models:
 rr=[r for r in rows if r['model']==m and r['tolerance']=='tight']
 checks.append(dict(model=m,max_masked_delta=max(r['tolerance_prediction_difference_nrmse'] for r in rr),max_position_delta=max(r['max_tolerance_normalized_position_difference'] for r in rr),
  pass_initializations=sum(all(r['tolerance_prediction_difference_nrmse']<=1e-4 and r['max_tolerance_normalized_position_difference']<=1e-3 for r in rr if r['seed']==seed) for seed in [9,19,29]),
  max_delta_by_regime={g:max(r['tolerance_prediction_difference_nrmse'] for r in rr if r['regime']==g) for g in regs}))
npass=sum(c['pass_initializations'] for c in checks)
dump(A/'combined_metrics.json',rows);dump(A/'summary.json',summary);dump(A/'tolerance_summary.json',checks)

t=(D/'论文第四轮修订稿_理论更新.md').read_text(encoding='utf-8')
def replace(old,new):
 global t
 assert old in t,old[:100]
 t=t.replace(old,new)

replace('网络先输出无量纲值，再用训练数据的力矩尺度逆归一化。','网络先输出无量纲值，再用训练有效区间内参考残差力矩M(a−f₀)的逐关节均值与标准差逆归一化。该尺度来自平滑加速度和固定物理模型，不是独立测得的摩擦力矩。')
replace('网络输入、位置误差和加速度误差的归一化统计量只由训练轨迹计算，标准差采用总体定义和10⁻¹²下限。','速度、位置和加速度的均值与标准差由完整训练轨迹计算；补偿力矩的均值与标准差由排除32点预热后的训练残差力矩计算。所有标准差采用总体定义和10⁻¹²下限。')
replace('训练均值与物理基底为确定性计算，各只有一个结果。','训练均值与物理基底为确定性计算，各只有一个结果。加速度归一化及常值基准使用完整训练轨迹统计量，而评价排除了32点预热，因此训练均值基准在训练有效区间的NMSE不必恰为1。')

# Distinguish the non-input network parameters from physical parameters in Eq. 1.
a,b=t.split('### 1.3 正则化与训练过程的混杂',1);sec,tail=b.split('### 1.4 历史输入的可区分变化',1)
sec=sec.replace('θ','ϑ').replace(r'\theta',r'\vartheta')
sec=sec.replace('其余参数记为ϑ','其余网络参数记为ϑ（区别于式(1)中的物理参数θ）')
sec=sec.replace('单输入网络对w设置学习率Kη、L2系数λ/K，对ϑ维持η和λ。','单输入网络初始w取重复列之和，其ϑ及相应Adam矩状态复制自重复网络；w的一阶和二阶矩初态分别取任意一列的共同矩状态，两网络的迭代步数相同。单输入网络对w设置学习率Kη、L2系数λ/K，对ϑ维持η和λ。')
sec=sec.replace('耦合L2下非对称列还会产生不同的一阶和二阶矩。','耦合L2下非对称列可能产生不同的矩状态。命题2是充分条件，不排除其他特殊参数设置下的等价。')
t=a+'### 1.3 正则化与训练过程的混杂'+sec+'### 1.4 历史输入的可区分变化'+tail

replace('其余周期未参与本次分析；不能把原研究更广的数据规模写成本文样本规模。','训练和验证仅用各自首周期；测试轨迹第二周期用于冻结模型的点态重复性检查。重复周期不作为新增独立工况。')
replace('严文俊和蔡月日[20]','严文俊和蔡月日[21]')
replace('[20] 严文俊, 蔡月日.', '[21] 严文俊, 蔡月日.')
replace('[21] 严文俊, 蔡月日.', '[20] DORMAND J R, PRINCE P J. A family of embedded Runge-Kutta formulae[J]. Journal of Computational and Applied Mathematics, 1980, 6(1): 19–26. DOI: 10.1016/0771-050X(80)90013-3.\n\n[21] 严文俊, 蔡月日.')
method='''

采用Dormand–Prince 5(4)嵌入式公式[20]进行误差控制积分。各预测起点分别选择子步，12维状态中最大的缩放局部误差决定接受或拒绝；尺度为各分量训练标准差乘绝对容限因子，加上相对容限乘该分量子步前后绝对值的较大者。两组相对容限为10⁻⁶和10⁻⁸，绝对容限因子分别为10⁻⁸和10⁻¹⁰。每个4 ms输入区间精确终止，再更新历史缓冲；沿用相同力矩保持和历史插值，不跨越更新边界。步长安全因子为0.9，变化倍数限制为0.2至10，最小步长10⁻¹⁰ s。嵌入式误差估计用于局部控制，不是完整预测的严格误差界。

在运行前规定两容限预测的一致性判据：三个工况的位置差NRMSE均不超过10⁻⁴，且全部起点、输出时刻及关节的最大标准化位置差不超过10⁻³。该操作性阈值用于检查计算结果对容限的敏感性，不是工艺精度指标。解析衰减、振动和时变强迫算例的最大绝对误差小于10⁻¹⁰；对D与H的初始化9，三个固定起点的8 ms预测与独立Radau方法相比，最大标准化状态差小于4.3×10⁻¹²。这些检查核验实现，不替代全量0.6 s预测的一致性评价。
'''
replace('令e_(o,h,j)为起点o、步h、关节j的位置误差',method+'\n令e_(o,h,j)为起点o、步h、关节j的位置误差')
replace('各工况按同一掩码分别计算对参照误差及相邻网格之间的预测差。','各工况按同一掩码分别计算对参照误差及相邻网格之间的预测差。D的三个初始化另计算0.25 ms结果；其余模型的更细固定网格未完成，不纳入完整模型均值比较。误差控制方法则覆盖D、H、H0的三个初始化、全部起点及两组预定容限。')
replace('表4 全部593个起点的积分步长细化（三个初始化均值）','表4 全部593个起点的积分设置比较（三个初始化均值）')
replace('|步长/ms|D整体NRMSE|H整体NRMSE|H0整体NRMSE|H相对D降幅/%|','|积分设置|D整体NRMSE|H整体NRMSE|H0整体NRMSE|H相对D降幅/%|')
table4_header='|积分设置|D整体NRMSE|H整体NRMSE|H0整体NRMSE|H相对D降幅/%|'
before,rest=t.split(table4_header,1);table4_rows,after=rest.split('\n\n',1)
for dt in ['4','2','1','0.5']:
 old='\n|'+dt+'|0.';assert table4_rows.count(old)==1
 table4_rows=table4_rows.replace(old,'\n|RK4，'+dt+' ms|0.')
t=before+table4_header+table4_rows+'\n\n'+after
part=''
for r in summary:
 if r['regime']=='all':
  name='误差控制，较松容限' if r['tolerance']=='loose' else '误差控制，较严容限'
  part+=f"|{name}|{r['capacity_control']:.6f}|{r['history']:.6f}|{r['history_removed']:.6f}|{r['reduction_percent']:.2f}|\n"
replace('|RK4，0.5 ms|0.049140|0.046729|0.048760|4.91|','|RK4，0.5 ms|0.049140|0.046729|0.048760|4.91|\n'+part.rstrip())
replace('全部起点上的积分步长敏感性。每条曲线为三个初始化均值；内部步长变化时历史采样网格仍为4 ms，未据此宣称积分收敛。','全部起点的积分设置敏感性。带符号曲线为四组RK4步长，水平点线为误差控制积分的较严容限结果；D、H和H0以不同符号、线型及灰度区分，均为三个初始化的均值，历史网格固定4 ms。')
fixed=[]
for seed in [9,19,29]:
 rr=read(R/f'fine_grid/metrics_seed{seed}.csv');assert len(rr)==3
 fixed.append(next(r for r in rr if r['regime']=='all'))
new=f'''D的三个初始化在0.25 ms下的整体NRMSE均值为{np.mean([float(r['nrmse']) for r in fixed]):.6f}。相对于0.5 ms，逐初始化的最大标准化位置差分别为'''+ '、'.join(f"{float(r['max_previous_grid_normalized_position_difference']):.6f}" for r in fixed)+'''，均超过10⁻³。由于更细固定网格未形成完整对照，这三项只用于说明D仍对数值设置敏感，不与未计算的H/H0网格组成性能排名。

'''
new+=f"采用较严容限的误差控制积分后，D、H、H0整体NRMSE分别为{st['all']['capacity_control']:.6f}、{st['all']['history']:.6f}、{st['all']['history_removed']:.6f}；H相对D的整体、低速及换向降幅为{st['all']['reduction_percent']:.2f}%、{st['low_speed']['reduction_percent']:.2f}%和{st['reversal']['reduction_percent']:.2f}%。"
new+='两容限之间，'+ '；'.join(f"{label}的最大工况差NRMSE为{c['max_masked_delta']:.3e}、全局最大标准化位置差为{c['max_position_delta']:.3e}，{c['pass_initializations']}/3个初始化满足两项判据" for label,c in zip(labels,checks))+'。'
new+=('这说明在预设检查精度下，各模型结果对本次容限收紧保持一致。该证据限于给定历史重构及力矩保持方式，不证明严格连续历史系统的收敛或稳定。' if npass==9 else '未满足判据的模型仍需更严格的容限或独立方法核验，不能把较严容限结果直接当作精确解，也不能宣称所有模型已数值收敛。')
ratios=[]
for seed in [9,19,29]:
 vv={m:next(r['nrmse'] for r in rows if r['model']==m and r['seed']==seed and r['tolerance']=='tight' and r['regime']=='all') for m in models}
 ratios.append(100*(1-vv['history']/vv['capacity_control']))
new+='按三个初始化分别计算，H相对D的整体降幅为'+ '、'.join(f'{v:.2f}%' for v in ratios)+'，负值表示H误差较高。因此，三初始化均值的变化不能替代逐初始化方向及局部敏感性检查。'
rh=next(r['nrmse'] for r in rows if r['model']=='history' and r['seed']==19 and r['tolerance']=='tight' and r['regime']=='all')
rh0=next(r['nrmse'] for r in rows if r['model']=='history_removed' and r['seed']==19 and r['tolerance']=='tight' and r['regime']=='all')
new+=f"在第二个初始化下，H的整体误差也比H0高{100*(rh/rh0-1):.2f}%，说明4 ms设置下逐初始化一致的历史移除结果不具有积分设置不变性。"
failed=json.loads((A/'failed_origins.json').read_text());assert [v['seed'] for v in failed]==[9,19,29]
new+=f"历史模型三个初始化中，超过最大位置差阈值的起点分别为{len(failed[0]['starts'])}、{len(failed[1]['starts'])}和{len(failed[2]['starts'])}个；两个未通过组合的异常起点部分重合，共涉及{len(set(v for f in failed for v in f['starts']))}个不同预测时刻。整体均值在两容限下接近，并不能排除局部时窗的数值差异。"
new+='\n\n'
replace('### 3.5 绝对误差与朴素基准',new+'### 3.5 绝对误差与朴素基准')
local=json.loads((A/'local_sensitivity_summary.json').read_text())
physical=[max((r for r in local['rows'] if r['seed']==seed),key=lambda r:r['max_normalized_position_difference']) for seed in [9,19]]
old_para='图7按起点索引选择中间窗口，固定初始化9，展示0.5 ms积分下D/H与恒速外推的六关节误差。窗口未经误差排序挑选，既包含H相对D改善的关节，也包含H较差的关节；恒速外推在该窗口的局部表现与全轨迹汇总不必一致。该图用于检查误差形态，不替代表3、表4的完整评价。'
new_para='图7针对两个未通过检查的历史模型，分别选取其两容限最大标准化位置差所在窗口，用于诊断局部敏感性，不将这些窗口作为平均预测性能的代表。两个最大差均出现在第150个预测步和第六关节，实际位置差分别为'+ '和'.join(f"{r['position_difference_rad']:.6f} rad（{r['position_difference_degree']:.3f}°）" for r in physical)+'。这些值是两次数值计算之间的差，不能解释为实机跟踪误差。完整起点指标与该局部诊断共同表明，平均误差接近与全量轨迹满足一致性阈值不是同一结论。'
# The base revision used a middle-window performance illustration. Retain that
# evidence in the guide and make the main figure answer the numerical question.
replace(old_para,new_para)
replace('图7 固定中间起点的六关节预测误差。D、H内部步长为0.5 ms，初始化9；参照为离线平滑位置，纵轴由rad换算为度，非末端定位误差。','图7 历史模型的局部容限敏感性。两行分别为两个未通过检查的初始化中最大差所在窗口；左列是第六关节对离线参照的位置误差，右列是每一时刻六关节标准化位置差的最大值，水平虚线为预定阈值。窗口按诊断规则选择，不用于代表整体性能。')
replace('表3 各模型的位置预测NRMSE','表3 各模型的位置预测NRMSE（网络采用4 ms积分）')
replace('图3 同一历史网络移除延迟差分后的配对比较。','图3 4 ms积分下同一历史网络移除延迟差分后的配对比较。')
replace('图4 预测时长改变时的误差。','图4 4 ms积分下预测时长改变时的误差。')
replace('图5 低速阈值敏感性。','图5 4 ms积分下的低速阈值敏感性。')

repeat=json.loads((R/'repeat_check/verification.json').read_text());assert repeat['status']=='pass';sv=repeat['summary']
rept='''### 3.7 同轨迹重复采集的点态检查

保持物理参数、网络权重与训练归一化固定，在测试轨迹的第二重复周期上重新计算点态加速度指标。首周期重算的V、D、H均值与既有结果相差不超过3.56×10⁻¹⁵。两周期分别进行相同FFT处理，第二周期不用于更新或选模。

表8 同一测试轨迹两次采集的加速度NMSE

|模型|首周期|第二周期|
|---|---|---|
'''
for model,label in [('training_mean','训练均值预测'),('velocity','V'),('capacity_control','D'),('history','H'),('history_removed','H0')]:
 vals=[next(r['mean'] for r in sv if r['period']==p and r['model']==model) for p in [1,2]]
 rept+=f'|{label}|{vals[0]:.6f}|{vals[1]:.6f}|\n'
rept+='''
V、D、H与H0为三个初始化的均值，常值基准为确定性结果。第二周期中H仍低于D及H0，但所有网络均明显高于均值基准。两次平滑位置序列的逐关节相关系数均大于0.999999999，差异RMSE约为4.52×10⁻⁷至4.74×10⁻⁶ rad，反映它们几乎相同的运动轨迹。该检查支持给定轨迹上的点态结果重复性，不增加独立激励或负载覆盖，也不验证多步积分性能。

'''
replace('## 4 讨论',rept+'## 4 讨论')
replace('本研究只有一条60 s测试轨迹和固定150 kg附加质量。','本研究仅覆盖一种60 s测试激励及固定150 kg附加质量。多步预测采用首周期，点态重复性检查使用该轨迹的第二周期。')
replace('这些验证尚未完成，限制了当前结论的适用范围。','同轨迹第二周期不能替代上述独立确认；这些验证尚未完成，限制了当前结论的适用范围。')
replace('结论限于单条离线平滑测试轨迹与固定物理基底','结论限于单一测试激励的离线平滑记录与固定物理基底')
replace('The findings concern one offline-smoothed test trajectory and a fixed physics model','The findings concern offline-smoothed records of one test excitation and a fixed physics model')
replace('点态加速度误差远高于训练均值预测基准，且对全部593个起点细化至0.5 ms后，相对降幅缩至4.91%，且对照模型仍存在明显的网格间预测差。',f'点态加速度误差远高于训练均值预测基准，且对全部593个起点细化至0.5 ms后，相对降幅缩至4.91%。较严容限的误差控制积分下，该降幅为{st["all"]["reduction_percent"]:.2f}%，{npass}/9个模型—初始化组合满足预设的两容限一致性判据。')
replace('Refinement to 0.5 ms over all 593 prediction origins reduces the relative improvement to 4.91%, while appreciable differences between successive grids remain for the control.',f'Refinement to 0.5 ms over all 593 prediction origins reduces the relative improvement to 4.91%. With error-controlled integration at the tighter tolerance, the improvement is {st["all"]["reduction_percent"]:.2f}%; {npass} of nine model–initialization combinations meet the stated agreement criteria between the two tolerances.')
replace('因此，现有证据支持给定离散协议下的条件性历史作用，尚未建立积分收敛后的优势。',f'较严容限积分下，H相对D的整体降幅为{st["all"]["reduction_percent"]:.2f}%，两容限一致性检查有{npass}/9个模型—初始化组合通过。'+('该结果支持给定历史重构下的条件性比较，仍不构成跨工况优势或完整历史系统的收敛证明。' if npass==9 else '未通过的一致性检查仍限制改善幅度的确定，现有证据不足以建立所有模型数值收敛后的优势。'))

# Keep the abstract focused on the question, quantified finding and evidence boundary.
zh=(f'为区分速度历史补偿中的信息作用与优化、积分效应，在公开重载机器人记录上比较瞬时速度、重复当前速度和历史输入网络。推导重复输入的函数折叠与条件Adam路径等价关系，结合冻结权重的历史移除、运动学基准和误差控制积分，评价128 ms历史下的0.6 s预测。4 ms积分时，历史模型较重复输入对照的整体位置归一化均方根误差降低10.48%；误差控制积分的较严容限下，降幅为{st["all"]["reduction_percent"]:.2f}%，{npass}/9个模型—初始化组合满足预设的两容限一致性判据。恒速外推在整体和低速区间优于历史模型，各网络的点态加速度误差均高于训练均值基准。结果支持已训练网络使用了延迟差分，但未完全分离优化和历史反馈效应。结论限于固定物理基底及单一测试激励的离线平滑记录，不支持摩擦机理辨识或跨工况优势。')
en=(f'This study distinguishes the use of delayed velocity information from optimization and integration effects in dynamics augmentation for a heavy-duty robot. Networks receiving instantaneous velocity, duplicated instantaneous velocity, or velocity history are compared using public robot measurements. An exact folding relation and sufficient conditions for equivalent Adam updates are derived. Fixed-weight history removal, kinematic baselines, and error-controlled integration are used to assess 0.6 s predictions with a 128 ms history. At a 4 ms integration step, the history model reduces overall position normalized root mean square error (NRMSE) by 10.48% relative to the duplicated-input control. With error-controlled integration at the tighter tolerance, the reduction is {st["all"]["reduction_percent"]:.2f}%; {npass} of nine model–initialization combinations meet the stated agreement criteria between tolerances. Constant-velocity extrapolation performs better overall and in low-speed regions, while all networks have larger pointwise acceleration errors than a training-mean predictor. The results show that the trained history network uses delayed velocity differences, but do not fully separate optimization and history-feedback effects. The findings are restricted to offline-smoothed records of one test excitation and a fixed physics model. They do not establish friction identification or performance across operating conditions.')
t=re.sub(r'(## 摘要\n\n).*?(\n\n关键词：)',lambda m:m[1]+zh+m[2],t,flags=re.S)
t=re.sub(r'(## Abstract\n\n).*?(\n\nKeywords:)',lambda m:m[1]+en+m[2],t,flags=re.S)
t=t.replace('model–initialization combinations','combinations of model and initialization').replace('optimization and history-feedback effects','the effects of optimization and feedback through delayed inputs')

(D/'论文第四轮修订稿.md').write_text(t,encoding='utf-8')
dump(D/'result_summary.json',dict(adaptive_summary=summary,tolerance_checks=checks,passed_cases=npass,repeat=repeat,manuscript_sha256=hashlib.sha256(t.encode()).hexdigest()))
print(json.dumps(dict(adaptive_summary=summary,tolerance_checks=checks),ensure_ascii=False))
