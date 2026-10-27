from pathlib import Path
from zipfile import ZipFile
import hashlib,json
root=Path(__file__).resolve().parent
manifest=json.loads((root/'RESOURCE_MANIFEST.json').read_text(encoding='utf-8'))
archives={}
for row in manifest:
    target=root/row['path']
    if row.get('bundle'):
        if row['bundle'] not in archives: archives[row['bundle']]=ZipFile(root/row['bundle'])
        archive=archives[row['bundle']]
        data=archive.read(row['path'])
    else:
        data=target.read_bytes()
    assert hashlib.sha256(data).hexdigest()==row['sha256'], row['path']
    if target.exists():
        assert target.read_bytes()==data, 'Refusing to overwrite changed file: '+row['path']
    else:
        target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
for archive in archives.values():archive.close()
print('Verified/restored',len(manifest),'original resource files. No experiments were run.')
