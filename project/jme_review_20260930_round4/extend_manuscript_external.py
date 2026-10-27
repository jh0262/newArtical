"""Integrate completed unseen-trajectory confirmation into the unified study."""
from pathlib import Path
import json,re,hashlib
R=Path(__file__).resolve().parent;D=R/'delivery';E=R/'external_validation'
done=json.loads((E/'analysis_complete.json').read_text());assert done['status']=='complete'
s=json.loads((E/'summary.json').read_text());assert hashlib.sha256((E/'summary.json').read_bytes()).hexdigest()==done['summary_sha256']
p=D/'论文第四轮修订稿.md';t=p.read_text(encoding='utf-8');assert '### 3.8' not in t,'Rebuild base manuscript first'
def replace(a,b):
 global t
 assert a in t,a[:100];t=t.replace(a,b)
def metric(model,reg='all'):return next(v for v in s['rollout_summary'] if v['model']==model and v['regime']==reg)
def cmp(control,reg='all'):return next(v for v in s['comparisons'] if v['control']==control and v['regime']==reg)
def fmt(v):return 'NA' if v is None else f'{v:.6f}'
def pct(v):return 'NA' if v is None else f'{v:.2f}'
overall=cmp('capacity_control');cv=cmp('constant_velocity');orig=json.loads((D/'result_summary.json').read_text());os=next(v for v in orig['adaptive_summary'] if v['regime']=='all' and v['tolerance']=='tight')
replace('研究对象为六轴KUKA KR300 R2500机器人，末端附加质量150 kg。','研究对象为六轴KUKA KR300 R2500机器人，原建模记录的末端附加质量为150 kg。第2.5节确认记录没有逐条载荷元数据，不据此推定其载荷覆盖。')
replace('通过重新训练对照、冻结权重历史移除和时域敏感性评价检查历史依赖与预测效果。','通过重新训练对照、冻结权重历史移除、误差控制积分及33条未见轨迹确认，检查历史依赖、数值设置与预测效果之间的关系。')
method='''### 2.5 未见轨迹确认与汇总

依据官方原始数据包[19]取得同一机器人的12个采集文件，每文件包含3种参考轨迹及各自重复执行。将已用文件的位置、速度、力矩等10个字段与文献[2]的转换数据逐元素核对，再核对三个轨迹各两个周期的位置/力矩片段，确认数据表示和周期映射。所有文件中同一参考轨迹的两个周期逐元素相同，因此每种只取首周期。排除全部已用文件后，保留11文件中的33条60 s轨迹；各文件均满足采集状态标志、有限值、6通道、250 Hz与片段长度检查。

取前三轴次级编码器位置和后三轴电机侧位置，按原通道定义转换为关节坐标；角度由度转为弧度，输入采用测得电机力矩。每条轨迹沿用第2.1节的谱处理。对时间对齐的参考位置计算相对Frobenius差，分母取候选参考位置去均值后的范数；与已用及此前候选轨迹的最近差值最小为1.118，大于事先设定的10⁻⁶近重复阈值。该检查只排除这种对齐指标下的数值近重复，不证明任意相移、偏置或重标度后的轨迹不等价。

在点态输出计算之前固定数据资格、全部既有权重、物理参数、训练尺度及主要评价规则，不重新训练、调参或选模。持平口径在点态结果后、多步输出前明确记录，不追溯称为全部结果之前的预注册。点态指标使用每条轨迹排除32点预热后的全部时间点。多步预测按整数等距规则取9个起点，从第33个样本至第14850个样本，每次预测150步，形成297个预测窗口；每条记录的历史和预测均不跨片段边界。这是每条60 s记录的预定稀疏时间覆盖，不是原测试记录593起点的全量重复。

D、H和H0各三个初始化均在两组既定容限下计算，另评价恒速与位置保持基准。数值内核、双精度、单线程和容限保持相同；D使用原函数执行，H/H0采用冻结编译图提速，该分配在H/H0多步输出前固定。编译前后核对全部9模型的动态批规模与逐样本阶段时间、18组含拒绝步的短程预测，输出及接受/拒绝步数一致；另对一个困难起点核对完整0.6 s时窗。该有限实现核验不替代各案例的容限检查，具体版本与证据随复现材料保存。

低速阈值和换向定义仍来自原训练数据。每条轨迹先对三个初始化取指标均值，再在轨迹间等权报告均值、中位数和范围；H相对D的降幅为1减去两者跨轨迹均值之比。另报告轨迹及原始文件组三条轨迹均值上的方向计数，NRMSE绝对差不超过10⁻¹²计为持平，不做时间点或初始化伪重复的显著性检验。无有效掩码记NA，积分失败和两容限不一致均单独记录，不删除后形成总体优势。

这33条轨迹未参与本项目网络更新、选模及此前方案设计，但来自同机、同日记录；不代表33台设备或33次独立机器人抽样。原始物理初始参数所用更早数据未在此重新审计，因此也不宣称与所有先验信息完全隔离。本文使用250 Hz原始记录及上述自定划分，与官方10 Hz标准基准的处理和划分不同，不能直接进行数值排名。

'''
replace('## 3 结果',method+'## 3 结果')
replace('结论应在独立轨迹上进一步检验。','第2.5节以固定模型的未见轨迹确认检查不同激励下的结果。')
result='''### 3.8 未见轨迹上的固定模型确认

表9给出33条轨迹的点态加速度误差分布。各轨迹先在相同有效区间、六关节及原训练尺度下计算；网络再取三个初始化均值，表内各统计量对33个轨迹值等权汇总。

表9 未见轨迹的加速度NMSE分布

|模型|均值|中位数|最小值～最大值|
|---|---|---|---|
'''
labels={'training_mean':'训练均值预测','physics_no_friction':'无摩擦物理基底','velocity':'V','capacity_control':'D','history':'H','history_removed':'H0','constant_velocity':'恒速外推','position_hold':'位置保持'}
for m in ['training_mean','physics_no_friction','velocity','capacity_control','history','history_removed']:
 a=next(v for v in s['pointwise_summary'] if v['model']==m);result+=f"|{labels[m]}|{fmt(a['mean'])}|{fmt(a['median'])}|{fmt(a['min'])}～{fmt(a['max'])}|\n"
