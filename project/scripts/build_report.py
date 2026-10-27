from pathlib import Path
import csv,json,datetime,hashlib,platform,statistics,zipfile
import numpy as np,scipy
from scipy.io import loadmat
root=Path(__file__).resolve().parents[1]; out=root/'analysis/results'
def load(name): return json.loads((out/name).read_text(encoding='utf-8'))
def table(name): return list(csv.DictReader((out/name).open(encoding='utf-8-sig')))
def link(label,path): return f'[{label}](<{path.as_posix()}>)'
audit=load('numerical_audit.json'); stats=load('statistical_crosscheck.json')
assert audit['status']==stats['status']=='PASS' and audit['runs']==2080
repro=json.loads((root/'provenance/reproduction500.json').read_text(encoding='utf-8')); assert repro['status']=='PASS'
rows=table('verified_runs.csv'); summary=table('summary.csv'); rankings=table('friedman_ranks.csv'); paired=table('g111_pairwise_holm.csv'); effects=table('factorial_across_problems.csv')
lookup={(r['Problem'],r['Algorithm']):r for r in summary}
problems=list(dict.fromkeys(r['Problem'] for r in summary)); pair={r['Comparator']:r for r in paired}
g111=[r for r in rows if r['Algorithm']=='G111']; app=sum(int(r['EarApplied']) for r in g111); fb=sum(int(r['EarFallback']) for r in g111)
changes=[0,0,0]
for r in g111:
    t=loadmat(root/r['RunPath']/'raw.mat',variable_names=['Telemetry'])['Telemetry']
    for k,col in enumerate([11,12,2]): changes[k]+=int(np.ptp(t[:,col])>1e-8)
