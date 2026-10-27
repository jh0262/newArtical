from pathlib import Path
import csv,hashlib,json,datetime
root=Path(__file__).resolve().parents[1]
pr=root/'provenance'
cfg=json.loads((pr/'study_config.json').read_text(encoding='utf-8'))
assert cfg['N']==100 and cfg['generations']==500 and len(cfg['seeds'])==20
assert len(cfg['problems'])==8 and len(cfg['algorithms'])==13
assert json.loads((pr/'preflight_completed.json').read_text(encoding='utf-8'))['status']=='passed'
paths=sorted(list((root/'src').glob('*.m'))+list((root/'vendor').rglob('*.m'))+list((root/'vendor').rglob('*.mat'))+[root/'README.md',root/'ec_setup.m',root/'ec_worker.m',pr/'study_config.json'])
files=[{'path':p.relative_to(root).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths]
stamp=datetime.datetime.now(datetime.timezone.utc).isoformat()
manifest={'version':'v1','frozen_at':stamp,'git_state':'workspace is not a git repository; content hashes are authoritative','files':files}
dest=pr/'code_manifest.json'
if dest.exists():
    previous=json.loads(dest.read_text(encoding='utf-8'))
    if previous['files']!=files: raise RuntimeError('Frozen identity changed. Register an amendment/new version before overwriting.')
else: dest.write_text(json.dumps(manifest,indent=2),encoding='utf-8')
with (pr/'experiment_matrix.csv').open('w',newline='',encoding='utf-8') as f:
    w=csv.writer(f); w.writerow(['row_id','problem','D','algorithm','seed','initial_seed','N','generations','FE','A','B','C','adaptive','shuffle','hypotheses'])
    row=0
    for pi,p in enumerate(cfg['problems'],1):
        for seed in cfg['seeds']:
            for a in cfg['algorithms']:
                row+=1
                w.writerow([row,p['name'],p['D'],a['name'],seed,100000+pi*1000+seed,100,500,50100,a['A'],a['B'],a['C'],a['adaptive'],a['shuffle'],'H-A|H-B|H-C|H-ABC'])
assert row==2080
print(f'Frozen {len(files)} source/config files; {row} runs; {row*50100:,} optimization evaluations')
