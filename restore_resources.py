from pathlib import Path
from zipfile import ZipFile
from urllib.request import urlopen
import hashlib,json,sys,shutil,gzip
root=Path(__file__).resolve().parent
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()
for row in json.loads((root/'ARCHIVE_MANIFEST.json').read_text(encoding='utf-8')):
    p=root/row['path']
    if not p.exists():
        if '--download' not in sys.argv:raise SystemExit('Missing '+row['path']+'; rerun with --download')
        p.parent.mkdir(parents=True,exist_ok=True)
        temp=p.with_suffix('.download')
        with urlopen(row['url'],timeout=180) as remote,temp.open('wb') as f:shutil.copyfileobj(remote,f)
        assert temp.stat().st_size==row['bytes'] and digest(temp)==row['sha256'],row['path']
        temp.replace(p)
    assert p.stat().st_size==row['bytes'] and digest(p)==row['sha256'],row['path']
manifest_path=root/'RESOURCE_MANIFEST.json'
if manifest_path.exists():manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
else:
    with gzip.open(root/'RESOURCE_MANIFEST.json.gz','rt',encoding='utf-8') as f:manifest=json.load(f)
archives={}
for row in manifest:
    target=(root/row['path']).resolve();assert target.is_relative_to(root.resolve())
    if row.get('bundle'):
        if row['bundle'] not in archives:archives[row['bundle']]=ZipFile(root/row['bundle'])
        data=archives[row['bundle']].read(row['path'])
    else:data=target.read_bytes()
    assert hashlib.sha256(data).hexdigest()==row['sha256'],row['path']
    if target.exists():assert target.read_bytes()==data,'Refusing to overwrite changed file: '+row['path']
    else:target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
for z in archives.values():z.close()
print('Verified/restored',len(manifest),'original resource files. No experiments were run.')
