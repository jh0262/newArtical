"""Read completed real CSVs; derive every result number used by v4."""
from pathlib import Path
import csv,json,math,statistics,hashlib
ROOT=Path(__file__).resolve().parents[1];R=ROOT/'results'
def read(name):
    with (R/name).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
S=read('summary.csv');T=read('comparisons.csv');F=read('family_totals.csv');U=read('runs.csv')
audit=json.loads((ROOT/'qa/run_audit/audit_summary.json').read_text('utf-8'))
assert audit['passed'] and len(U)==5640 and len(S)==188 and len(T)==136
assert sum(int(float(r['FE'])) for r in U)==194577300
lookup={(r['problem_id'],r['variant_id']):r for r in S}
tests={(r['family_id'],r['problem_id']):r for r in T if r['family_id']!='jitter_pressure_vessel'}
families={r['family_id']:r for r in F}
ids=[f'F{i:02}' for i in range(1,24)]+['WB','CB','PV']
def full(pid):return 'G2P1J1' if pid=='PV' else 'G2P1J0'
def n(r,k):return float(r[k])
def fmt(v,d=6):
    v=float(v)
    if not math.isfinite(v):return 'NA'
    if v==0:return '0'
    return f'{v:.{d}g}'
def totals(f):
    r=families[f];return tuple(int(float(r[k])) for k in ['a_better','not_significant','b_better'])
def decisions(f,kind):return '、'.join(p for p in ids if (f,p) in tests and tests[f,p]['decision']==kind) or '无'
def detail(f,name):
    w,t,l=totals(f)
    return f'{name}在Holm校正后为{w}项有利、{t}项未检出差异、{l}项不利；有利题为{decisions(f,"a_better")}，不利题为{decisions(f,"b_better")}。'
pc=totals('full_vs_parent');cc=totals('full_vs_classic')
familynames={
 'full_vs_parent':'完整PADE / ADE-Parent',
 'full_vs_classic':'完整PADE / 经典DE',
 'spectral_scaling':'谱尺度 G2P1 / G1P1',
 'axis_with_pulse':'主轴交叉 G1P1 / G0P1',
 'pulse_with_geometry':'双锁脉冲 G2P1 / G2P0',
 'jitter_pressure_vessel':'PV普通trial抖动 J1 / J0'}
familyrows=[['比较家族','题/对数','显著有利','未显著','显著不利']]
for f,label in familynames.items():
    w,t,l=totals(f);familyrows.append([label,str(int(float(families[f]['planned_tests']))),w,t,l])
terminal=[['问题','PADE Mean','PADE Std','Parent Mean','Classic Mean','p Holm¹','判决¹']]
symbol={'a_better':'+','b_better':'−','not_significant':'='}
for pid in ids:
    a=lookup[pid,full(pid)];b=lookup[pid,'G0P0J0'];c=lookup[pid,'CLASSIC_DE'];t=tests['full_vs_parent',pid]
    terminal.append([pid,fmt(a['mean_f']),fmt(a['std_f']),fmt(b['mean_f']),fmt(c['mean_f']),fmt(t['p_holm'],3),symbol[t['decision']]])
ablation=[['配置','F03 Mean','F05 Mean','F09 Mean','WB Mean','PV J0 Mean','PV J1 Mean']]
for g in range(3):
    for p in range(2):
        base=f'G{g}P{p}';v=base+'J0'
        ablation.append([base,*[fmt(lookup[q,v]['mean_f']) for q in ['F03','F05','F09','WB']],fmt(lookup['PV',v]['mean_f']),fmt(lookup['PV',base+'J1']['mean_f'])])
eng=[['问题','算法','Best','Mean','Std','可行/30','秒/次']]
for pid in ['WB','CB','PV']:
    for v,label in [(full(pid),'PADE'),('G0P0J0','Parent'),('CLASSIC_DE','Classic')]:
        r=lookup[pid,v];eng.append([pid,label,fmt(r['best_f'],9),fmt(r['mean_f'],9),fmt(r['std_f'],4),int(float(r['n_feasible'])),fmt(r['mean_seconds'],4)])
bestjson=json.loads((R/'engineering_best.json').read_text('utf-8'))
# JSON has explicit metadata plus designs; retain its decimal-roundtrip source.
if isinstance(bestjson,list):bestentries=bestjson
else:
    bestentries=next(v for k,v in bestjson.items() if isinstance(v,list) and v and isinstance(v[0],dict) and 'problem_id' in v[0])
