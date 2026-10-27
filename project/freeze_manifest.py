"""Freeze/check formal experiment input hashes. Does not authorize a run."""
import argparse
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
DEST=ROOT/'provenance/formal_manifest.json'

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser(); group=ap.add_mutually_exclusive_group(required=True)
    group.add_argument('--freeze',action='store_true'); group.add_argument('--check',action='store_true'); a=ap.parse_args()
    if a.freeze:
        assert not DEST.exists(), 'Existing manifest preserved; audit changes before a new version.'
        files=[ROOT/'config.json',ROOT/'MODEL_CONTRACT.md',ROOT/'ALGORITHM_PROTOCOL.md',ROOT/'freeze_manifest.py',
               ROOT/'literature/catalog_btkv.csv',ROOT/'literature/catalog_inertia.csv']+sorted((ROOT/'matlab').rglob('*.m'))
        data={'version':'formal-plan-v01','compute_authorization':'tracked in native ARIS run record; manifest does not authorize computation',
              'files':[{'path':p.relative_to(ROOT).as_posix(),'sha256':digest(p)} for p in files]}
        DEST.parent.mkdir(exist_ok=True)
        DEST.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    data=json.loads(DEST.read_text(encoding='utf-8'))
    for item in data['files']:
        p=ROOT/item['path']; assert p.is_file() and digest(p)==item['sha256'], f'Changed: {p}'
    print(f'PASS: {len(data["files"])} frozen inputs; compute authorization is separate.')

if __name__=='__main__': main()