known_order=[r['Algorithm'] for r in rankings]; ordinal=known_order.index('G111')+1
primary=['MODE_FIXED','G000','G111','NSGAII','SPEA2','MOEAD']
lines=['# 耳切思想与多机制 MODE：MATLAB 实验报告','',f'生成时间：{datetime.datetime.now(datetime.timezone.utc).isoformat()}','',
'## 结论','',
f'已完成全部 **2,080 次正式实验**：13种配置 × 8个双目标问题 × 20个随机种子。每次种群100，初始化后运行500代，严格消耗50,100次优化评价；合计 **104,208,000 次优化评价**。全部原始结果通过独立数值复核。', '',
f'按8个问题的20次运行中位IGD+计算，G111（三机制全开）在13组中列第{ordinal}，在候选G系列中排名最好，但整体排名落后于SPEA2、MOEA/D和NSGA-II。G111相对固定参数MODE和自适应基准G000均为6胜2负；相对NSGA-II、SPEA2均为0胜8负；相对MOEA/D为2胜6负。这些是逐问题中位数的方向统计，不是逐项显著优越性结论。', '',
'当前证据支持“组合机制在部分问题上改善本研究的基础MODE”，尚不支持“优于经典多目标算法”或“已经证实三机制协同”。ZDT4的收敛不足最明显。后续应围绕失效原因修改另一个版本，而不是直接以本轮结果宣称新算法优势。','',
'## 实验配置与公平性','',
'- A：在最后一层非支配解中进行覆盖误差受约束的耳切删减；误差界由同集普通拥挤距离删减自动确定。','- B：从截断前的非支配候选集提取邻距与局部转折信息，选择DE引导父代。','- C：按固定观察窗口下的真实目标改善记录，自适应分配DE/rand/1和DE/current-to-guide/1的调用比例。','- G000至G111为完整2^3组合。F和CR的成功历史适应是这八组共享的支持机制。MODE_FIXED关闭这些适应规则，使用固定F=0.5、CR=0.9。','- 几何打乱对照保留权重分布并打乱其与引导解的对应关系。经典算法使用存档PlatEMO源码，MOEA/D显式采用Tchebycheff选项。','- 每个问题与种子块内，13组的初始决策矩阵完全相同；预算和目标评价一致。参考前沿仅供观察回调与离线指标使用，不进入DE变异、选亲或适应。','- 学习率0.1、概率下限0.1、记忆长度6、采样宽度0.1仍为固定超参数；自适应并不意味着没有参数。','',
'## 主要结果：最终归一化IGD+中位数','',
'数值越小越好。所有算法均保留在完整CSV表中。','',
'| 问题 | '+' | '.join(primary)+' |','|---|'+'---:|'*len(primary)]
for p in problems: lines.append('| '+p+' | '+' | '.join(f"{float(lookup[p,a]['MedianIGDplus']):.6g}" for a in primary)+' |')
lines+=['','## 全部配置的平均排名','','按每个问题的中位IGD+排名，较小更好。','', '| 配置 | 平均秩 |','|---|---:|']
for r in rankings: lines.append(f"| {r['Algorithm']} | {float(r['AverageRank']):.4g} |")
lines+=['','## 消融与机制解释','',
'1. **耳切选择A确实参与了运行。** G100相对G000在6/8个问题上降低中位IGD+。完整G111共触发耳切选择'+f'{app:,}次，回退{fb}次（{100*fb/app:.3f}%）。因此其结果并非由持续回退为普通拥挤距离选择产生。但是覆盖半径约束只约束当前候选集的离散覆盖误差，不保证真实前沿精度或收敛速度。',
'2. **几何选亲B的额外作用仍不稳定。** G111对几何打乱组为6胜2负，跨问题Holm校正p='+f"{float(pair['G111_SHUFFLE']['HolmP']):.6g}"+'。ZDT4上两组差距较大，其他部分问题差距很小；不能据此把全部改善归因于几何信息传递。',
'3. **自适应分配C没有普遍的增益。** G111对G110为5胜3负；跨问题平均主效应的方向在4/8个问题上有利。应把分配概率轨迹与每个区域的实际收益一起分析，不能只依据“参数发生变化”判断适应有效。',
'4. **三机制协同尚未成立。** 原始IGD+尺度上的ABC三阶交互只在3/8个问题方向有利。单独、两两和全开的结果已全部导出。交互效应依赖指标尺度，原始尺度上负值表示有利；这与某个完整组合的最终排名是不同的判断。','',
'| 效应 | 跨问题对比量中位数 | 有利问题数 | Holm校正p |','|---|---:|---:|---:|']
for r in effects: lines.append(f"| {r['Effect']} | {float(r['MedianProblemContrast']):.6g} | {r['FavorableProblems']}/8 | {float(r['HolmP']):.6g} |")
lines+=['','## 自适应实际发生的证据','',f'在160次G111正式运行中，F记忆均值发生变化的运行数为{changes[0]}，CR记忆均值发生变化为{changes[1]}，局部算子概率发生变化为{changes[2]}（判据为跨代极差大于1e-8）。完整轨迹保存在每次运行的adaptation.csv和raw.mat中。','',
'## 统计解释与限制','',
f"Friedman总体检验p={stats['friedman_p']:.8g}，说明所列配置在这8个问题上的排名并非完全一致；它不能单独证明G111更好。跨问题检验以8个问题为样本，20次种子重复用于估计算法随机性，未伪装成160个独立问题。",'',
'一个必须保留的设计限制是：8对非零差值的双侧精确Wilcoxon最小p值为0.0078125。12项Holm比较第一步的最小校正值为0.09375，7项交互检验为0.0546875，均高于0.05。因此，这两组检验在本设计下无法达到0.05。未通过阈值不能解释为算法等价或机制无效；本轮仍能提供逐问题差异、总体排名和失效诊断。未事后切换检验、删除比较项或扩大种子作为独立样本来追求显著性。', '',
'报告中的bootstrap置信区间是描述性的：问题层面20,000次重采样，问题内部种子层面10,000次重采样。它们不是经过多重比较校正的同时置信区间。八个相关基准也不是所有优化问题的随机样本，不能外推普遍优势。完整配对比较包含p值、校正值、差值、置信区间和配对秩二列效应量。','',
'## 主要失效与后续研究方向','',
'- ZDT4：G111中位IGD+约0.3233，而三个经典算法约0.0031至0.0040，显示多峰决策空间上的收敛差距。该结果不能由几何档案保留单独解决。','- DTLZ2、DTLZ4：复杂组合没有改善基础MODE的最终中位IGD+。需要区分解集覆盖收益与变异搜索效率，避免几何选择将已有采样误差固化。','- 当前信用分配使用每代观测前沿的归一化尺度；跨代尺度变化、个体HV潜在收益相互重叠、有限观察窗口下的重复发现，都可能影响分配。这里是基于实现结构的待验证解释，尚非已经确认的原因。','- 若开展下一轮，应提前登记更广的独立问题集合、对照组与统计方案，优先检验多峰搜索能力和信用分配失效。正式旧结果保持不变；没有根据本轮结果反向调参并重报为同一实验。','',
'## 数值验证与可复现性','',
f"- 全部2,080次运行：最终决策独立重算最大误差{audit['max_objective_recompute_error']:.3e}；每一代HV独立重算最大误差{audit['max_all_generation_HV_error']:.3e}；每10代IGD+最大误差{audit['max_checkpoint_IGDplus_error']:.3e}。",'- 初始矩阵160个问题/种子块内完全一致；每次501个种群快照、500代、50,100次评价均核对通过。','- MATLAB核心、集成与统计公式测试共14项通过；另有两次独立500代G111复跑，逐代目标、最终决策和参数轨迹逐位一致。该一致性只对应当前MATLAB和硬件环境。',f"- MATLAB与Python交叉核对Friedman、12项Wilcoxon/Holm和1,120个逐种子消融对比，最大消融计算差异{stats['max_factorial_error']:.3e}。",'- 原始结果约816.7 MB（MAT文件），失败日志未发现异常。全部源代码、配置、每次运行的原始结果与哈希均保留。','- 耳切覆盖不等式按运行轨迹及独立小型性质测试验证；没有声称在Python中独立重演每次删点。','',
'## 图表','']
for name,label in [('convergence_igdplus','500代收敛曲线'),('factorial_igdplus','完整消融指标'),('factorial_interactions','主效应与交互效应'),('pareto_fronts','按中位秩选择的代表性前沿'),('adaptive_parameters','自适应参数轨迹'),('average_ranks','算法平均排名')]:
    lines += [f'### {label}','',f'![{label}]({(out/"figures"/(name+".png")).as_posix()})','',link('可导出的PDF',out/'figures'/(name+'.pdf')),'']
