import bootstrap
import subprocess,os,sys,json,time,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parent
cfg=json.loads((ROOT/'config.json').read_text())
rows=[('physics',9,'a')]+[(m,s,'a') for s in cfg['seeds'] for m in cfg['models']]+[('velocity',9,'repeat')]
logs=ROOT/'suite_logs';logs.mkdir(exist_ok=True)
results=[]
for model,seed,attempt in rows:
    label=f'{model}_seed{seed}_{attempt}';dest=ROOT/'runs'/label
    if dest.exists():
        raise RuntimeError('Immutable run already exists: '+label)
    env=os.environ.copy();env['PYTHONHASHSEED']=str(seed)
    cmd=[sys.executable,'-u','-X','utf8',str(ROOT/'run_model.py'),'--model',model,'--seed',str(seed),'--attempt',attempt]
    print('START',label,flush=True);t=time.perf_counter()
    with (logs/(label+'.stdout.log')).open('w',encoding='utf-8') as out, (logs/(label+'.stderr.log')).open('w',encoding='utf-8') as err:
        code=subprocess.run(cmd,cwd=ROOT,env=env,stdout=out,stderr=err).returncode
    if dest.exists():
        shutil.copy2(logs/(label+'.stdout.log'),dest/'stdout.log');shutil.copy2(logs/(label+'.stderr.log'),dest/'stderr.log')
    results.append({'model':model,'seed':seed,'attempt':attempt,'exit_code':code,'elapsed_seconds':time.perf_counter()-t,'argv':cmd})
    (ROOT/'suite_status.json').write_text(json.dumps(results,indent=2))
    print('END',label,'exit',code,'seconds',round(time.perf_counter()-t),flush=True)
print('SUITE_FINISHED',len(results),'failures',sum(r['exit_code']!=0 for r in results),flush=True)
