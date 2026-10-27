"""Bound concurrent confirmation jobs while original-test workers finish."""
from pathlib import Path
import sys,json,time,subprocess
R=Path(__file__).resolve().parent;D=R/'external_validation'
pending=[(m,s) for m in ['capacity_control','history','history_removed'] for s in [9,19,29]];active=[];finished=[]
while pending or active:
 for job in active[:]:
  code=job['process'].poll()
  if code is not None:
   job['log'].close();finished.append(dict(model=job['model'],seed=job['seed'],exit_code=code));active.remove(job);print('FINISHED',finished[-1],flush=True)
 original_remaining=0
 for model in ['history','history_removed']:
  for seed in [9,19,29]:
   path=R/'adaptive'/f'case_execution_{model}_{seed}.json'
   try:done=json.loads(path.read_text())['status']=='complete'
   except (FileNotFoundError,json.JSONDecodeError):done=False
   original_remaining+=not done
 while pending and len(active)<3 and original_remaining+len(active)<4:
  model,seed=pending.pop(0);log=open(D/f'execution_{model}_{seed}.log','w',encoding='utf-8');cmd=[sys.executable,'-X','utf8',str(R/'run_external_case.py'),'--model',model,'--seed',str(seed)]
  process=subprocess.Popen(cmd,cwd=R,stdout=log,stderr=subprocess.STDOUT);active.append(dict(model=model,seed=seed,process=process,log=log));print('STARTED',model,seed,'pid',process.pid,'original_remaining',original_remaining,flush=True)
 state=dict(pending=[dict(model=m,seed=s) for m,s in pending],active=[dict(model=j['model'],seed=j['seed'],pid=j['process'].pid) for j in active],finished=finished,original_remaining=original_remaining)
 (D/'scheduler_state.json').write_text(json.dumps(state,indent=2),encoding='utf-8')
 if pending or active:time.sleep(10)
print('SCHEDULER COMPLETE',finished,flush=True)
if any(j['exit_code']!=0 for j in finished):sys.exit(1)