result+='\n表10给出较严容限积分的位置预测结果，整体中位数同时保留轨迹间分布的信息。表内均值不以窗口数量或低速掩码数量加权。\n\n表10 未见轨迹的位置预测NRMSE\n\n|模型|整体均值|低速均值|换向均值|整体中位数|\n|---|---|---|---|---|\n'
for m in ['capacity_control','history','history_removed','constant_velocity','position_hold']:
 a=[metric(m,g) for g in ['all','low_speed','reversal']];result+=f"|{labels[m]}|{fmt(a[0]['mean'])}|{fmt(a[1]['mean'])}|{fmt(a[2]['mean'])}|{fmt(a[0]['median'])}|\n"
result+='\n有效轨迹数（整体/低速/换向）：'+ '；'.join(labels[m]+'为'+'/'.join(str(metric(m,g)['n']) for g in ['all','low_speed','reversal']) for m in ['capacity_control','history','history_removed','constant_velocity','position_hold'])+'。'
if s['failures']:result+='存在积分失败，表内可得值仅是已完成范围的描述，不能据此声称全体33条轨迹的总体优势。'
result+=f"两容限一致性按轨迹、模型和初始化逐一检查，共{s['tolerance_cases']}项，{s['tolerance_passes']}项通过。"
result+='各模型通过数为'+ '、'.join(labels[x['model']]+f" {x['passed']}/{x['cases']}" for x in s['checks_by_model'])+'。'
if s['tolerance_passes']!=297:result+='未通过项限制相应指标的数值确定性；较严容限不自动等同精确解。'
result+=f"记录到{len(s['failures'])}个轨迹—模型—初始化—容限组合积分失败。按轨迹隔离重试与批量执行的模式另行记录，批规模变化可能带来浮点路径差异。\n\n"
for g,label in [('all','整体'),('low_speed','低速'),('reversal','换向')]:
 c=cmp('capacity_control',g);dire=c['trajectory_direction'];fg=c['file_direction']
 result+=f"{label}范围中，H相对D的均值降幅为{pct(c['reduction_percent'])}%，共同有效轨迹{c['common_records']}条；H较低/持平/较高的轨迹数为{dire['lower']}/{dire['equal']}/{dire['higher']}，{c['complete_file_groups']}个完整文件组上的对应数量为{fg['lower']}/{fg['equal']}/{fg['higher']}。"
