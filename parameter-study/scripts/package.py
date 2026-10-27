from pathlib import Path
import json, hashlib, zipfile, shutil, sys
R=Path(__file__).resolve().parents[1]
def selected_files():
    selected=[]
    for name in ['code','scripts','tests','data','figures','audit']:
        for p in (R/name).rglob('*'):
            if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc':selected.append(p)
    for p in R.iterdir():
        if p.is_file() and p.suffix in ['.m','.md','.json','.mat']:selected.append(p)
    # Include the first confirmation baseline trajectory for each problem.
    for problem,seed in [('PPAR',951001),('DTLZ3',952001)]:
        for suffix in ['.mat','_fine.mat','_status.json']:
            p=R/'results/confirm'/f'{problem}_B_{seed}{suffix}'
            if p.is_file():selected.append(p)
    return sorted(set(p for p in selected if p.name not in ['package_contents.json','package_audit.json']))

def main():
    selected=selected_files()
    if len(sys.argv)==3 and sys.argv[1]=='--stage':
        dest=Path(sys.argv[2]).resolve();assert not dest.exists(),'Use a new directory for a clean reproduction.'
        dest.mkdir(parents=True)
        for p in selected:
            target=dest/p.relative_to(R);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
        print(json.dumps({'stage':str(dest),'files':len(selected)},ensure_ascii=False));return
    assert len(sys.argv)==1,'Use no arguments or --stage NEW_DIRECTORY'
    archive=R/'机构优先参数测试_精简复现包.zip';assert not archive.exists(),'Preserve the existing package; choose a new version.'
    manifest=[{'path':p.relative_to(R).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in selected]
    (R/'audit/package_contents.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8');selected.append(R/'audit/package_contents.json')
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted(set(selected)):z.write(p,p.relative_to(R).as_posix())
    assert archive.stat().st_size<120_000_000
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for rec in manifest:assert hashlib.sha256(z.read(rec['path'])).hexdigest()==rec['sha256']
    audit={'status':'pass','file':str(archive),'bytes':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'limit_bytes':120_000_000,'entries':len(set(selected)),'scope':'all derived data, statistics, plots, scripts, protocol, and two baseline trajectories; all other raw trajectories preserved locally'}
    (R/'audit/package_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(audit,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
