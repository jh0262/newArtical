from pathlib import Path
import json,hashlib,csv,datetime
ROOT=Path(__file__).resolve().parents[1]
for d in ['raw','analysis','qa','figures','failures']: (ROOT/d).mkdir(exist_ok=True)
problems=[]
for i in range(1,27):
    pid=f'F{i:02d}' if i<=23 else ['WB','CB','PV'][i-24]
    budget=30030 if i<=13 else 15030 if i<=23 else 100040
    ids=[f'G{g}P{p}J{j}' for g in range(3) for p in range(2) for j in range(2 if pid=='PV' else 1)]+['CLASSIC_DE']
    problems.append(dict(id=pid,index=i,N=30 if i<=23 else 40,maxFE=budget,variants=ids,runs=30))
config=dict(version='PADE-FE-v4.0',workers=6,runs=30,seeds=list(range(1001,1031)),
            problems=problems,clock='consumed FE / total FE',cv_tolerance=0,
            primary_alpha=.05,pBestRate=.15,warmupRatio=.1,pulseEndRatio=.9,
            gamma=.25,betaCrit=2.8,stagnationLimit=15,rotation_threshold=.20,
            total_runs=sum(len(p['variants'])*30 for p in problems),
            total_search_FE=sum(len(p['variants'])*30*p['maxFE'] for p in problems))
(ROOT/'CONFIG.json').write_text(json.dumps(config,ensure_ascii=False,indent=2),encoding='utf-8')
rows=[]
for p in problems:
    pid=p['id'];j=int(pid=='PV');full=f'G2P1J{j}'
    for family,b in [('full_vs_parent','G0P0J0'),('full_vs_classic','CLASSIC_DE'),
                     ('spectral_scaling',f'G1P1J{j}'),('axis_with_pulse',f'G0P1J{j}'),
                     ('pulse_with_geometry',f'G2P0J{j}')]:
        a=f'G1P1J{j}' if family=='axis_with_pulse' else full
        rows.append(dict(family_id=family,a_id=a,b_id=b,problem_id=pid))
for g in range(3):
    for p in range(2):rows.append(dict(family_id='jitter_pressure_vessel',a_id=f'G{g}P{p}J1',b_id=f'G{g}P{p}J0',problem_id='PV'))
with (ROOT/'comparisons.csv').open('w',encoding='utf-8',newline='') as f:
    w=csv.DictWriter(f,fieldnames=['family_id','a_id','b_id','problem_id']);w.writeheader();w.writerows(rows)
orig=[]
for f in [*ROOT.parent.glob('*.m'),ROOT.parent/'PADE_Mechanical_Optimization_Full_Paper-v2.docx']:
    orig.append(dict(path=str(f),sha256=hashlib.sha256(f.read_bytes()).hexdigest()))
(ROOT/'INPUT_MANIFEST.json').write_text(json.dumps(orig,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:config[k] for k in ['total_runs','total_search_FE','workers']},ensure_ascii=False))
