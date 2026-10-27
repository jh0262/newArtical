"""Dispatch only preassigned compiled cases, with graceful stop support."""
from pathlib import Path
import sys,json,time,subprocess
R=Path(__file__).resolve().parent;D=R/'external_validation_compiled';D.mkdir(exist_ok=True)
assert json.loads((R/'compiled_execution/verification.json').read_text())['status']=='pass'
assert json.loads((R/'external_execution_modes.json').read_text())['selection']=={'capacity_control':'external_validation','history':'external_validation_compiled','history_removed':'external_validation_compiled'}
pending=[(m,s) for m in ['history','history_removed'] for s in [9,19,29]];active=[];finished=[]
def eager_remaining():
 n=0
 for s in [9,19,29]:
  try:done=json.loads((R/'external_validation'/f'completion_capacity_control_{s}.json').read_text())['status']=='complete'
  except (FileNotFoundError,json.JSONDecodeError):done=False
  n+=not done
 return n
while pending or active:
 for j in active[:]:
  code=j['process'].poll()
  if code is not None:j['log'].close();finished.append(dict(model=j['model'],seed=j['seed'],exit_code=code));active.remove(j);print('FINISHED',finished[-1],flush=True)
 remaining=eager_remaining()
 # Original-test workers finished; 24 logical CPUs and >40 GiB free on this host.
 # Each integration process remains single-threaded with unchanged arithmetic.
 while pending and len(active)+remaining<6 and not (D/'stop_after_active.flag').exists():
  m,s=pending.pop(0);log=open(D/f'execution_{m}_{s}.log','w',encoding='utf-8');process=subprocess.Popen([sys.executable,'-X','utf8',str(R/'run_external_compiled.py'),'--model',m,'--seed',str(s)],cwd=R,stdout=log,stderr=subprocess.STDOUT);active.append(dict(model=m,seed=s,process=process,log=log));print('STARTED',m,s,'pid',process.pid,'eager_remaining',remaining,flush=True)
 state=dict(pending=[dict(model=m,seed=s) for m,s in pending],active=[dict(model=j['model'],seed=j['seed'],pid=j['process'].pid) for j in active],finished=finished,eager_remaining=remaining)
 (D/'scheduler_state.json').write_text(json.dumps(state,indent=2),encoding='utf-8')
 if (D/'stop_after_active.flag').exists() and not active:print('STOP FLAG: queued work retained',flush=True);sys.exit(2)
 if pending or active:time.sleep(10)
print('COMPILED SCHEDULER COMPLETE',finished,flush=True)
if any(j['exit_code']!=0 for j in finished):sys.exit(1)
