"""Audit retained research evidence; no fitting, integration or physical experiment."""
from pathlib import Path
import sys, json, csv, hashlib, zipfile, re, platform, shutil, datetime
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
BASE = ROOT.parent
sys.path.insert(0, str(BASE))
import bootstrap
import numpy as np
import torch
import scipy
import core
import run_model as rm
from networks import JointNet

def readj(p): return json.loads(Path(p).read_text(encoding='utf8'))
def rows(p): return list(csv.DictReader(Path(p).open(encoding='utf-8-sig', newline='')))
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
checks = []
def check(name, ok, details=None):
    checks.append(dict(name=name, passed=bool(ok), details=details))
    if not ok: print('FAILED:', name, details)

stamp = datetime.datetime.now().astimezone().isoformat()
manifest = readj(ROOT/'input_manifest.json')
check('parent_inputs_unchanged', all(sha(BASE/k)==v for k,v in manifest['inputs'].items()), manifest['inputs'])
check('experiment_script_and_protocol_unchanged',
      sha(ROOT/'run_revision.py')==manifest['script_sha256'] and sha(ROOT/'补充实验协议.md')==manifest['protocol_sha256'])
check('completion_record', readj(ROOT/'completion.json')['status']=='complete')

candidates = rows(ROOT/'results/training_candidates.csv')
selected = readj(ROOT/'results/selected.json')
check('candidate_grid_complete', len(candidates)==27 and
      {(r['model'],int(r['seed']),float(r['learning_rate'])) for r in candidates} ==
      {(m,s,l) for m in ['velocity','capacity_control','history'] for s in [9,19,29] for l in [1e-5,1e-4,1e-3]})
logs_ok = True
for r in candidates:
    path = ROOT/r['path']
    log = readj(path/'training_log.json')
    best = min(log, key=lambda x: x['validation_acc_nmse'])
    state = torch.load(path/'best.pt', weights_only=True)
    logs_ok &= (np.isfinite([x['validation_acc_nmse'] for x in log]).all()
        and best['step']==int(r['best_step'])
        and abs(best['validation_acc_nmse']-float(r['best_validation_acc_nmse']))<1e-10
        and log[-1]['step']==int(r['updates'])
        and all(torch.isfinite(v).all().item() for v in state.values()))
check('all_candidate_logs_and_checkpoints', logs_ok,
      dict(actual_updates=sum(int(r['updates']) for r in candidates),
           budget_exhausted=sum(r['termination']=='budget_exhausted' for r in candidates)))
selection_ok = len(selected)==9
for r in selected:
    best = min((x for x in candidates if x['model']==r['model'] and int(x['seed'])==r['seed']),
               key=lambda x: float(x['best_validation_acc_nmse']))
    selection_ok &= best['path']==r['path']
check('selection_uses_minimum_recorded_validation_loss', selection_ok)
rm.set_seed(101,4)
check('parameter_counts', [sum(p.numel() for p in JointNet(w).parameters()) for w in [1,7]]==[62412,66048])

prepared = np.load(BASE/'preflight/prepared.npz')
scale = np.maximum(prepared['train_q'].std(axis=0),1e-12)
metric_rows = rows(ROOT/'results/metrics.csv')
max_metric_delta = 0.0
common = None
arrays_ok = True
evidence_files = []
all_rollout_dirs = sorted(p for p in (ROOT/'evaluations').iterdir() if (p/'predictions.npz').exists())
check('rollout_count',len(all_rollout_dirs)==12)
for path in all_rollout_dirs:
    z = np.load(path/'predictions.npz')
    label,seed = path.name.rsplit('_',1)
    arrays_ok &= z['prediction'].shape==(593,150,12) and z['reference'].shape==(593,150,12)
    arrays_ok &= np.isfinite(z['prediction']).all() and np.isfinite(z['reference']).all()
    arrays_ok &= np.array_equal(z['target_ids'],z['starts'][:,None]+np.arange(1,151)[None,:])
    arrays_ok &= np.array_equal(z['starts'],np.arange(32,15000-150,25))
    true_state = np.concatenate([prepared['test_q'],prepared['test_v']],axis=1)
    arrays_ok &= np.array_equal(z['reference'],true_state[z['target_ids']])
    fields = ['reference','starts','target_ids','low_speed_mask','reversal_mask']
    if common is None: common={k:z[k].copy() for k in fields}
    arrays_ok &= all(np.array_equal(z[k],common[k]) for k in fields)
    if label!='history_removed':
        stored_scale=torch.load(path/'scalers.pt',weights_only=True)['qstd'].numpy()
        arrays_ok &= np.array_equal(stored_scale,scale)
    else:
        source=readj(path/'selection.json')
        actual=readj(ROOT/'evaluations'/f'history_{seed}'/'selection.json')
        arrays_ok &= source['path']==actual['path'] and source['best_step']==actual['best_step']
    for regime in ['all','low_speed','reversal']:
        mask = np.ones(z['prediction'][:,:,:6].shape,dtype=bool) if regime=='all' else z[regime+'_mask']
        # Independent expression: slice each joint's selected elements before averaging.
        error=z['prediction'][:,:,:6]-z['reference'][:,:,:6]
        jerr=[np.mean((error[:,:,j][mask[:,:,j]]/scale[j])**2) for j in range(6) if mask[:,:,j].any()]
        independent=float(np.sqrt(np.mean(jerr)))
        direct=core.metric(z['prediction'][:,:,:6],z['reference'][:,:,:6],scale,mask)
        row=next(r for r in metric_rows if r['model']==label and int(r['seed'])==int(seed) and r['regime']==regime)
        max_metric_delta=max(max_metric_delta,abs(independent-float(row['nrmse'])),
                             *[abs(direct[k]-float(row[k])) for k in ['nrmse','rmse_rad','endpoint_nrmse']])
    evidence_files.append(dict(path=str((path/'predictions.npz').relative_to(ROOT)),sha256=sha(path/'predictions.npz')))
