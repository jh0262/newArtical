"""Interpret failed numerical-agreement cases in both normalized and physical units."""
from pathlib import Path
import json
from adaptive_integrator import R,REV,load,np,dump,write_csv
cfg,data,cache,params,s=load();scale=s['qstd'].numpy();rows=[];selection=[]
for seed in [9,19,29]:
 lo=np.load(R/f'adaptive/history_{seed}_loose.npz');hi=np.load(R/f'adaptive/history_{seed}_tight.npz');assert np.array_equal(lo['starts'],hi['starts'])
 delta=abs(hi['prediction'][:,:,:6]-lo['prediction'][:,:,:6]);norm=delta/scale;failed=np.where(norm.max((1,2))>1e-3)[0]
 for i in failed:
  step,joint=np.unravel_index(np.argmax(norm[i]),norm[i].shape);rows.append(dict(seed=seed,origin_index=int(i),start_sample=int(hi['starts'][i]),start_time_s=float(hi['starts'][i]*.004),prediction_step=int(step+1),joint=int(joint+1),max_normalized_position_difference=float(norm[i,step,joint]),position_difference_rad=float(delta[i,step,joint]),position_difference_degree=float(delta[i,step,joint]*180/np.pi)))
 if len(failed):
  i=int(np.argmax(norm.max((1,2))));step,joint=np.unravel_index(np.argmax(norm[i]),norm[i].shape)
  selection.append(dict(seed=seed,origin_index=i,start_sample=int(hi['starts'][i]),joint=int(joint+1),prediction_step=int(step+1)))
write_csv(R/'adaptive/local_sensitivity.csv',rows)
dump(R/'adaptive/local_sensitivity_summary.json',dict(failed_origin_initialization_pairs=len(rows),unique_origins=len(set(r['start_sample'] for r in rows)),selection_rule='For each failing initialization, select origin and joint attaining the maximum normalized loose/tight position difference. Diagnostic selection, not representative prediction performance.',figure_cases=selection,rows=rows))
print(json.dumps(rows,ensure_ascii=False))
