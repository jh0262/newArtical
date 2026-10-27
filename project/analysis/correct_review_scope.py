"""Correct manuscript authority and scope; never run/alter optimisation data."""
from pathlib import Path
import json,hashlib,datetime,re
ROOT=Path(__file__).resolve().parents[1];PAPER=ROOT.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
backup=ROOT/'qa/scope_correction';backup.mkdir(exist_ok=True)
changed=[]
correction=PAPER/'论文修订_20261015/评审范围纠正与原稿修订依据.md'
note=('> **适用范围纠正（2026-10-15）：** 本文件记录另写的PADE-FE v4分支，不是原始PADE代码的原样复现。'
      '其中性能结果不替换原论文PADE–DE比较或文献表；由该分支推广到原论文创新性、发表潜力及改题要求的判断已撤回。'
      '本分支单独归档，不再执行优化实验。当前依据见[评审范围纠正]('+correction.as_posix()+')。\n\n')
def replace(path,text):
    old=path.read_bytes()
    archive=backup/path.relative_to(ROOT).as_posix().replace('/','__')
    if not archive.exists():archive.write_bytes(old)
    path.write_text(text,encoding='utf-8')
    changed.append({'path':path.relative_to(ROOT).as_posix(),'before_sha256':hashlib.sha256(old).hexdigest(),'after_sha256':sha(path),'backup':archive.relative_to(ROOT).as_posix()})
for rel in ['README.md','必改项落实与更新评审.md','HANDOFF.md','manuscript/manuscript_text.txt','analysis/独立结果解读.md']:
    p=ROOT/rel
    if not p.exists():continue
    t=p.read_text('utf-8')
    if rel=='README.md':
        t=t.replace('实验和修订工作已落实，当前结果不支持按“新增机制提升同父性能”的主张直接投稿。','上述结论仅限本PADE-FE v4实现，不用于判断原始PADE论文的发表潜力。')
        t=t.replace('主要交付：','该分支历史交付（不作为当前原稿主稿）：')
    if rel=='必改项落实与更新评审.md':
        t=t.replace('## 六、更新后的创新性和发表建议','## 六、v4独立分支的历史分析及适用范围')
        t=t.replace('相较上一轮“中等创新、大修后投稿”的判断，当前这一投稿主张的证据应下调，而不是继续用对经典DE的优势掩盖父对照结果。','该分析只限另写的v4分支；撤回据此下调原始PADE论文评价的推论，原稿以作者原实验数据为依据。')
        t=t.replace('按现有完整证据，较自洽的论文方向是','仅对这一独立v4分支，可讨论的研究方向是')
    replace(p,note+t)
statepath=ROOT/'.sci/state.json';s=json.loads(statepath.read_text('utf-8'))
s['scope_correction']={'corrected_at_utc':now,'authority':'User explicitly rejects re-running/re-evaluating original PADE results.','active_manuscript':str(PAPER/'论文修订_20261015/PADE_Mechanical_Optimization_Full_Paper-v3.docx'),'review_basis':str(correction),'new_optimization_runs':'not_authorized_under_current_scope','v4_status':'archived_separate_reimplementation_not_original_paper_evaluation'}
s['scientific_outcome_scope']='PADE-FE v4 only; must not be generalized to original PADE manuscript.'
s['next_action']='Revise original-paper explanation, definitions, novelty positioning and presentation using author-supplied original results; do not launch optimization.'
s['delivery_status']='v4_archived_original_result_manuscript_restored_as_basis'
s['scientific_outcome']['original_pade_submission_assessment']='Not determined by v4 branch.'
replace(statepath,json.dumps(s,ensure_ascii=False,indent=2))
oldreview=PAPER/'论文修订_20261015/科学评估与修订说明.md'
orig=oldreview.read_text('utf-8')
saved=backup/'v3_scientific_review_before_scope_correction.md'
if not saved.exists():saved.write_bytes(oldreview.read_bytes())
oldreview.write_text('> **当前范围说明（2026-10-15）：** 原实验真实性按作者说明接受。下文曾列出的新增同父、等FE与消融要求，不再作为本轮必须执行的实验或认可原结果的前提；当前执行范围以[评审范围纠正与原稿修订依据]('+correction.as_posix()+')为准。已完成的数学与文字修订继续保留。\n\n'+orig,encoding='utf-8')
inputs=json.loads((ROOT/'INPUT_MANIFEST.json').read_text('utf-8'))
preserved=[{'path':a['path'],'sha256':sha(Path(a['path'])),'unchanged':sha(Path(a['path']))==a['sha256']} for a in inputs]
v3=PAPER/'论文修订_20261015/PADE_Mechanical_Optimization_Full_Paper-v3.docx'
assert sha(v3)=='f8063361b2cc22156081c8197d3519ca0aae45d51b4117986113d00f3685a7cb'
assert all(a['unchanged'] for a in preserved)
manifestpath=ROOT/'DELIVERY_MANIFEST.json';m=json.loads(manifestpath.read_text('utf-8'))
m['scope_corrected_at_utc']=now
m['current_use']='Historical PADE-FE v4 delivery only; not original PADE paper authority.'
m['original_paper_authority']=str(correction)
m['scientific_outcome_scope']=s['scientific_outcome_scope']
for rec in m['files']:
    p=ROOT/rec['path']
    if any(x['path']==rec['path'] for x in changed):rec.update(bytes=p.stat().st_size,sha256=sha(p))
replace(manifestpath,json.dumps(m,ensure_ascii=False,indent=2))
record={'corrected_at_utc':now,'primary_manuscript':str(v3),'primary_sha256':sha(v3),'review_basis':str(correction),'original_inputs':preserved,'changed_metadata':changed,'optimization_runs_started':0,'objective_calls':0,'raw_data_files_modified':0,'MATLAB_code_files_modified':0,'Word_files_modified':0,'withdrawn_inference':'Using a changed v4 implementation to replace or downgrade original PADE experimental conclusions.'}
(ROOT/'SCOPE_CORRECTION_MANIFEST.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'scope_corrected':True,'original_inputs_unchanged':True,'v3_unchanged':True,'optimization_runs_started':0,'data_or_code_modified':False},ensure_ascii=False))
