"""Refine every already-failed history window; preserve original failure labels."""
from pathlib import Path
import argparse,json,hashlib,time,io,traceback
from adaptive_integrator import R,REV,load,torch,np,dump,robot_rollout,algorithm_signature,core
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--seed',type=int,choices=[9,19],required=True);a=ap.parse_args()
 O=R/'failed_window_refinement';O.mkdir(exist_ok=True);cfg,data,cache,params,s=load();torch.set_num_threads(1);scale=torch.cat([s['qstd'],s['vstd']]);sq=s['qstd'].numpy()
 paths=[Path(__file__),R/'failed_window_refinement_protocol.md',R/'compiled_execution/verification.json',R/'external_validation/semantic_dependencies.json',R/'adaptive/inputs_seed9.json']
 expected={}
 for p in [R/'adaptive/inputs_seed9.json',R/'compiled_execution/verification_inputs.json']:
  for k,v in json.loads(p.read_text()).items():
   if k in expected:assert expected[k]==v,k
   expected[k]=v
 for p,h in expected.items():assert sha(p)==h,p
 sem=json.loads((R/'external_validation/semantic_dependencies.json').read_text());assert {k:v.numpy().tolist() for k,v in s.items()}==sem['scalers']
 lo_p=R/f'adaptive/history_{a.seed}_loose.npz';hi_p=R/f'adaptive/history_{a.seed}_tight.npz';lo=np.load(lo_p);hi=np.load(hi_p);assert np.array_equal(lo['starts'],hi['starts'])
 dif=abs((lo['prediction'][:,:,:6]-hi['prediction'][:,:,:6])/sq);ii=np.where(dif.max((1,2))>1e-3)[0];starts=hi['starts'][ii]
 assert starts.tolist()==({9:[11982],19:[757,3357,3382,4632,11982,13532,13582]}[a.seed])
 cv=json.loads((R/'compiled_execution/verification.json').read_text());assert cv['status']=='pass' and cv['algorithm_signature']==algorithm_signature()
 row=next(x for x in cv['models'] if x['model']=='history' and x['seed']==a.seed);graph=Path(row['path']);assert sha(graph)==row['sha256'];rhs=torch.jit.load(io.BytesIO(graph.read_bytes())).eval()
 paths +=[lo_p,hi_p,graph,REV/f'evaluations/history_{a.seed}/predictions.npz']
 if a.seed==9:paths +=[R/'failed_origin_check/dp_refined.npz',R/'failed_origin_check/dp_stats.json',R/'failed_origin_check/inputs.json']
 expected.update({str(p):sha(p) for p in paths});dump(O/f'inputs_{a.seed}.json',expected)
 preds=[];info=[]
 for name,rtol,af in [('fine',1e-10,1e-12),('finer',1e-12,1e-14)]:
  print('REFINE',a.seed,name,starts.tolist(),flush=True)
  if a.seed==9 and name=='fine':
   saved=np.load(R/'failed_origin_check/dp_refined.npz');assert np.array_equal(saved['starts'],starts);pred=saved['prediction'];stats=json.loads((R/'failed_origin_check/dp_stats.json').read_text());mode='retained eager full-origin DP result'
  else:pred,stats=robot_rollout(rhs,data['test'],cfg,starts,scale,rtol,af);mode='verified compiled RHS'
  path=O/f'history_{a.seed}_{name}.npz';np.savez_compressed(path,prediction=pred,starts=starts);dump(O/f'history_{a.seed}_{name}_stats.json',dict(**stats,implementation=mode,rtol=rtol,atol_factor=af));preds.append(pred);info.append(dict(name=name,sha256=sha(path),implementation=mode))
 z=np.load(REV/f'evaluations/history_{a.seed}/predictions.npz');checks=[]
 for j,start in enumerate(starts):
  mx=float(abs((preds[1][j,:,:6]-preds[0][j,:,:6])/sq).max());deltas={}
  for label,mask in [('all',None),('low_speed',z['low_speed_mask'][ii[j]:ii[j]+1]),('reversal',z['reversal_mask'][ii[j]:ii[j]+1])]:deltas[label]=core.metric(preds[1][j:j+1,:,:6],preds[0][j:j+1,:,:6],sq,mask)['nrmse']
  checks.append(dict(start=int(start),max_normalized_position_difference=mx,difference_nrmse=deltas,refinement_consistency_pass=mx<=1e-3 and max(x for x in deltas.values() if x is not None)<=1e-4,original_failure_retained=True))
 for p,h in expected.items():assert sha(p)==h,p
 dump(O/f'completion_{a.seed}.json',dict(status='complete',seed=a.seed,origins=starts.tolist(),cases=info,checks=checks,input_hashes_unchanged=True,scope='All previously failed windows for this seed only; no main-table replacement, no strict global convergence claim'))
 print('REFINEMENT COMPLETE',a.seed,checks,flush=True)
if __name__=='__main__':
 try:main()
 except Exception:
  o=R/'failed_window_refinement';o.mkdir(exist_ok=True);(o/('failure_'+'_'.join(__import__('sys').argv[1:]).replace('--','')+'.txt')).write_text(traceback.format_exc(),encoding='utf-8');raise
