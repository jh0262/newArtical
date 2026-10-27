"""Copy only required, unmodified PlatEMO sources; record content hashes."""
from pathlib import Path
import hashlib,json,shutil,datetime
root=Path(__file__).resolve().parents[1]
src=root.parent/'TA_TPDE_Benchmark_V0_1/external/PlatEMO-v4.15'
dest=root/'vendor/PlatEMO'
parts=['README.md','PlatEMO/Algorithms/ALGORITHM.m','PlatEMO/Algorithms/Utility functions',
       'PlatEMO/Algorithms/Multi-objective optimization/NSGA-II',
       'PlatEMO/Algorithms/Multi-objective optimization/SPEA2',
       'PlatEMO/Algorithms/Multi-objective optimization/MOEA-D',
       'PlatEMO/Problems/PROBLEM.m','PlatEMO/Problems/SOLUTION.m',
       'PlatEMO/Problems/Multi-objective optimization/ZDT',
       'PlatEMO/Problems/Multi-objective optimization/DTLZ']
records=[]
for part in parts:
    item=src/part
    if not item.exists(): raise FileNotFoundError(item)
    files=sorted(item.rglob('*')) if item.is_dir() else [item]
    for p in files:
        if not p.is_file(): continue
        rel=p.relative_to(src); target=dest/rel
        digest=hashlib.sha256(p.read_bytes()).hexdigest()
        target.parent.mkdir(parents=True,exist_ok=True)
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest()!=digest:
            raise RuntimeError(f'Refuse to overwrite different vendor file: {target}')
        shutil.copy2(p,target)
        records.append({'path':str(rel).replace('\\','/'),'sha256':digest})
out=root/'provenance'; out.mkdir(exist_ok=True)
(out/'vendor_manifest.json').write_text(json.dumps({'source':str(src),'source_label_untrusted':'folder v4.15; README headline 4.14','copied_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'files':records},ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Copied and hashed {len(records)} unchanged vendor files')