lines+=['## 文件与使用','',link('MATLAB使用与复现说明',root/'RUN_GUIDE_zh.md'),'',link('完整逐次运行指标',out/'verified_runs.csv'),'',link('消融逐问题统计',out/'factorial_effects_by_problem.csv'),'',link('全部配对比较',out/'g111_pairwise_holm.csv'),'',link('数值核验记录',out/'numerical_audit.json'),'',link('统计交叉核验',out/'statistical_crosscheck.json'),'',
'## 证据边界与引用','',
'本轮完成的是解析、连续、无约束双目标算法研究。没有运行有限元或物理实验，不涉及机械结构安全结论，也未完成外部新颖性定论。本轮收益不能直接推广到三目标以上、离散变量或工程约束问题。','',
'经典算法源码来自本地存档的[PlatEMO](https://github.com/BIMK/PlatEMO)，所有版权和研究使用说明均已保留。发表时应引用Tian等关于PlatEMO的2017年论文，并引用NSGA-II、SPEA2、MOEA/D及相应基准原始文献；这些引用信息保留在vendor源码头部。F/CR规则借鉴[成功历史参数适应](https://metahack.org/CEC2013-SHADE.pdf)，多目标信用定义为本研究的候选改写，不称为单目标SHADE原样复现。','']
(root/'RESULTS_zh.md').write_text('\n'.join(lines),encoding='utf-8')
acceptance={'status':'COMPLETE_WITH_RESEARCH_LIMITATIONS','requirements':{'matlab_implementation':True,'three_mechanisms':True,'complete_2_power_3_ablation':1280,'basic_and_classical_comparisons':True,'minimum_500_generations_all_runs':2080,'adaptive_parameters_observed':changes,'all_2080_runs_independently_audited':True,'statistics_crosschecked':True,'report_and_six_png_pdf_figures':True,'independent_500_generation_reproduction':True},'limitations':['candidate has not outperformed classical algorithms','8-problem exact-Wilcoxon Holm resolution cannot reach 0.05 for declared families','external novelty unestablished','analytic biobjective unconstrained benchmarks only'],'environment':{'python':platform.python_version(),'numpy':np.__version__,'scipy':scipy.__version__,'MATLAB':'R2025b'},'artifacts':{'report':'RESULTS_zh.md','guide':'RUN_GUIDE_zh.md','numerical_audit':'analysis/results/numerical_audit.json','statistics':'analysis/results/statistical_crosscheck.json','reproduction':'provenance/reproduction500.json'},'verified_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(root/'ACCEPTANCE.json').write_text(json.dumps(acceptance,ensure_ascii=False,indent=2),encoding='utf-8')
bundle=root/'EarClip_MODE_code_and_report.zip'
with zipfile.ZipFile(bundle,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for folder in ['src','vendor','tests','scripts','provenance','analysis']:
        for p in sorted((root/folder).rglob('*')):
            if p.is_file() and '__pycache__' not in p.parts and p.name!='analysis.mat': z.write(p,p.relative_to(root))
    for p in sorted(root.iterdir()):
        if p.is_file() and p.suffix in ('.md','.m','.ps1','.json'): z.write(p,p.name)
print(json.dumps({'report':str(root/'RESULTS_zh.md'),'code_and_report_bundle':str(bundle),'raw_runs_remain_in':str(root/'runs/formal_v1'),'adaptive_changes':changes},ensure_ascii=False))