bestrows=[['问题','最佳设计向量 按显示精度','目标 f','CV']]
for pid in ['WB','CB','PV']:
    e=next(e for e in bestentries if e['problem_id']==pid and e['role']=='full')
    x=e.get('x',e.get('design_vector',[]))
    if not x:
        # Actual field name is recorded in the export, never infer numbers.
        x=next(v for k,v in e.items() if k in ['best_x','design_x','x_values'])
    bestrows.append([pid,'('+', '.join(fmt(v,10) for v in x)+')',fmt(e['best_f'],12),fmt(e['best_cv'])])
fu=[r for r in U if r['variant_id']==full(r['problem_id'])]
assert len(fu)==780
def total_event(k):return sum(float(r['event_'+k]) for r in fu)
pulse_active=sum(float(r['event_pulse_triggers'])>0 for r in fu)
rot=total_event('rot_trials');ps=total_event('pulse_success');pbest=total_event('pulse_best');pfe=total_event('pulse_FE');ptrig=total_event('pulse_triggers')
jit=total_event('jitter_trials');jeff=total_event('jitter_effective');js=total_event('jitter_success')
full_trial=sum(float(r['event_trial_FE']) for r in fu)
full_FE=sum(float(r['FE']) for r in fu)
pvfu=[r for r in fu if r['problem_id']=='PV']
pv_trial=sum(float(r['event_trial_FE']) for r in pvfu)
pv_j_candidates=sum(float(r['event_jitter_candidates']) for r in pvfu)
pv_rot=sum(float(r['event_rot_trials']) for r in pvfu)
pv_pulse=sum(float(r['event_pulse_FE']) for r in pvfu)
pv_paccept=sum(float(r['event_pulse_success']) for r in pvfu)
ratio=statistics.median(n(lookup[p,full(p)],'mean_seconds')/n(lookup[p,'G0P0J0'],'mean_seconds') for p in ids)
allfeasible=sum(int(float(r['n_feasible'])) for r in S)
blocks=[]
def heading(s):blocks.append(dict(type='heading',text=s))
def para(s):blocks.append(dict(type='paragraph',text=s))
def table(cap,rows,widths=None,note=''):
    b=dict(type='table',caption=cap,rows=rows,note=note)
    if widths:b['widths']=widths
    blocks.append(b)
