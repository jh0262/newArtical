"""Package both preserved stages and the new follow-up without overwriting."""
from pathlib import Path
import hashlib,json,zipfile

ROOT=Path(__file__).resolve().parent;BASE=ROOT.parent;PROJECT=BASE.parent
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def main():
    manifest=json.loads((ROOT/'provenance/delivery_manifest.json').read_text(encoding='utf-8'))
    for row in manifest['files']:assert sha(BASE/row['path'])==row['sha256']
    dest=PROJECT/'10_dynamic_mode_followup_20261011.zip'
    assert not dest.exists(),'Existing archive must be preserved; choose a new version.'
    paths=sorted(p for p in BASE.rglob('*') if p.is_file() and '__pycache__' not in p.parts)
    with zipfile.ZipFile(dest,'x',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in paths:z.write(p,p.relative_to(PROJECT))
    with zipfile.ZipFile(dest) as z:
        assert z.testzip() is None
        assert len(z.namelist())==len(paths)
    record=dict(date='2026-10-11',archive=str(dest),files=len(paths),bytes=dest.stat().st_size,sha256=sha(dest),CRC='PASS',content='Preserved original dynamic study plus 120-run full-history follow-up; native-state completion snapshots included.')
    dest.with_suffix('.manifest.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(record,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
