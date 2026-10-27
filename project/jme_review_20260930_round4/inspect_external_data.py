from pathlib import Path
import sys,json,hashlib
R=Path(__file__).resolve().parent;B=R.parent;D=R/'external_data';sys.path.insert(0,str(B));import bootstrap
import scipy.io as sio,numpy as np
files=sorted((D/'unpacked/raw_data').glob('*.mat'));assert len(files)==12
original=Path('F:/暑假原始资料/05_evidence/20260928_robot_paper_selection/resources/common_data__py_recording_2021_12_15_20H_45M.mat')
old=sio.loadmat(original,simplify_cells=True);same=next(p for p in files if p.name=='recording_2021_12_15_20H_45M.mat');raw=sio.loadmat(same,simplify_cells=True)
fields=['q_mot_meas','q_se_meas','qd_mot_meas','qd_se_meas','tau_meas','tau_fb_meas','q_ref','qd_ref','tau_ref_ff','time']
equivalence={k:dict(shape=list(raw[k].shape),exact_equal=bool(np.array_equal(raw[k],old['z'][k])),max_abs_difference=float(np.max(np.abs(raw[k]-old['z'][k])))) for k in fields}
assert all(v['exact_equal'] for v in equivalence.values()),'The raw records differ; do not infer mapping'
q=np.concatenate([raw['q_se_meas'][:3],raw['q_mot_meas'][3:]],axis=0).T;u=raw['tau_meas'].T;mapping=[]
for i,real in enumerate(old['realizations']):
 for j,period in enumerate(real['periods']):
  uq=period['u_data_V'];yq=period['y_data_V'][:,:6]
  candidates=np.flatnonzero(np.all(u==uq[0],axis=1));hits=[]
  for k in candidates:
   if k+len(uq)<=len(u) and np.array_equal(u[k:k+len(uq)],uq) and np.array_equal(q[k:k+len(uq)],yq):hits.append(int(k))
  assert len(hits)==1,(i,j,hits)
  mapping.append(dict(realization=i,period=j,start=hits[0],length=len(uq),exact_q_u_match=True))
starts=[r['start'] for r in mapping if r['period']==0];references=[];original_refs=[raw['q_ref'][:,i:i+15000].T for i in starts];catalog=[]
for p in files:
 z=sio.loadmat(p,simplify_cells=True);shape=z['tau_meas'].shape;dt=np.diff(z['time']);ok=bool(z['recording_ok']) and shape[0]==6 and all(np.isfinite(z[k]).all() for k in fields)
 assert ok and np.max(abs(dt-.004))<1e-9,p
 assert all(i+15000<=shape[1] for i in starts),p
 if p==same:continue
 for j,k in enumerate(starts):
  ref=z['q_ref'][:,k:k+15000].T;norm=np.linalg.norm(ref-ref.mean(0));deltas=[float(np.linalg.norm(ref-x)/max(norm,1e-12)) for x in original_refs+references]
  duplicate=min(deltas)<=1e-6
  catalog.append(dict(file=p.name,realization=j,start=k,length=15000,recording_ok=True,dt=.004,sha256=hashlib.sha256(p.read_bytes()).hexdigest(),reference_nearest_relative_difference=min(deltas),eligible=not duplicate,payload_field_present=any('load' in k.lower() or 'mass' in k.lower() for k in z)))
  if not duplicate:references.append(ref)
result=dict(status='pass',raw_original_equivalence=equivalence,period_mapping=mapping,eligibility=catalog,new_eligible_trajectories=sum(r['eligible'] for r in catalog),excluded_original_file=same.name,protocol_sha256=hashlib.sha256((R/'external_validation_protocol.md').read_bytes()).hexdigest(),script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
(D/'mapping_and_eligibility.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(dict(mapping=mapping,eligible=result['new_eligible_trajectories'],minimum_new_reference_difference=min(r['reference_nearest_relative_difference'] for r in catalog),payload_field_present=any(r['payload_field_present'] for r in catalog)),ensure_ascii=False))