def fig(file,caption,note=''):blocks.append(dict(type='figure',file='figures/'+file,caption=caption,note=note))
heading('4.1 同父算法与经典DE的整体比较')
para(f'5640次正式运行均达到指定预算，总计194577300 FE；严格可行终值共{allfeasible}/5640。全部188单元各30次运行，未删除异常值或缺失样本。'+detail('full_vs_parent','完整PADE相对ADE-Parent')+detail('full_vs_classic','完整PADE相对经典DE'))
table('表4 预设比较家族的Holm校正结果',familyrows,[3400,1000,1200,1400,1500],'正向表示比较式左侧配置更优。每个26题家族独立校正；PV六对J构成单独家族。未显著不表示算法等效。')
para('表5给出所有问题的终值概况，完整Best、Worst、中位数、可行成本和逐对效应均在补充CSV中。表内均值采用六位有效数字，检验使用保存的完整精度。小标准差或末位显著差异结合实际数值尺度解释。F07为带共同噪声的已观测历史最优，F15为本文拟合数据版本。')
table('表5 26题的共同FE终值统计与同父配对比较',terminal,[550,1450,1300,1450,1450,1450,450],'¹p及判决针对完整PADE/ADE-Parent；+为显著有利，−为显著不利，=为未检出差异。每配置30次，p使用家族内Holm校正。')
fig('01_equal_FE_benchmarks_en.png','图2 六个预设数值问题在共同FE下的历史最优轨迹','曲线为30次中位数，阴影为四分位区间；从真实改进事件按阶梯重建。正值函数的对数显示下限仅用于作图，原始数据和检验值保持不变。负值目标使用线性坐标。')
heading('4.2 核心机制的可分辨增量')
for f,name in [('axis_with_pulse','主轴交叉增量'),('spectral_scaling','谱尺度增量'),('pulse_with_geometry','双锁脉冲增量')]:para(detail(f,name))
para('这些结果不支持将新增机制写成对同父算法的普遍性能提升。F01的差异发生在极小目标误差范围；F03、F04、F05和F10则存在可见的搜索精度或收敛差距，不能将全部不利比较归为浮点末位。譬如F03完整方法均值为'+fmt(lookup['F03',full('F03')]['mean_f'],9)+'，父算法为'+fmt(lookup['F03','G0P0J0']['mean_f'],9)+'。由协方差谱估计分布宽度，并不自动得到最适合目标下降的方向尺度；压缩低方差方向可能同时压缩仍需校正的分量。这是与消融相符的解释，尚需独立开发实验进一步分辨。')
para(r'谱规则的作用可在理想对齐情形下直接说明。设正定矩阵\(C=V\Lambda V^T\)同时是独立同分布样本的协方差，\(\delta=x_{r1}-x_{r2}\)，F固定为正且全维交叉，令\(A=VSV^T\)。则有')
blocks.append(dict(type='equation',formula=r'\operatorname{Cov}(F\delta A)=2F^2V\operatorname{diag}\left(\lambda_j^{1+\gamma}/\lambda_1^\gamma\right)V^T'))
blocks.append(dict(type='equation',formula=r'\kappa\left(\operatorname{Cov}(F\delta A)\right)=\kappa(C)^{1+\gamma}'))
para('因此，该谱缩放进一步抑制低方差方向，可能在这些方向仍需校正时产生负干预。该式中的条件数指协方差的最大最小特征值比。实际PADE使用精英收缩矩阵，并含精英引导、档案、随机掩码和状态门，未必满足共同C假设；上述推导解释缩放倾向，不作为完整提案协方差或特定函数退化因果的精确公式。')
para('F10的完整方法在种子1009和1011终止于约0.931305，其余运行大多已接近零；父算法各次终值均不超过约1.286×10⁻¹¹。F13中约0.0109874的终值在完整方法出现两次、在父算法出现一次。中位数与均值因这些尾部运行反映不同侧面，因此重复求解稳定性需结合逐次分布解释。')
jw,jt,jl=totals('jitter_pressure_vessel')
para(f'PV普通trial网格抖动在六个固定G、P条件下的结果为{jw}对有利、{jt}对未显著、{jl}对不利。P内部的离散跃迁仍属于P，因此该J家族检验普通trial抖动的额外作用，不能把J0解释为整个求解器没有任何离散动作。表6列出预设代表问题及三个工程维度中的同父组合；全部188单元统计一并公开。')
table('表6 六种G×P配置及PV网格抖动的平均终值',ablation,[800,1300,1300,1300,1300,1250,1250],'G0/G1/G2依次为原坐标、主轴方向、主轴方向加谱比例；P为双锁脉冲。除PV J1列外均为J0。代表问题在分析前指定，未按显著性筛选。')
fig('04_mechanism_ablation_en.png','图3 预设方向、尺度、脉冲与网格抖动效应','正效应支持比较式左侧配置；显著性标记使用各预设家族内Holm结果。完整逐对数据包括有利、未显著和不利结果。')
heading('4.3 机制活动与计算代价')
para(f'完整方法780次运行累计使用主轴trial {int(rot)}次，脉冲触发{int(ptrig)}批、评价{int(pfe)}次，其中{int(ps)}次被目标个体接受、{int(pbest)}次改善历史最优；{pulse_active}/780次运行至少触发一次脉冲。普通trial网格抖动提案{int(jit)}次，实际规格变化计数{int(jeff)}，相关候选接受{int(js)}次。后两类计数按实现定义区分维度动作与候选接受，不把动作次数当作独立成功率。')
para(f'不同操作的活动程度差异很大。主轴trial占完整方法普通trial的{100*rot/full_trial:.3f}%；脉冲占完整方法FE的{100*pfe/full_FE:.5f}%。PV普通trial中有网格动作的候选占{100*pv_j_candidates/pv_trial:.3f}%，其接受比例为{100*js/max(1,pv_j_candidates):.4f}%。PV的主轴trial为{int(pv_rot)}次，脉冲评价{int(pv_pulse)}次、接受{int(pv_paccept)}次，说明该问题上几何因子没有形成实际旋转活动。有限干预在本方法中表示动作受状态与范围限制；总体活动率及接受率仍需逐机制测量。')
para(f'在26个问题上，完整方法与父算法平均运行耗时比的中位数为{ratio:.3f}。相同FE控制了搜索评价资源；协方差、谱分解和记录本身仍产生CPU开销。微小解析基准目标调用很廉价，该开销不可忽略；对较昂贵工程评价的影响需要按评价成本另行判断。')
if pulse_active==0:
    para('本预算和冻结阈值下，完整方法的双锁脉冲没有实际触发；对应消融只能说明该门控在这些轨迹上保持关闭，不能据其相同终值宣称恢复机制已经产生收益。')
