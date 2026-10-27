"""Build evidence-bounded reports and update authoritative state after audits."""
from pathlib import Path
import csv,hashlib,json,shutil
import numpy as np

ROOT=Path(__file__).resolve().parent;BASE=ROOT.parent;PROJECT=BASE.parent;OUT=ROOT/'analysis'
def read(name):
    with (OUT/name).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def jsave(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def main():
    a=json.loads((OUT/'analysis_audit.json').read_text());b=json.loads((OUT/'replay_audit.json').read_text());v=json.loads((OUT/'delivery_audit.json').read_text())
    assert a['status']==b['status']==v['status']=='PASS' and v['FE']==3847680
    summary=read('summary.csv');comp=read('paired_comparisons.csv');ret=read('retention_summary.csv');rgroup=read('retention_by_method.csv');eng=read('engineering_summary.csv')
    assert len(comp)==10 and all(float(r['p_holm_5'])>=.05 for r in comp)
    lookup={(float(r['cycle_limit_s']),r['method']):r for r in summary}
    names={'D0':'CD/CD','D1':'PCD/CD','D2':'EAR/CD','D3':'CD/PCD','D4':'PCD/PCD','D5':'EAR/PCD'}
    pair=[r for r in comp if r['contrast']=='D5-D4']
    maxgap=max(float(r['history_HV'])-float(r['final_HV']) for r in ret)
    worst=min((r for r in ret if float(r['cycle_limit_s'])==3.5),key=lambda r:float(r['final_HV']))
    table=['|方法：种群/全局引导档案|2.5 s：HV 中位数|3.5 s：HV 中位数|','|---|---:|---:|']
    for name,meaning in names.items():table.append(f'|{name} {meaning}|{float(lookup[(2.5,name)]["HV_median"]):.6f}|{float(lookup[(3.5,name)]["HV_median"]):.6f}|')
    pt=['|周期上限/s|D5−D4 均值差|逐项 95% bootstrap 区间|胜/负|Holm p|','|---|---:|---|---:|---:|']
    for r in pair:pt.append(f'|{float(r["cycle_limit_s"]):.1f}|{float(r["mean_difference"]):+.6f}|[{float(r["ci95_mean_low"]):+.6f}, {float(r["ci95_mean_high"]):+.6f}]|{r["wins"]}/{r["losses"]}|{float(r["p_holm_5"]):.3f}|')
    engineering=['|周期上限/s|方法|0.1 µm 达标运行|最短周期的中位数/s|','|---|---|---:|---:|']
    for r in eng:
        if r['method'] in ['D0','D4','D5'] and float(r['residual_threshold_um'])==.1:engineering.append(f'|{float(r["cycle_limit_s"]):.1f}|{r["method"]}|{r["attained"]}/10|{float(r["median_shortest_cycle_s"]):.6f}|')
    lines=['# 第二轮实验：结果与研究判断','','日期：2026-10-11。证据类型：假设模型上的数值优化与保存数据重放。', '',
        '**120 次获准运行全部完成，尚未建立耳切相对递归拥挤距离的增量优势。完整历史诊断表明，低值运行主要需要继续排查搜索覆盖；当前不宜把文章主贡献写成“耳切组合算法显著优越”。**','',
        '## 实际执行与检查','',
        f'- 6 方法 × 2 周期上限 × 10 新配对种子，N=64、500 代，共 **3,847,680 FE**。单 MATLAB 进程耗时 **{v["batch_wall_seconds"]:.3f} s**，低于获准的 1,200 s；120 个 MAT 和 240 个 CSV 完整。未重跑、换种子或扩展优化预算。',
        '- 预检覆盖 47 个几何样例、282 次 PCD 与全重算对照，未调用模型。原 28 项输入与新 12 项冻结输入一致。',
        f'- 保存 **3,847,680 条完整评价记录**（X/F/CV/10 项 G）。按原始 G 重算 CV 的差为 0；60,120 个种群状态的独立 HV 最大误差为 {a["independent_HV_max_error"]:.3g}。这不是重新运行物理模型或实体验证。',
        '- 60,000 代的实际种群/档案选择均可重放；完成 180,000 次同集合截断重放。增益−损失恒等式的最大误差约 1e-15。',
        '- 10 项预设检验用全部符号组合独立枚举交叉核对，原始 p 值差为 0。新统计与旧 420 次分开分析。',
        '- 事后计算额外目标模型调用数为 0。所有结果均保留；3 组 PNG 已目视检查，PDF 已生成，未宣称独立逐页 PDF 渲染检查。','',
        '## 六组方法的最终质量','',
        'CD 为一次性拥挤距离，PCD 为逐次重算的递归拥挤距离，EAR 为覆盖约束耳切。所有引导档案均为全局非支配、容量 64。表中每项为 10 次运行中位数。','']+table+['',
        '预设 D1−D0、D3−D0、D4−D0、D5−D4、D2−D1，每工况各作五项 Holm 校正；**10 项均未检出显著差异**。这不证明各方法等效，也不说明不存在较小真实效应。当前样本数没有功效保证。','',
        '耳切增量最直接的比较是 D5−D4：两者使用相同 PCD 引导档案，只改变种群截断。','']+pt+['',
        '两个区间均跨 0；在宽松工况，耳切均值差为负但仍不显著，不能写成已证明耳切有害。在固定 CD 档案下的 D2−D1 也没有显著增益。单独 HV 中位数的高低不替代配对检验。','',
        '## 搜索与保留：新证据回答了什么','',
        '令 U 为某代父代和子代可行并集，P 为父代，P′ 为选择后种群：G=HV(U)−HV(P)，L=HV(U)−HV(P′)，逐代核对 ΔHV=G−L。L 包含容量固有代价，不能都归为算子缺陷；其跨代求和也不是不重复区域的净损失。',
        f'本批全部运行中，完整评价历史 H 的 HV 与最终种群 HV 的最大差为 **{maxgap:.9f}**。无界历史是该次已经评价候选能达到的 HV 上界，不是真实 Pareto 前沿，也不是公平的在线求解器。',
        f'一个明确标为极端个例的宽松工况运行（{worst["method"]}，种子 {worst["seed"]}）：最终 HV={float(worst["final_HV"]):.9f}，全部评价历史 HV={float(worst["history_HV"]):.9f}，历史统一用 PCD 压缩至 64 点后 HV={float(worst["common_PCD64_HV"]):.9f}。其低终点不能通过重新保留已经评价过的点恢复至同批较好运行的水平。',
        '因此当前优先方向是种群实际访问的区域、目录类别与轨迹变量的耦合、以及探索能力。该推断不排除早期筛选改变繁殖轨迹、进而影响后续搜索；本实验没有隔离这些长期反馈的全部因果作用。',
        '同集合重放显示 PCD/EAR 相对于另一截断的每步 HV 差通常很小。这里的 60,000 代不是 60,000 个独立统计样本，只按运行汇总作描述。历史统一 PCD64 有时低于最终种群，因为 PCD 不是 HV 最优子集求解器，不能将负差改为 0。','',
        '## 工程终点','']+engineering+['',
        '0.1 µm 为比较用假设阈值，所有组在两个工况均 10/10 达到。严格工况的 0.05 µm 阈值均 0/10，不能解释成该问题不可行。宽松工况 D5 的 0.1 µm 周期中位数略小，但严格工况没有相同方向；这些描述不构成工程显著改进的证据。','',
        '## 对论文主线的决定','',
        '- 原 420 次正式比较未支持 A/B 机制增益，本轮强对照也未建立耳切增量。保留几何截断及核验作为方法比较内容，不把“耳切显著领先”作为当前主贡献。',
        '- 论文修订强调可复核的滚珠丝杠型号—轨迹联合设计，以及有限集合压缩和实际搜索覆盖的区别；新的机制证据已经并入 `../manuscript/manuscript_en_followup_v03.md`。',
        '- 下一研究方向是按型号分析可行域和轨迹响应结构，再判断是否需要分解搜索或针对性探索机制。没有据此自动追加任何新优化批次。',
        '- 当前仍为研究稿：工程参数是假设值，缺实体验证和部分最近前作全文；不能保证录用或当前中科院分区要求已经满足。','',
        '## 可复核文件','',
        '- `analysis/paired_comparisons.csv`、`summary.csv`、`engineering_summary.csv`：正式预设统计。',
        '- `analysis/retention_summary.csv`、`retention_by_method.csv`、`*_replay.csv`：历史保留与同集合诊断。',
        '- `analysis/analysis_audit.json`、`replay_audit.json`、`delivery_audit.json`：检查范围与结果。',
        '- `provenance/execution.log`、`authorization.json`、`manifest.json`：执行记录、用户授权、冻结输入。',
        '- `README.md`：复现方法、图注和口径。','']
    (ROOT/'RESULTS_zh.md').write_text('\n'.join(lines),encoding='utf-8')
    english=['### 5.7 Prospective follow-up with pruning-crowding controls','',
        'A second, separately authorized experiment was designed after inspecting the initial study. It crossed three population selectors (CD, recursive pruning CD, and bounded EAR) with two global guide-archive selectors (CD and pruning CD). Recursive crowding-distance pruning has direct prior art in the Kukkonen–Deb report [6]; it is used here as a control, not a new mechanism. The six variants D0–D5 correspond respectively to CD/CD, PCD/CD, EAR/CD, CD/PCD, PCD/PCD, and EAR/PCD (population/archive). All archives had capacity 64. Stable evaluation IDs defined common input, tie-handling and output order. This order convention differs from the initial implementation, so the new D0 is not represented as its bitwise replay. The original model, variation parameters and objective scaling were unchanged.',
        'The follow-up comprised 120 runs: six methods, cycle ceilings 2.5 and 3.5 s, and ten new paired seeds 104101–104110, each with 64 individuals and 500 offspring generations. Initialization was included in the 32,064 evaluations per run. The completed budget was 3,847,680 evaluations, and the batch elapsed time was 242.614 s. This is a focused diagnostic on previously studied cases, not an independent problem-family validation or a pooled extension of the first inferential sample.',
        'Five contrasts per case were specified in advance: D1−D0, D3−D0, D4−D0, D5−D4 and D2−D1. Exact paired signed-rank probabilities were Holm-adjusted within each five-comparison family. All ten adjusted comparisons were nonsignificant. For the direct EAR increment under the common PCD guide archive:', '',
        '|Cycle ceiling (s)|Mean paired D5−D4 HV difference|Individual 95% bootstrap interval|Wins/losses|Holm p|','|---|---:|---|---:|---:|']
    for r in pair:english.append(f'|{float(r["cycle_limit_s"]):.1f}|{float(r["mean_difference"]):+.6f}|[{float(r["ci95_mean_low"]):+.6f}, {float(r["ci95_mean_high"]):+.6f}]|{r["wins"]}/{r["losses"]}|{float(r["p_holm_5"]):.3f}|')
    english+=['','The intervals were constructed from 10,000 paired bootstrap resamples with seed 20261011 and are individual, not simultaneous, intervals. Ten repetitions do not establish equivalence or exclude small effects. No seeds were replaced or appended. Host-specific median compute times were approximately 1.8–2.2 s; unlike the earlier timing convention, these include initial evaluation and common logging. They do not establish portable complexity advantages.', '',
        '### 5.8 Full evaluation-history and same-candidate replay','',
        'Every evaluated decision vector, objective vector and raw constraint vector was retained in a passive ledger. Only current population and guide-archive members were visible to reproduction. The analysis independently checked 60,120 population states, with a maximum HV discrepancy of 9.99×10⁻¹⁶; constraint violations reconstructed from saved raw constraints matched exactly. These are recorded-result consistency checks, not new physical-model validation.',
        'All 60,000 generation transitions were replayed, including actual population and guide selections. For feasible parent set P, offspring set Y, candidate union U=P∪Y and selected population P′, the recorded quantities G=HV(U)−HV(P) and L=HV(U)−HV(P′) satisfied HV(P′)−HV(P)=G−L within approximately 10⁻¹⁵. Each saved union was also passed to the three selectors, yielding 180,000 offline selections. These counterfactual sets did not alter subsequent search. Generations are nested observations, not independent experimental units. Selection loss includes unavoidable finite-capacity compression and cannot be identified entirely with poor selection.',
        f'Across the follow-up runs, the maximum difference between the HV of all evaluated feasible candidates and that of the final population was {maxgap:.9f}. In the lowest-HV relaxed-case run (D5, seed {worst["seed"]}), the final population attained {float(worst["final_HV"]):.9f}, the complete evaluated history attained {float(worst["history_HV"]):.9f}, and common PCD compression of that history to 64 points attained {float(worst["common_PCD64_HV"]):.9f}. Thus, post-hoc retention of already evaluated points could not recover the much better quality reached by other runs. The priority is to investigate search coverage and the coupling of catalogue choice with trajectory variables. This finding does not exclude long-term feedback from earlier survival decisions into candidate generation.',
        'The unbounded history is an upper envelope over observed candidates only. It is neither a true Pareto reference nor a fair online competitor. Common PCD compression can occasionally produce lower HV than the final population because it is not an HV-optimal subset solver. Such differences were retained without clipping. Full-replay analysis added no model evaluations.', '',
        '### 5.9 Follow-up engineering endpoint','',
        'At the assumed 0.1 µm residual threshold, every variant attained a feasible design in all ten repetitions of both cases. For D0/D4/D5, the median shortest cycles were respectively '+
        '/'.join(f'{float(next(r for r in eng if float(r["cycle_limit_s"])==2.5 and r["method"]==m and float(r["residual_threshold_um"])==.1)["median_shortest_cycle_s"]):.6f}' for m in ['D0','D4','D5'])+' s at the strict ceiling and '+
        '/'.join(f'{float(next(r for r in eng if float(r["cycle_limit_s"])==3.5 and r["method"]==m and float(r["residual_threshold_um"])==.1)["median_shortest_cycle_s"]):.6f}' for m in ['D0','D4','D5'])+' s at the relaxed ceiling. These descriptive endpoint changes do not establish a consistent engineering improvement. All variants had zero attainment of the 0.05 µm threshold in the strict case; this is not a proof of infeasibility.','']
    section='\n'.join(english)
    (ROOT/'followup_results_en.md').write_text(section,encoding='utf-8')
    old=(BASE/'manuscript/manuscript_en_formal_v02.md').read_text(encoding='utf-8')
    new=old.replace('**Formal numerical results revision, 21 September 2026.** The approved 420-run experiment is complete.','**Two-stage numerical results revision, 11 October 2026.** The original 420-run study and a separately analyzed 120-run diagnostic follow-up are complete.')
    new=new.replace('The study therefore distinguishes verifiable archive compression from unproven search improvement.', 'A separately analyzed 120-run follow-up compared population and guide-archive selectors against recursive crowding-distance pruning. No corrected contrast established an EAR increment; complete evaluation histories indicated that low-quality runs had not discovered comparably high-quality candidate sets. The study therefore distinguishes finite-set representation from search coverage, while retaining uncertainty about long-term selection feedback.')
    new=new.replace('## 6. Discussion and limitations',section+'\n## 6. Discussion and limitations',1)
    new=new.replace('The appropriate next experiment would target a specified failure mode, rather than combine further operators without attribution.', 'The separately specified follow-up targeted population versus guide-archive selection. Its negative comparisons and full-history records prioritize search coverage as the next question, while preserving uncertainty about effect sizes.')
    new=new.replace('Any follow-up claim about bounded geometric archives must compare against that stronger baseline under a new, prospectively fixed protocol.', 'The completed follow-up used that stronger control under a newly frozen protocol and did not establish an EAR advantage. A claim of superiority is therefore not supported by the present two-stage evidence.')
    new=new.replace('One secondary logging requirement was incomplete:', 'In the first experiment, one secondary logging requirement was incomplete:')
    new=new.replace('The primary HV, engineering-endpoint and factorial analyses are unaffected.', 'The primary HV, engineering-endpoint and factorial analyses are unaffected. The follow-up saved absolute coverage radii and full evaluation/selection histories for every applicable call; it does not retrospectively recover the missing first-stage records.')
    new=new.replace('Its HV was close to iterative pruning, so this result supports a narrower archive-representation research question rather than a general optimizer-superiority claim.', 'Its HV was close to iterative pruning. The 120-run follow-up additionally found no significant EAR increment against pruning-crowding controls. Across those runs, complete evaluated histories were close in HV to final populations, including low-quality runs; future work should therefore investigate candidate generation and search coverage, without claiming that selection has no long-term influence.')
    new=new.replace('**Reference completion tasks:**', '6. Kukkonen S., Deb K. *Improved Pruning of Non-Dominated Solutions Based on Crowding Distance for Bi-Objective Optimization Problems*. KanGAL Report 2006007; 2006. [Institutional full text](https://repository.ias.ac.in/83504/1/8-a.pdf). Targeted reading of Section 3 and the GDE3 experiment description, 11 October 2026.\n\n**Reference completion tasks:**')
    new=new.replace('the 420 formal MAT records, final-population and trajectory CSV files,', 'the 420 first-stage MAT records and the separate 120 full-history follow-up MAT records, final-population and trajectory CSV files,')
    target=BASE/'manuscript/manuscript_en_followup_v03.md';assert not target.exists();target.write_text(new,encoding='utf-8')
    ledger='''# 第二轮论断与证据

2026-10-11。与原 CLAIM_LEDGER_formal_v02.md 并存。

|论断|状态|证据|限制|
|---|---|---|---|
|120 次、3,847,680 FE 完成，耗时 242.614 s|SUPPORTED|provenance/execution.log；analysis/delivery_audit.json|不含旧批次和开发计算|
|耳切相对 PCD 的增量未建立|SUPPORTED|paired_comparisons.csv：D5−D4、D2−D1|两工况各 n=10；不显著不是等效|
|保存的种群和档案选择可重放|SUPPORTED|replay_audit.json；*_replay.csv|同一实现的记录重放，不是物理验证|
|低值运行的完整评价历史同样偏低，优先研究搜索覆盖|SUPPORTED_AS_BOUNDED_INFERENCE|retention_summary.csv；history_vs_final.png|不排除早期选择对繁殖的长期反馈；未知真实前沿|
|PCD 全历史 64 点压缩为最优上界|UNSUPPORTED|部分运行低于最终种群|PCD 是启发式，负差保留|
|组合具普遍算法优越性或工程实测优势|UNSUPPORTED|当前无此证据|不得用于论文结论|
'''
    (BASE/'manuscript/CLAIM_LEDGER_followup_v03.md').write_text(ledger,encoding='utf-8')
    readme='''# 第二轮复核入口

已批准并完成：120 次，3,847,680 FE，单 MATLAB 进程，批次 242.614 s。报告见 RESULTS_zh.md。原 420 次未改动，新旧统计不合并。

在上一级 10_dynamic_mode 目录执行：

```powershell
python -X utf8 followup_v02_20261011/prepare.py --check
python -X utf8 followup_v02_20261011/analyze.py
python -X utf8 followup_v02_20261011/verify_results.py
```

analyze.py 需要 Python/NumPy/SciPy，并复用上一级 analysis_formal/analyze_formal.py 的已验证精确统计函数。它重建派生统计，不重新优化。verify_results.py 需要已经存在的 MATLAB 重放结果；重新生成时按以下顺序运行 MATLAB：

```matlab
addpath(fullfile(pwd,'followup_v02_20261011'));
counterfactuals();
plot_results();
```

counterfactuals 读取保存目标，不调用物理模型。verify_results 再独立检查其 CSV 恒等式。原优化入口 v2_study 会拒绝覆盖已有 MAT/日志；查看或复核结果不应重启优化。

图注：final_HV 每点对应一个独立种子，竖线为四分位范围，黑线为中位数；paired_effects 为均值差的逐项 95% bootstrap 区间，非同时区间；history_vs_final 的每点对应一次运行，无界历史不是公平在线算法，虚线为相等线。两面板坐标范围不同。三张 PNG 已打开目视核查，均可读；PDF 已生成但未独立逐页渲染。

MATLAB R2025b；Python 3.14.7、NumPy 2.5.2、SciPy 1.18.0 沿用本机。Python 启动器会输出 real location 提示，但实际分析及审计成功；该提示不作数据错误处理。

结果包含完整评价历史、约束及种群/档案 ID。累计代际增益和损失会重复计入曾经恢复的区域，不能作净区域损失。所有工程输出是显式假设模型预测，没有实物、FEM 或伺服闭环验证。
'''
    (ROOT/'README.md').write_text(readme,encoding='utf-8')
    for p in [BASE/'STATUS.md',PROJECT/'HANDOFF.md',PROJECT/'.aris/runs/ball-screw-earclip-dynamics-20260921.json']:
        dest=ROOT/'provenance'/('before_completion_'+p.name)
        if not dest.exists():shutil.copy2(p,dest)
    statepath=PROJECT/'.aris/runs/ball-screw-earclip-dynamics-20260921.json'
    state=json.loads(statepath.read_text(encoding='utf-8'));state['updated']='2026-10-11'
    for phase in state['phases']:
        if phase['phase']=='followup-protocol':phase.update(status='checked',implementation_started=True,budget_authorized=True,runs_completed=120,actual_FE=3847680,wall_seconds=242.614,artifact='10_dynamic_mode/followup_v02_20261011/analysis/delivery_audit.json')
        if phase['phase']=='paper-writing':phase.update(status='provisional',artifact='10_dynamic_mode/manuscript/manuscript_en_followup_v03.md',submission_candidate=False,note='Two separately analyzed completed batches; no supported EAR superiority. Literature/model limits remain.')
    state['followup_results']=dict(runs=120,FE=3847680,wall_seconds=242.614,adjusted_significant_contrasts=0,new_posthoc_model_evaluations=0,max_history_HV_minus_final=maxgap,scope='Focused diagnostic; prioritizes search coverage, without causal exclusion of selection feedback.')
    state['next_action']='Retain both null comparisons and investigate catalogue-wise feasible-region and trajectory-response structure before proposing any new optimizer trial. No new batch running; current authorized batch complete.'
    jsave(statepath,state);shutil.copy2(statepath,ROOT/'provenance/aris_completion_snapshot.json')
    status='# 当前研究状态：2026-10-11（第二轮完成）\n\n120 次已批准实验全部完成，3,847,680 FE，耗时 242.614 s；独立 HV、约束记录、精确统计、60,000 代选择重放通过。10 项预设比较均未显著；耳切增量仍未建立。完整历史与终点差较小，优先研究搜索覆盖，但不排除选择的长期反馈。\n\n报告：`followup_v02_20261011/RESULTS_zh.md`。英文稿：`manuscript/manuscript_en_followup_v03.md`。原 420 次结果和旧稿保持不变；新旧结果分开统计。当前稿件不是投稿候选，物理验证、新颖性与官方 CAS 证据边界保留。无新增批次运行。\n\n'
    (BASE/'STATUS.md').write_text(status+(ROOT/'provenance/before_completion_STATUS.md').read_text(encoding='utf-8').replace('# 当前研究状态：2026-10-11','# 历史状态：第二轮开始前',1),encoding='utf-8')
    handoff='# 最新交接：2026-10-11（已批准第二轮完成）\n\n用户已批准并已执行 120 次/3,847,680 FE/1,200 s 单进程方案；实际 242.614 s 完成。不要再次询问该批授权或再次运行同批。原 420 次与本轮分开统计，两个批次优化 FE 合计 17,314,560（不含开发与第一轮额外审计）。\n\n先读 `10_dynamic_mode/followup_v02_20261011/RESULTS_zh.md`、`analysis/delivery_audit.json`，论文为 `10_dynamic_mode/manuscript/manuscript_en_followup_v03.md`。10 项校正检验均不显著；60,000 代重放和完整历史核对支持优先研究搜索覆盖，不能宣称 EAR 优于 PCD 或所有算法等效。无新目标模型复算，无实体/FEM 验证，无追加优化。\n\n下一步应分析按型号的可行域、轨迹响应及探索范围，再提出具体可证伪机制；当前没有新的实验预算或自动化。前一阶段的待授权文字仅为历史记录，以下保留。\n\n'
    (PROJECT/'HANDOFF.md').write_text(handoff+(ROOT/'provenance/before_completion_HANDOFF.md').read_text(encoding='utf-8'),encoding='utf-8')
    shutil.copy2(PROJECT/'HANDOFF.md',ROOT/'provenance/HANDOFF_completion_snapshot.md')
    # Check generated values against the audited CSVs, then register final artifacts.
    for r in pair:assert f'{float(r["mean_difference"]):+.6f}' in new
    assert '### 5.7' in new and '### 5.8' in new and '### 5.9' in new
    artifacts=[ROOT/'RESULTS_zh.md',ROOT/'README.md',target,BASE/'manuscript/CLAIM_LEDGER_followup_v03.md',OUT/'analysis_audit.json',OUT/'replay_audit.json',OUT/'delivery_audit.json',ROOT/'analyze.py',ROOT/'counterfactuals.m',ROOT/'verify_results.py',ROOT/'plot_results.m',ROOT/'publish.py']
    jsave(ROOT/'provenance/delivery_manifest.json',dict(date='2026-10-11',files=[dict(path=str(p.relative_to(BASE)),sha256=sha(p)) for p in artifacts]))
    print(json.dumps(dict(report=str(ROOT/'RESULTS_zh.md'),manuscript=str(target),max_history_gap=maxgap,formal_FE_total_two_batches=17314560),ensure_ascii=False,indent=2))

if __name__=='__main__':main()
