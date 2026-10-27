"""Independent sidecar audit of the original, non-reassigned input manifest."""
from pathlib import Path
import json,sys,datetime,argparse
from train_controlled import R,B,sha,dump,load
sys.path.insert(0,str(B/'jme_review_20260930_round4'))
import adaptive_integrator as ai
def main(stage):
 load();old=B/'jme_review_20260930_round4/adaptive/implementation_checks.json';v=json.loads(old.read_text());assert v['status']=='pass' and v['algorithm_signature']==ai.algorithm_signature()
 rows=[]
 for p in sorted(R.glob('pointwise/inputs_initial.json'))+sorted(R.glob('rollout/*/inputs_initial.json')):
  inputs=json.loads(p.read_text());bad=[f for f,h in inputs.items() if sha(f)!=h];assert not bad,bad
  full=p.parent/'inputs.json';d=json.loads(full.read_text());bad=[f for f,h in d.items() if sha(f)!=h];assert not bad,bad
  overlap=set(inputs)&set(d);assert all(inputs[f]==d[f] for f in overlap)
  rows.append(dict(directory=str(p.parent),initial_manifest_sha256=sha(p),files_checked=len(inputs),full_manifest_sha256=sha(full),full_files_checked=len(d),original_inputs_unchanged=True,completed=(p.parent/'completion.json').exists()))
 out=R/'review';out.mkdir(exist_ok=True);dump(out/f'evaluation_input_guard_{stage}.json',dict(status='pass',checked_at=datetime.datetime.now().astimezone().isoformat(),stage=stage,verified_kernel_signature=ai.algorithm_signature(),prior_verification_sha256=sha(old),directories=rows,guard_sha256=sha(__file__)))
 print(stage,'PASS',len(rows),'directories')
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--stage',required=True);args=ap.parse_args();main(args.stage)