else:
    para('触发和接受记录说明机制实际参与了部分搜索；脉冲改善历史最优的次数是直接事件记录，最终增量仍以等FE消融家族为准。未触发的运行反映门控保持关闭，触发后的不利终值则反映附加评价与普通搜索之间的资源竞争。')
fig('05_mechanism_activity_en.png','图4 完整方法的主轴、脉冲及PV网格动作记录','四行依次为旋转trial比例、脉冲FE比例、至少触发一次脉冲的运行比例、PV有效坐标变化数/(2×普通trial FE)。活动与终值效应分别报告；每次脉冲评价均从共同预算扣除。')
heading('4.4 机械约束求解的稳定性')
table('表7 三个工程问题的完整方法、同父与经典对照',eng,[550,950,1450,1450,1300,1250,1150],'目标统计采用未舍入终值；可行按CV==0判断。耗时为当前六进程、每进程单线程运行的平均wall time，环境间不直接比较。全部消融配置见engineering_summary.csv。')
for pid in ['WB','CB','PV']:
    a=lookup[pid,full(pid)];b=lookup[pid,'G0P0J0'];t=tests['full_vs_parent',pid]
    para(f'{pid}：完整方法Best={fmt(a["best_f"],12)}，Mean={fmt(a["mean_f"],12)}，Std={fmt(a["std_f"],6)}，可行{int(float(a["n_feasible"]))}/30；父算法Mean={fmt(b["mean_f"],12)}。其同父配对效应为{fmt(t["effect"],4)}，Holm p={fmt(t["p_holm"],4)}，判决{symbol[t["decision"]]}。工程成本的相对大小与统计检验分开解释，接近相同最优精度时的最后几位不作为制造收益。')
fig('02_equal_FE_engineering_en.png','图5 机械问题的可行目标历程与可行率','上排在各FE的可行子集中计算中位数及四分位区间，下排给出全部30次的可行率；可行子集会随FE变化，二者需联合阅读。')
fig('06_engineering_distributions_en.png','图6 工程问题全部配置的可行终值分布与可行率','每行一个问题，左列为严格可行终值，右列为全部30次的可行率。点为真实运行；箱体覆盖四分位区间，中心为中位数，须延伸到1.5倍四分位距内的观测值。Classic指CLASSIC_DE。')
abstract_cn=(f'机械约束优化中，坐标交叉、方向尺度、分布收缩诊断和离散取整可能与搜索状态失配。本文从演化动力学与局部微分几何出发，构建主轴投影与构型熵双锁差分进化算法PADE：在JADE风格自适应DE上引入状态门控的主轴交叉与谱尺度，以熵和最优记录停滞联合触发低方差子空间恢复，并通过相邻网格抖动补充离散规格访问。给出新增机制联合关闭时恢复父算法的同状态条件。对23个数值问题和三个机械设计基准执行30种子配对实验，188个配置共5640次运行，严格计入初始化和脉冲的总评价量为194577300 FE。Holm校正后，完整方法相对同父算法为{pc[0]}项有利、{pc[1]}项未显著、{pc[2]}项不利，相对经典DE为{cc[0]}、{cc[1]}、{cc[2]}项。嵌套消融和实际事件记录进一步区分方向、谱尺度、恢复及网格动作的作用。本轮未确认新增机制相对同父算法的性能增益，结果揭示了基于分布几何施加干预的作用边界。')
abstract_en=(f'Coordinate crossover, directional scaling, population contraction diagnostics and discrete rounding can become misaligned with the state of mechanical constrained optimisation. PADE combines state-gated principal-axis crossover and spectral scaling, entropy-and-stagnation-triggered recovery in a low-variance subspace, and neighbouring-grid jitter on a JADE-style adaptive differential evolution parent. A same-state recovery property is established when all additional operations are disabled. Paired experiments with 30 seeds cover 23 numerical and three mechanical design problems, comprising 188 configurations and 5640 runs. Initialisation and pulse proposals are included in an exact total of 194577300 function evaluations. With within-family Holm correction, full PADE produces {pc[0]} favourable, {pc[1]} nonsignificant and {pc[2]} unfavourable outcomes against its adaptive parent, compared with {cc[0]}, {cc[1]} and {cc[2]} against classical DE. Nested ablations and recorded events separate direction, spectral scale, recovery and grid operations. These experiments do not establish an incremental performance benefit over the adaptive parent and delineate the limits of intervention based on population geometry.')
engineering_prose=[
 '表8的每项设计均从本轮完整方法30次运行中按可行优先规则选取。保存向量与独立公式回代的f、CV一致，厚度网格和边界分别检查；完整精度残差保存在随附文件中。',
 'WB、CB的解析模型与PV的混合规格模型对应不同的误差尺度。数值精度、可行性、跨次稳定性和制造改进分别解释；本文机械结论针对这三个基准的约束求解与规格分支访问。原稿文献报值及原代数运行表作为历史补充资料独立保留，不纳入本轮配对检验。']
