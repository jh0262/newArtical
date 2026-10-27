"""Recompute prior active-clipping control summaries; do not retrain."""
from pathlib import Path
import csv,json,hashlib,math
R=Path(__file__).resolve().parent;P=R.parent/'jme_review_20260930_round4';D=P/'optimizer_verification'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
done=json.loads((D/'verification.json').read_text(encoding='utf-8'))
assert sha(P/'adam_equivalence.py')==done['script_sha256']
rows=list(csv.DictReader((D/'per_step.csv').open(encoding='utf-8-sig')))
out=[]
for case in done['cases']:
 rs=[v for v in rows if v['case']==case['case']];assert len(rs)==200
 for source,key in [('max_output_difference','max_normalized_output_difference'),('effective_parameter_difference','max_effective_parameter_difference'),('loss_difference','max_loss_difference')]:
  assert math.isclose(max(float(v[source]) for v in rs),case[key],rel_tol=1e-14,abs_tol=1e-15)
 assert sum(float(v['wide_unclipped_grad_norm'])>100 for v in rs)==case['clipped_steps']
 assert math.isclose(float(rs[-1]['max_output_difference']),case['final_batch_output_difference'],rel_tol=1e-14,abs_tol=1e-15)
 out.append(case)
report={'status':'pass','scope':'Saved local 200-step optimizer-path control, not full predictive experiment. No new training.','cases':out,'inputs':{str(p):sha(p) for p in [P/'adam_equivalence.py',D/'verification.json',D/'summary.csv',D/'per_step.csv']}}
(R/'analysis/clipping_control_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print('Four cases, 800 saved steps checked; no retraining.')
