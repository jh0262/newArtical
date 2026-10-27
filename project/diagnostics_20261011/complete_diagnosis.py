"""Publish the zero-FE diagnosis and append its state without changing formal data."""
from pathlib import Path
import csv, hashlib, json, shutil

ROOT=Path(__file__).resolve().parents[1]
OUT=Path(__file__).resolve().parent
PROJECT=ROOT.parent

def read(name):
    with (OUT/name).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    audit=json.loads((OUT/'trace_audit.json').read_text(encoding='utf-8'))
    assert audit['status']=='PASS' and audit['new_objective_evaluations']==0
    rows=read('trace_by_run.csv'); summaries=read('trace_summary.csv')
    mode=[r for r in rows if r['method'].startswith('MODE-')]
    maxgap=max(float(r['peak_minus_final']) for r in mode)
    worst=min((r for r in mode if r['method']=='MODE-CD-G' and float(r['cycle_limit_s'])==3.5),key=lambda r:float(r['final_HV']))
    lines=['# 下一步研究判断与已完成诊断','', '日期：2026-10-11。当前轮新增目标评价 **0 FE**；已核对原 28 项冻结输入和全部 420 个 MAT 哈希。', '',
        '**建议先开展小规模机制定位，而不是立即扩写“改进算法优越性”论文。下一轮要比较强截断对照，并记录完整搜索历史，判断找不到好解和未保住好解各占什么作用。**','',
        '## 本轮新增证据','',
        '1. 静态代码证据：`matlab/bs_mode.m:21–22` 将档案更新和环境选择分别调用；EAR 标记只传给 `bs_select`。`matlab/bs_archive.m:7,27` 的两类档案截断均调用一次性 CD。因此原 EAR 机制没有替代引导档案截断。',
        f'2. 轨迹证据：全部四种 MODE、三工况、20 种子共 240 次运行中，历史最佳种群 HV 与最终 HV 的最大差仅为 **{maxgap:.9f}**。MODE 会回落，但不能因此把大幅运行差异简单归为末期丢点。',
        f'3. 作为明确标注的极端个例，3.5 s 基础 MODE 最低终点运行是种子 {worst["seed"]}：最终 HV={float(worst["final_HV"]):.9f}，该次保存轨迹的最高 HV={float(worst["peak_HV"]):.9f}。它并未在已保存的种群轨迹中先达到高 HV 再大幅丢失。该个例不代表所有运行，也不能排除早期删点影响后续搜索。',
        '4. 最近直接前作：已针对性读取 Kukkonen–Deb 报告的递归 CD 伪代码和 GDE3 实验段落。PCD 必须作为直接对照；不是新的创新机制。详见 `LITERATURE_CHECK.md`。','',
        '## 保存轨迹的描述性结果','',
        '以下每组 20 次。回落次数指相邻代 HV 下降超过 1e-10；“峰值−终点”只比较某一代种群，不是历史全候选并集。没有新增事后显著性检验。','',
        '|周期上限/s|方法|回落代数中位数|终点低于峰值的运行数|峰值−终点最大差|',
        '|---|---|---:|---:|---:|']
    for r in summaries:
        if r['method'] in ['MODE-CD-G','MODE-EAR-G','MODE-EAR-S']:
            lines.append(f'|{float(r["cycle_limit_s"]):.1f}|{r["method"]}|{float(r["median_drop_generations"]):.1f}|{r["runs_with_final_below_peak"]}/20|{float(r["max_peak_minus_final"]):.9f}|')
    lines+=['','原来没有保存所有子代和全部候选历史，不能从这些标量轨迹重建每次选择的损失。CD 和 EAR 不保证 HV 单调，检测到回落本身不说明程序错误。','',
        '## 建议执行的下一批','',
        '- 种群截断 CD/PCD/EAR × 全局引导档案截断 CD/PCD，共 6 组；不同时引入新的变异、自适应和局部搜索。',
        '- 两个周期上限 2.5/3.5 s，每组 10 个新配对种子，64 个体、500 代：**120 次、3,847,680 FE**。单 MATLAB 进程，建议上限 **20 分钟**，运行间检查。',
        '- 保存全部评价记录与选择索引，运行后核对“候选产生增益−保留损失=种群 HV 变化”，并在完全相同候选集上比较三种截断。',
        '- 以 EAR 对 PCD 的增量决定是否继续耳切主线。若强对照吸收收益，就改为问题结构和工程联合设计研究；不再用增加机制寻找显著性。','',
        '具体方法、种子、统计、日志、失败与停止规则见 [FOLLOWUP_PROTOCOL.md](FOLLOWUP_PROTOCOL.md)。这一轮是旧结果指导的机制诊断，不是投稿所需的全部确认性证据。','',
        '## 完成与尚未完成','',
        '已完成：旧记录完整性复核、210,000 个代际变化的零 FE 诊断、直接前作核验、下一批可审阅协议、原生 ARIS 与交接更新。','',
        '尚未完成：新优化器实现、确定性预检、代码冻结以及 120 次性能运行。旧批次预算已完整执行；此处的新预算为建议，不能写成已授权。数值模型仍无实体或有限元验证，新颖性与当前官方 CAS 分区证据仍待补齐。','',
        '复核入口：`python -X utf8 diagnostics_20261011/trace_diagnosis.py`。只读取旧结果并更新本目录派生 CSV/JSON，不调用模型、不改旧结果。','']
    (OUT/'NEXT_STEP_zh.md').write_text('\n'.join(lines),encoding='utf-8')
    for p in [ROOT/'STATUS.md',PROJECT/'HANDOFF.md',PROJECT/'.aris/runs/ball-screw-earclip-dynamics-20260921.json']:
        dest=OUT/('before_'+p.name)
        if not dest.exists():shutil.copy2(p,dest)
    state_path=PROJECT/'.aris/runs/ball-screw-earclip-dynamics-20260921.json'
    state=json.loads(state_path.read_text(encoding='utf-8'))
    existing=[p for p in state['phases'] if p['phase'] not in ['followup-trace-diagnosis','followup-protocol']]
    state['phases']=existing+[
        dict(phase='followup-trace-diagnosis',status='checked',artifact='10_dynamic_mode/diagnostics_20261011/trace_audit.json',new_objective_evaluations=0,evidence_scope='Raw hash checks and posthoc trace arithmetic; not a new performance trial or causal decomposition.'),
        dict(phase='followup-protocol',status='produced',artifact='10_dynamic_mode/diagnostics_20261011/FOLLOWUP_PROTOCOL.md',implementation_started=False,runs_completed=0,budget_authorized=False,proposed_runs=120,proposed_FE=3847680,proposed_workers=1,proposed_wall_seconds=1200)]
    state['updated']='2026-10-11'
    state['next_action']='Obtain decision on concrete 120-run diagnostic budget; then implement isolated 3x2 selector/archive variants, verify on saved data, freeze new inputs, and execute within authorization. Old 420-run comparison remains checked and unchanged.'
    state['followup_diagnosis']=dict(max_MODE_trace_peak_minus_final=maxgap,new_objective_evaluations=0,literature_status='Kukkonen-Deb report section 3 and GDE3 experiment passage checked; global novelty unresolved.')
    state_path.write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    shutil.copy2(state_path,OUT/'aris_after_diagnosis_snapshot.json')
    status=(OUT/'before_STATUS.md').read_text(encoding='utf-8')
    status=status.replace('# 当前研究判断与状态','# 2026-09-21 正式实验状态（保留）',1)
    note='# 当前研究状态：2026-10-11\n\n旧 420 次正式结果及哈希保持不变；新增 0 FE 轨迹诊断已完成。新证据与下一轮协议见 `diagnostics_20261011/NEXT_STEP_zh.md` 和 `FOLLOWUP_PROTOCOL.md`。建议下一批 6 方法 × 2 工况 × 10 种子，120 次/3,847,680 FE，单进程上限 20 分钟；预算尚未授权，代码尚未实现、运行尚未启动。原正式负结果与稿件边界不变。\n\n'
    (ROOT/'STATUS.md').write_text(note+status,encoding='utf-8')
    old=(OUT/'before_HANDOFF.md').read_text(encoding='utf-8')
    handoff='# 最新交接：2026-10-11\n\n本轮响应用户“下一步”，已完成零 FE 诊断和直接前作核验。读取 `10_dynamic_mode/diagnostics_20261011/NEXT_STEP_zh.md`。原 28 项输入与 420 个 MAT 哈希均保持一致，没有新优化运行。\n\n发现：EAR 仅用于种群选择；原引导档案均用 CD。MODE 保存轨迹的末期回落很小，不足以把整体差异归结为末期丢点。下一轮拟用 CD/PCD/EAR 种群选择 × CD/PCD 全局档案的 3×2 因子结构，保存所有候选与选择 ID，以分解搜索和保留作用。\n\n可审阅协议：`10_dynamic_mode/diagnostics_20261011/FOLLOWUP_PROTOCOL.md`。建议 120 次、3,847,680 FE，N=64、500 代，2.5/3.5 s 两工况，种子 104101–104110，1 进程，1,200 s 墙钟上限，运行间检查。当前仅为新预算建议，未实现、未冻结代码、未获运行授权。原 420 次已完整执行，不能当成本轮授权；同一新预算一旦得到明确答复就记录并持续实现、预检、冻结、执行，不再重复询问。\n\n以下保留上一阶段完整交接。\n\n'
    (PROJECT/'HANDOFF.md').write_text(handoff+old,encoding='utf-8')
    files=[p for p in OUT.iterdir() if p.is_file() and p.name!='diagnosis_manifest.json']
    artifact=dict(date='2026-10-11',new_objective_evaluations=0,protocol_status='PROPOSED_NOT_EXECUTED',files=[dict(file=p.name,sha256=sha(p)) for p in sorted(files)])
    (OUT/'diagnosis_manifest.json').write_text(json.dumps(artifact,ensure_ascii=False,indent=2),encoding='utf-8')
    assert 6*2*10*64*501==3847680
    assert next(p for p in state['phases'] if p['phase']=='formal-comparison')['runs_completed']==420
    print(json.dumps({'report':str(OUT/'NEXT_STEP_zh.md'),'max_MODE_peak_minus_final':maxgap,'proposed_runs':120,'proposed_FE':3847680,'new_FE':0,'implementation_started':False,'new_budget_authorized':False},ensure_ascii=False,indent=2))

if __name__=='__main__':main()
