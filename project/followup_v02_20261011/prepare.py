"""Record explicit authorization; freeze or check isolated follow-up inputs."""
from pathlib import Path
import argparse, hashlib, json, shutil

ROOT=Path(__file__).resolve().parent
BASE=ROOT.parent
STATE=BASE.parent/'.aris/runs/ball-screw-earclip-dynamics-20260921.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--authorize',action='store_true');ap.add_argument('--freeze',action='store_true');ap.add_argument('--check',action='store_true');a=ap.parse_args()
    prov=ROOT/'provenance';prov.mkdir(exist_ok=True)
    old=json.loads((BASE/'provenance/formal_manifest.json').read_text(encoding='utf-8'))
    for item in old['files']:assert sha(BASE/item['path'])==item['sha256'],item['path']
    if a.authorize:
        assert not (prov/'authorization.json').exists()
        shutil.copy2(STATE,prov/'aris_before_followup.json')
        write(prov/'authorization.json',dict(date='2026-10-11',authorized=True,user_message='可以，按上述方案和预算继续实验。',runs=120,max_FE=3847680,workers=1,max_seconds=1200,scope='Implementation, zero-FE checks, freeze, 120-run protocol, saved-result analysis; no added optimization batch.'))
        state=json.loads(STATE.read_text(encoding='utf-8'));state['updated']='2026-10-11'
        for phase in state['phases']:
            if phase['phase']=='followup-protocol':phase.update(budget_authorized=True,implementation_started=True,status='running')
        state['followup_authorization']=json.loads((prov/'authorization.json').read_text(encoding='utf-8'))
        state['next_action']='Implement, verify, freeze and execute the approved 120-run follow-up without repeated authorization.'
        write(STATE,state)
        shutil.copy2(BASE/'diagnostics_20261011/FOLLOWUP_PROTOCOL.md',ROOT/'APPROVED_PROTOCOL.md')
    if a.freeze:
        assert json.loads((prov/'authorization.json').read_text(encoding='utf-8'))['authorized']
        assert json.loads((prov/'preflight.json').read_text(encoding='utf-8'))['status']=='PASS'
        assert not (prov/'manifest.json').exists()
        paths=list((ROOT/'matlab').glob('v2_*.m'))+[ROOT/'prepare.py',ROOT/'APPROVED_PROTOCOL.md',ROOT/'IMPLEMENTATION_NOTES.md',prov/'authorization.json',prov/'preflight.json']
        write(prov/'manifest.json',dict(version='followup-v02',date='2026-10-11',source_formal_manifest_sha256=sha(BASE/'provenance/formal_manifest.json'),files=[dict(path=p.relative_to(ROOT).as_posix(),sha256=sha(p)) for p in sorted(paths)]))
    if a.check:
        m=json.loads((prov/'manifest.json').read_text(encoding='utf-8'))
        assert sha(BASE/'provenance/formal_manifest.json')==m['source_formal_manifest_sha256']
        for item in m['files']:assert sha(ROOT/item['path'])==item['sha256'],item['path']
        print(f"PASS {len(old['files'])} original inputs and {len(m['files'])} follow-up inputs")
    elif a.authorize:print('Recorded user authorization: 120 runs, 3847680 FE, 1200 seconds, one worker.')
    elif a.freeze:print('Frozen follow-up protocol and implementation.')

if __name__=='__main__':main()