conclusion=[
 '本文沿四类算子—状态失配构造有限干预的PADE，明确经验主轴方向、谱尺度、双锁低方差恢复和离散网格动作与基础自适应DE的关系。局部几何语言用于说明坐标与搜索形状，协方差谱提供可计算的统计代理；同状态联合关闭条件保证恢复父算法转移，FE时钟使恢复候选与普通trial在同一评价资源下竞争。',
 f'5640次等FE实验补齐了同父比较与机制归因。完整PADE相对ADE-Parent的校正结果为{pc[0]}有利、{pc[1]}未显著、{pc[2]}不利；相对经典DE为{cc[0]}、{cc[1]}、{cc[2]}。原有经典对照能够体现完整搜索框架的能力，同父结果进一步分离继承机制与新增算子的贡献，不能将两类优势合并归因。',
 '方向、尺度、脉冲及网格的完整消融揭示了不同操作的条件性。'+''.join(f'{familynames[f]}为{totals(f)[0]}/{totals(f)[1]}/{totals(f)[2]}；' for f in ['axis_with_pulse','spectral_scaling','pulse_with_geometry','jitter_pressure_vessel'])+'这些计数按显著有利/未显著/显著不利顺序报告。实际触发、接受及改善历史最优的事件记录与终值效应配合，用于解释介入时机和资源代价。',
 '三个机械基准的完整精度解经独立公式复核，并同时报告可行率与重复运行分布。有限干预是一项结构设计原则，其性能需要与诊断阈值、几何估计和离散分支共同理解。下一步研究可针对目前不利地形建立独立开发问题集，检验更有区分度的状态门及方向尺度规则，再以新的验证种子考察其泛化，避免依据本轮验证结果反复调整后回报同一组最优结果。']
spec=dict(raw_runs=len(U),audit_passed=audit['passed'],abstract_cn=abstract_cn,abstract_en=abstract_en,
 literature_table=[['方法','方向与尺度','恢复诊断','与本文的区别'],
 ['CoBiDE 2014','当前较优子集协方差；固定概率按代切换','未设置双锁恢复','主要用特征向量；本文另测谱比例'],
 ['ACoS 2019','档案累计协方差；逐个体概率反馈','坐标选择按成功/失败更新','已有JADE关闭分支对照；本文增加状态门与谱尺度'],
 ['Choi 2025','演化路径秩一更新；按代切换','以低成本学习方向为目标','本文使用当前精英完整谱并报告代价'],
 ['PCM-DE 2024','细节预览未披露','协方差停滞与方差扰动','本文比较熵—停滞联合门及低谱子空间'],
 ['HCDE 2025','细节预览未披露','逐维熵触发混合扰动/重启','本文采用对数体积与W双锁、有限对象与方向'],
 ['PADE-FE v4','精英收缩；耦合门；成功反馈；谱比例','双锁脉冲、低方差方向及网格动作','同父、等FE及嵌套消融明确各项增量']],
 results_blocks=blocks,engineering_prose=engineering_prose,best_design_table=bestrows,
 conclusion=conclusion,counts={'full_vs_parent':pc,'full_vs_classic':cc},
 activity=dict(rot_trials=rot,pulse_triggers=ptrig,pulse_FE=pfe,pulse_success=ps,pulse_best=pbest,pulse_active_runs=pulse_active,jitter_trials=jit,jitter_effective=jeff,jitter_success=js),
 source_sha256={name:hashlib.sha256((R/name).read_bytes()).hexdigest() for name in ['summary.csv','comparisons.csv','family_totals.csv','runs.csv','engineering_best.json']})
(ROOT/'analysis/paper_results.json').write_text(json.dumps(spec,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'counts':spec['counts'],'activity':spec['activity'],'audit':audit['passed']},ensure_ascii=False))
