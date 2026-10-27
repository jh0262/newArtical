"""Sidecar source audit; timestamps reflect when performed, not a pre-run gate."""
from pathlib import Path
import sys,json,hashlib,datetime
from adaptive_integrator import R,load
phase=sys.argv[1];assert phase in ['during','end']
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
sources=[R/'adaptive/inputs_seed9.json',R/'compiled_execution/verification_inputs.json']
expected={}
for p in sources:
 for k,v in json.loads(p.read_text()).items():
  if k in expected:assert expected[k]==v,k
  expected[k]=v
for k,v in expected.items():assert sha(k)==v,k
cfg,data,cache,params,s=load();semantic=json.loads((R/'external_validation/semantic_dependencies.json').read_text())
assert {k:v.numpy().tolist() for k,v in s.items()}==semantic['scalers']
o=dict(status='pass',phase=phase,checked_at=datetime.datetime.now().astimezone().isoformat(),timing='Sidecar performed during/after execution, not claimed as part of original worker end guard',reference_manifests={str(p):sha(p) for p in sources},hashes=expected,scalers_equal=True,scope='Prepared original data, config, cache, weights, model implementations and scalers compared against earlier frozen source records')
(R/'failed_origin_check_compiled'/f'input_sidecar_{phase}.json').write_text(json.dumps(o,ensure_ascii=False,indent=2),encoding='utf-8');print('PASS',phase,len(expected),'source hashes and scalers')