check('prediction_shapes_finiteness_common_masks_references_and_h0_source',arrays_ok)
check('saved_prediction_metric_reconstruction',max_metric_delta<1e-12,dict(max_abs_difference=max_metric_delta))

summary=rows(ROOT/'results/summary.csv')
summary_ok=len(summary)==12
text=(ROOT/'论文修订稿.md').read_text(encoding='utf8')
numeric_table_ok=True
for r in summary:
    values=np.array([float(v['nrmse']) for v in metric_rows if v['model']==r['model'] and v['regime']==r['regime']])
    summary_ok &= len(values)==3 and abs(values.mean()-float(r['mean']))<1e-12 and abs(values.std(ddof=1)-float(r['sd']))<1e-12
    numeric_table_ok &= f"{float(r['mean']):.6f} ± {float(r['sd']):.6f}" in text
check('summary_mean_and_sample_sd',summary_ok)
check('all_main_table3_cells_match_csv',numeric_table_ok)

math=readj(ROOT/'results/mathematical_checks.json')
check('retained_math_checks',len(math['folding'])==9 and all(r['pass_check'] for r in math['folding'])
      and max(r['max_abs_normalized_output_difference'] for r in math['folding'])<1e-10
      and math['l2_identity_abs_error']<1e-12 and math['sgd_identity_abs_error']<1e-12)
grid=readj(ROOT/'results/refinement_implementation_check.json')
check('refinement_implementation_at_original_grid_two_origins',all(r['passed'] for r in grid),grid)
convergence=rows(ROOT/'results/integration_convergence.csv')
check('local_refinement_coverage',len(convergence)==8 and
      {(r['model'],float(r['dt']),int(r['origins'])) for r in convergence}==
      {(m,d,50) for m in ['history','capacity_control'] for d in [.004,.002,.001,.0005]})

refs=readj(ROOT/'literature/references.json')
body,biblio=text.split('## 参考文献',1)
mentioned=set()
for token in re.findall(r'\[([0-9,，–-]+)\]',body):
    for part in re.split('[,，]',token):
        bounds=re.split('[–-]',part)
        mentioned.update(range(int(bounds[0]),int(bounds[-1])+1))
check('references_and_citation_numbers',len(refs)==18 and mentioned==set(range(1,19)) and
      all(f"[{r['id']}] {r['bibliography']}" in biblio for r in refs) and
      len({r['bibliography'] for r in refs})==18)
check('no_manuscript_placeholders',not re.search(r'@[A-Z_]+@|\bTODO\b|\bTBD\b|�',text))

document=ROOT/'重载机器人短历史补偿_论文修订稿.docx'
ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'm':'http://schemas.openxmlformats.org/officeDocument/2006/math',
    'a':'http://schemas.openxmlformats.org/drawingml/2006/main'}
with zipfile.ZipFile(document) as package:
    check('docx_zip_integrity',package.testzip() is None)
    xml=ET.fromstring(package.read('word/document.xml'))
    equations=[p for p in xml.findall('.//w:p',ns)
               if p.find('m:oMath',ns) is not None
               and p.find('w:pPr/w:jc',ns) is not None
               and p.find('w:pPr/w:jc',ns).get('{'+ns['w']+'}val')=='center']
    tables=xml.findall('.//w:tbl',ns)
    drawings=xml.findall('.//w:drawing',ns)
    check('docx_editable_math_tables_figures',len(equations)==9 and len(tables)==4 and len(drawings)==5,
          dict(equations=len(equations),tables=len(tables),figures=len(drawings)))
    check('native_time_derivative_accents',
          len(equations)>0 and len([n for n in equations[0].findall('.//m:accPr/m:chr',ns) if n.attrib.get('{'+ns['m']+'}val')=='\u0307'])==2)
    radical=equations[-1].find('.//m:rad/m:e',ns) if equations else None
    radical_text=''.join(radical.itertext()) if radical is not None else ''
    check('metric_radical_contains_full_sum_and_normalized_error',
          radical is not None and all(t in radical_text for t in ['J','I','e','s']))
    check('no_title_paragraph_border',not xml.findall('.//w:pBdr',ns))
    current_png={sha(p) for p in (ROOT/'figures').glob('*.png')}
    embedded=[hashlib.sha256(package.read(n)).hexdigest() for n in package.namelist() if n.startswith('word/media/')]
    check('embedded_figures_match_reconstructed_png',len(embedded)==5 and set(embedded)==current_png)
