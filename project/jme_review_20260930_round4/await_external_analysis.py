"""One-shot local completion gate for the currently running confirmation cases."""
from pathlib import Path
import json,time,subprocess,sys
R=Path(__file__).resolve().parent;previous=None;started=time.time()
while time.time()-started<7200:
 states=[]
 for model in ['capacity_control','history','history_removed']:
  base=R/('external_validation' if model=='capacity_control' else 'external_validation_compiled')
  for seed in [9,19,29]:
   p=base/f'completion_{model}_{seed}.json'
   try:state=json.loads(p.read_text())['status'] if p.exists() else 'absent'
   except json.JSONDecodeError:state='writing'
   states.append((model,seed,state))
 if states!=previous:print('COMPLETION',states,flush=True);previous=states
 if all(v[2]=='complete' for v in states):
  for script in ['analyze_external.py','summarize_local_sensitivity.py','assemble_adaptive_results.py','extend_manuscript_external.py','apply_journal_format.py','condense_manuscript.py','render_first_five.py','render_adaptive_figures.py','support/audit_results.py']:
   print('BUILD',script,flush=True);subprocess.run([sys.executable,'-X','utf8',str(R/script)],cwd=R,check=True)
  print('CONFIRMATION ASSEMBLY COMPLETE',flush=True);break
 time.sleep(15)
else:raise TimeoutError('Existing confirmation workers did not complete in two hours; no partial assembly')