result+='这些计数反映本批同日同机记录的描述性一致程度，不能解释为独立抽样下的显著性。\n\n'
result+='![图8 未见轨迹的整体位置NRMSE配对分布。每点代表一条轨迹的三初始化均值；横轴分别为D和恒速外推，纵轴为H，虚线为相等线。点的位置体现轨迹间差异，不表示独立物理重复。](figures/fig8_confirmation.png)\n\n'
result+=f"H与恒速外推在整体范围的共同有效轨迹为{cv['common_records']}条，H较低/持平/较高的数量为{cv['trajectory_direction']['lower']}/{cv['trajectory_direction']['equal']}/{cv['trajectory_direction']['higher']}。结合点态加速度基准可见，同一模型的网络对照排序与朴素基准比较应分开判断；增加确认轨迹并不能消除固定物理基底、训练目标和离线微分参照的限制。\n\n"
replace('## 4 讨论',result+'## 4 讨论')
a,b=t.split('### 4.4 外部有效性和后续证据',1);old,tail=b.split('## 5 结论',1)
t=a+'''### 4.4 确认范围与工程适用性

33条未见轨迹将证据范围由单一测试激励扩展到同一机器人、同一采集日期的多条记录，固定模型确认避免了利用这些结果再选择超参数。单条轨迹上的改善幅度不能直接当作这一分布的平均效果；逐轨迹和文件组的配对结果更能反映结论对激励条件的依赖。轨迹数、重叠窗口和初始化数各自代表不同层次，不能相互替代。

这些数据没有逐条载荷或温度元数据，因此尚未建立跨载荷、跨温度或跨机器人验证。整段FFT的非因果处理和周期延拓影响导数及近零区间；给定未来记录力矩的离线预测也不能直接推广到未知输入或闭环控制。确认采用每条9个预定窗口，不能替代全时间范围的误差覆盖证明。

进一步区分历史信息与未观测摩擦状态，需要具有相同当前速度、不同运动历史的受控工况，以及与动态摩擦或循环状态模型的同条件比较。理论中的等价优化对照为这类设计提供了明确条件，但本次冻结候选的确认并未重新匹配其训练轨迹。当前贡献是可复核的对照与数值敏感性分析，尚不足以提出普遍优越的补偿算法或闭环稳定性结论。

## 5 结论'''+tail
a,b=t.split('## 5 结论',1);old,tail=b.split('## 数据与代码可用性',1)
t=a+f'''## 5 结论

重复当前速度的补偿网络可精确折叠为单输入网络，新增参数不扩大其函数类，却改变输入层的正则化和优化几何。对列对称初始化的特例，匹配Adam参数块学习率、耦合L2与加权梯度裁剪后，可建立输出函数序列等价；200步成对核验与递推关系一致。该条件命题不能替代原候选的优化混杂分析。

原测试轨迹上，H相对D的整体位置NRMSE降幅由4 ms积分下的10.48%变为较严容限误差控制积分下的{os['reduction_percent']:.2f}%，但历史模型仅1/3个初始化通过原测试的两容限一致性检查。33条未见轨迹上的对应降幅为{pct(overall['reduction_percent'])}%，H较低/持平/较高的轨迹数为{overall['trajectory_direction']['lower']}/{overall['trajectory_direction']['equal']}/{overall['trajectory_direction']['higher']}。这说明改善幅度须结合数值设置及激励分布报告；{s['tolerance_passes']}/297项确认范围内的两容限检查通过，未通过项和失败记录保留，不以较严容限名义作严格全局收敛声明。

冻结权重的历史移除与点态检查支持模型依赖延迟差分，但未分离所有优化和反馈效应。网络相对对照的改善、对朴素运动学基准的优势及真实物理机理辨识属于不同判断。结论限于同机同日的离线平滑记录及固定物理基底，不涵盖跨载荷或机器人泛化，也不构成闭环控制稳定性证明。

## 数据与代码可用性'''+tail
replace('原始记录及物理模型来自文献[2]作者公开代码仓库roblue，','原建模记录及物理模型来自文献[2]作者公开代码仓库roblue，')
replace('本研究保存数据哈希、实验配置、候选训练记录、选模依据、权重和逐窗口预测，','33条确认轨迹来自文献[19]对应的官方原始数据归档（DOI：10.26204/data/5）；保存发布者MD5、下载SHA256、原始文件与周期映射。原数据与来源代码的许可分别保留，不把作者代码GPLv3自动套用于全部原始数据。本研究保存数据哈希、实验配置、候选训练记录、选模依据、权重和逐窗口预测，')
zh=f'为区分速度历史补偿中的信息作用与优化、积分效应，比较重载机器人的瞬时速度、重复当前速度和历史输入网络。推导函数折叠及条件Adam路径等价关系，结合冻结权重的历史移除、运动学基准和误差控制积分，评价128 ms历史下的0.6 s预测。原测试轨迹中，历史模型相对重复输入对照的整体位置归一化均方根误差降幅由4 ms积分下的10.48%变为较严容限下的{os["reduction_percent"]:.2f}%。历史模型的三个初始化中仅一个通过原测试两容限检查。在未参与模型选择的33条同机同日轨迹上，该降幅为{pct(overall["reduction_percent"])}%，历史模型误差较低的轨迹为{overall["trajectory_direction"]["lower"]}条，{s["tolerance_passes"]}/297项两容限检查通过。点态加速度误差及运动学基准比较表明，相对网络对照的改善不能替代绝对预测能力检验。研究给出条件性的历史依赖证据，不支持摩擦机理辨识或跨设备、跨载荷优势。'
en=f'This study examines how optimization and numerical integration affect the assessment of velocity-history dynamics augmentation for a heavy-duty robot. Networks using instantaneous velocity, duplicated instantaneous velocity, and velocity history are compared. An exact folding relation and sufficient conditions for equivalent Adam updates are derived. Fixed-weight history removal, kinematic baselines, and error-controlled integration are used for 0.6 s predictions with a 128 ms history. On the original test trajectory, the reduction in overall position normalized root mean square error (NRMSE) of the history model relative to the duplicated-input control changes from 10.48% at a 4 ms integration step to {os["reduction_percent"]:.2f}% at the tighter controlled tolerance. Only one of its three initializations passes the original-test agreement criteria between tolerances. On 33 trajectories from the same robot and acquisition date that were not used for model selection, the corresponding reduction is {pct(overall["reduction_percent"])}%; the history model has lower errors on {overall["trajectory_direction"]["lower"]} trajectories, and {s["tolerance_passes"]} of 297 agreement checks between tolerances pass. Pointwise acceleration errors and kinematic baselines show why improvement relative to a network control cannot replace an assessment of absolute prediction accuracy. The results support conditional dependence on delayed velocity differences. They do not establish friction identification or advantages across robots or payloads.'
t=re.sub(r'(## 摘要\n\n).*?(\n\n关键词：)',lambda m:m[1]+zh+m[2],t,flags=re.S);t=re.sub(r'(## Abstract\n\n).*?(\n\nKeywords:)',lambda m:m[1]+en+m[2],t,flags=re.S)
assert not any(x in t for x in ['补充实验','追加实验','本轮实验','尚需取得对应原始数据','本研究仅覆盖一种60 s测试激励'])
# Add the two directly relevant primary numerical-learning studies in first-citation order.
t=re.sub(r'\[(18|19|20|21)\]',lambda m:'['+str(int(m[1])+2)+']',t)
intro='神经微分方程中的积分误差已有专门研究。Zhu等[18]分析了通过数值流映射训练时的离散误差与学习误差关系，Westny等[19]讨论了积分稳定域与模型初始化、预测表现之间的联系。因此，数值求解会影响学习模型这一事实不是本文的新颖性主张。本文关注其在有限历史机器人补偿比较中的具体影响，并与重参数化对照和冻结历史干预同时核查。\n\n'
replace('本文由此考察一个限定问题：',intro+'本文由此考察一个限定问题：')
replace('本文按验证加速度损失选模，是为了保持可追溯的比较规则。','本文按验证加速度损失选模，是为了保持可追溯的比较规则。文献[18]分析的是经数值流映射训练的神经微分方程；本文采用点态加速度回归，不能直接套用其误差界。文献[19]提供稳定域分析背景，也不替代本文带离散历史缓冲的完整系统稳定性证明。')
refs='[18] ZHU A, JIN P, ZHU B, et al. On numerical integration in neural ordinary differential equations[C]//Proceedings of the 39th International Conference on Machine Learning. PMLR, 2022, 162: 27527–27547. https://proceedings.mlr.press/v162/zhu22f.html.\n\n[19] WESTNY T, MOHAMMADI A, JUNG D, et al. Stability-informed initialization of neural ordinary differential equations[C]//Proceedings of the 41st International Conference on Machine Learning. PMLR, 2024, 235: 52903–52914. https://proceedings.mlr.press/v235/westny24a.html.\n\n'
replace('[20] KINGMA D P, BA J.',refs+'[20] KINGMA D P, BA J.')
p.write_text(t,encoding='utf-8');orig['external_summary']=s;orig['manuscript_sha256']=hashlib.sha256(t.encode()).hexdigest();(D/'result_summary.json').write_text(json.dumps(orig,ensure_ascii=False,indent=2),encoding='utf-8')
print('Integrated 33-trajectory confirmation; 11 equations, 10 tables, 8 figures, 23 references')
