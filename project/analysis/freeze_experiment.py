from pathlib import Path
import json,hashlib,datetime
ROOT=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
core=['pade_solve_fe.m','pade_problems.m','pade_defaults.m','pade_variants.m','pade_worker.m']
code={n:sha(ROOT/'code'/n) for n in core}
combined='\n'.join(n+':'+code[n] for n in sorted(code))
cfg={n:sha(ROOT/n) for n in ['CONFIG.json','PROTOCOL.md','comparisons.csv']}
manifest=dict(version='PADE-FE-v4.0',frozen_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
 code_hash=hashlib.sha256(combined.encode()).hexdigest(),problem_hash=code['pade_problems.m'],
 config_hash=hashlib.sha256('\n'.join(n+':'+cfg[n] for n in sorted(cfg)).encode()).hexdigest(),
 code_files=code,protocol_files=cfg,diagnostics=json.loads((ROOT/'qa/solver_checks.json').read_text('utf-8'))['passed'])
assert manifest['diagnostics']
target=ROOT/'FROZEN_MANIFEST.json'
if target.exists() and any((ROOT/'raw').glob('**/*.mat')):
 old=json.loads(target.read_text('utf-8'));assert old['code_hash']==manifest['code_hash'] and old['config_hash']==manifest['config_hash']
else:target.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
stateFile=ROOT/'.sci/state.json';s=json.loads(stateFile.read_text('utf-8'))
s['authorization_records']=[{'source':'user latest instruction 2026-10-15','scope':'local implementation, comparison experiments, analysis and manuscript revision','text':'继续，把评审报告中的必改项逐项落实，优先补齐同父自适应DE、相同函数评价预算和核心机制消融的比较实验，进一步完善论文与代码。'}]
s['budget']={'fe':194577300,'source':'original per-run N/T converted to FE; 30 seeds; prespecified 6/12 nested ablations plus classic DE','wall_hours':None,'formal_runs':5640,'workers':6,'qa_search_FE_separate':True}
for st in s['stages']:
 if st['id'] in ['S00','S01','S02','S03','S04','S05']:
  st['status']='checked';st['evidence_scope']='Protocol, model source preservation, independent static review and 11 MATLAB implementation diagnostics. Literature coverage includes three full texts; two publisher previews.'
 elif st['id']=='S06':st['status']='running';st['evidence_scope']='Exact FE paired runs; no result claim until complete.'
s['active_protocol']='PROTOCOL.md';s['frozen_manifest']='FROZEN_MANIFEST.json'
stateFile.write_text(json.dumps(s,ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'HANDOFF.md').write_text('# 当前进度\n\n已冻结同父、等FE及嵌套全因素实验：5640次，194577300搜索FE，6进程。授权来自2026-10-15用户最新指令。11组实际MATLAB实现诊断通过；完整原稿和源码未修改。\n\n下一步：执行pade_launch并保存raw；检查所有任务、FE账本、种子/初始化与模型回代；运行预设配对统计，生成图表并另存v4论文。不得依据中途结果改变配置或增删种子。\n',encoding='utf-8')
print(json.dumps({k:manifest[k] for k in ['version','code_hash','config_hash']},ensure_ascii=False))
