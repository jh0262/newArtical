from pathlib import Path
import hashlib, json, shutil, csv, statistics
R=Path(__file__).resolve().parents[1]
S=R.parent/'MO_PACPO_参数作用机理_第二轮_20261026'
for d in ['code/reference','tests/reference','results/screen','results/confirm','data','audit','failures','figures']:
    (R/d).mkdir(parents=True,exist_ok=True)
for name in ['Core','Mechanism','Pulse','Tape','Front','Theory']:
    src=S/'code'/f'DM{name}.m'
    (R/'code'/f'ER{name}.m').write_text(src.read_text(encoding='utf-8').replace('DM','ER'),encoding='utf-8')
shutil.copy2(S/'code/reference/PPaPaRModel.m',R/'code/reference/PPaPaRModel.m')
for f in (S/'tests/reference').glob('*.m'): shutil.copy2(f,R/'tests/reference'/f.name)
(R/'tests/MechanismContracts.m').write_text((S/'tests/MechanismContracts.m').read_text(encoding='utf-8').replace('DM','ER'),encoding='utf-8')
rows=list(csv.DictReader((S/'data/main_runs.csv').open(encoding='utf-8')))
base=[float(x['SearchHV']) for x in rows if x['Problem']=='PPAR' and x['Variant']=='B']
target=.99*statistics.median(base)
(R/'data/targets.json').write_text(json.dumps({'engineering_HV_target':target,'definition':'0.99 * median of round2 main B search HV (30 prior seeds)','source':str(S/'data/main_runs.csv'),'prior_baseline_median':statistics.median(base)},indent=2),encoding='utf-8')
records=[]
for f in S.rglob('*'):
    if f.is_file() and not f.is_symlink():
        records.append({'path':str(f),'bytes':f.stat().st_size,'sha256':hashlib.file_digest(f.open('rb'),'sha256').hexdigest()})
(R/'audit/preserved_round2_manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'new_root':str(R),'preserved_files':len(records),'target':target},ensure_ascii=False))