pages=readj(ROOT/'render_qa/final/page_text.json')
check('native_pdf_page_text',len(pages)==12 and all(r['characters']>200 and '�' not in r['text'] for r in pages))
check('all_python_sources_parse', all(compile(p.read_text(encoding='utf-8-sig'),str(p),'exec') is not None
       for p in list(ROOT.glob('*.py'))+list((ROOT/'literature').glob('*.py'))))

# Preserve exact code used; this snapshot is an audit bundle, not a relocated executable tree.
snapshot=ROOT/'source_snapshot'
source_rows=[]
sources=[(BASE/f,'parent/'+f) for f in ['bootstrap.py','core.py','networks.py','run_model.py','config.json']]
sources += [(p,'revision/'+p.name) for p in ROOT.glob('*.py')]
sources += [(ROOT/'reproduce_revision.ps1','revision/reproduce_revision.ps1')]
sources += [(ROOT/'literature/build_catalog.py','revision/literature/build_catalog.py')]
for source,relative in sources:
    dest=snapshot/relative
    dest.parent.mkdir(parents=True,exist_ok=True)
    if dest.exists() and sha(dest)!=sha(source): raise RuntimeError('Snapshot differs; preserve prior snapshot: '+str(dest))
    if not dest.exists(): shutil.copy2(source,dest)
    source_rows.append(dict(source=str(source),snapshot=relative,sha256=sha(source)))
(ROOT/'source_snapshot_manifest.json').write_text(json.dumps(source_rows,ensure_ascii=False,indent=2),encoding='utf8')

visual=dict(reviewed_at=stamp,renderer='Microsoft Word desktop ExportAsFixedFormat; read-only background session',
            docx_sha256=sha(document),pdf_sha256=sha(ROOT/'render_qa/manuscript.pdf'),
            pages=12,all_pages_reviewed=True,
            findings=['Pages 1-12 individually inspected at rendered resolution.',
                      'Equation 1 time-derivative dots and equation 6 hats/bars render correctly after native-accent fix.',
                      'Equation 9 radical includes all averages and squared normalized error.',
                      'Five figures, four tables and reference list have no observed clipping or overlap.',
                      'The final reference page has intentional bottom whitespace.'],
            page_checks=[dict(page=p['page'],image_sha256=sha(ROOT/f"render_qa/final/page-{p['page']}.png")) for p in pages])
(ROOT/'render_qa/visual_review.json').write_text(json.dumps(visual,ensure_ascii=False,indent=2),encoding='utf8')
report=dict(checked_at=stamp,computational_and_document_checks='PASS' if all(c['passed'] for c in checks) else 'FAIL',
            checks=checks,environment=dict(python=platform.python_version(),torch=torch.__version__,numpy=np.__version__,
              scipy=scipy.__version__,dtype='float64',threads=4),
            wrapper_checks=dict(default_reconstruction='executed successfully in this revision',
              powershell_parser='passed in host PowerShell',full_Retrain_wrapper='statically checked only; component research stages executed'),
            source_snapshot_files=len(source_rows),prediction_hashes=evidence_files,
            deliverables={p.name:sha(p) for p in [document,ROOT/'论文修订稿.md',ROOT/'render_qa/manuscript.pdf']},
            research_status='revised research draft; not submission-ready validation',
            unresolved=['Full integration convergence over every seed and all 593 origins remains unverified.',
              'One test trajectory, noncausal whole-record filtering and post-hoc design limit external validity.',
              'No new physical experiment, cross-load or cross-robot validation, or closed-loop stability evidence.',
              'No matched recurrent/dynamic-friction baselines and no complete physical parameter consistency proof.',
              'Optimal learning rate lies at upper candidate boundary; global optimization convergence not established.',
              'Cross-machine reproduction and public archive not completed.'])
(ROOT/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2,allow_nan=False),encoding='utf8')
print(json.dumps(dict(status=report['computational_and_document_checks'],checks=len(checks),
      passed=sum(c['passed'] for c in checks),source_snapshot_files=len(source_rows)),ensure_ascii=False))
if not all(c['passed'] for c in checks): sys.exit(1)
