"""Bounded parallel HTTP range retrieval of the public archive; publisher checksum required."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import urllib.request,hashlib,json,time
R=Path(__file__).resolve().parent;D=R/'external_data';C=D/'download_chunks';C.mkdir(exist_ok=True)
url='https://fdm-fallback.uni-kl.de/TUK/FB/MV/WSKL/0001/Robot_Identification_Benchmark_With_Raw_Data.rar'
size=227384738;chunk=4*1024*1024;out=D/'Robot_Identification_Benchmark_With_Raw_Data.rar';start=time.time()
assert not out.exists(),'Preserve existing archive'
expected=(D/'publisher.md5').read_text().split()[0]
def get(i):
 a=i*chunk;b=min(size,(i+1)*chunk)-1;p=C/f'{i:03d}.bin'
 if p.exists():assert p.stat().st_size==b-a+1;return i,p
 request=urllib.request.Request(url,headers={'Range':f'bytes={a}-{b}'})
 with urllib.request.urlopen(request,timeout=40) as r:
  assert r.status==206 and r.headers['Content-Range']==f'bytes {a}-{b}/{size}'
  body=r.read();assert len(body)==b-a+1
 p.write_bytes(body);return i,p
n=(size+chunk-1)//chunk;parts={}
with ThreadPoolExecutor(max_workers=4) as pool:
 for f in as_completed([pool.submit(get,i) for i in range(n)]):
  i,p=f.result();parts[i]=p
  if len(parts)%4==0:print('completed_chunks',len(parts),'of',n,'seconds',round(time.time()-start,1),flush=True)
target=D/'range_assembled.rar.part';assert not target.exists()
with target.open('wb') as f:
 for i in range(n):f.write(parts[i].read_bytes())
assert target.stat().st_size==size
assert hashlib.md5(target.read_bytes()).hexdigest()==expected,'Publisher MD5 mismatch'
target.rename(out)
(D/'retrieval.json').write_text(json.dumps(dict(url=url,publisher_md5=expected,md5_verified=True,size=size,sha256=hashlib.sha256(out.read_bytes()).hexdigest(),method='HTTP206 4MiB ranges, four connections, exact Content-Range checks, official MD5',seconds=time.time()-start,script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),acquired_at=time.strftime('%Y-%m-%dT%H:%M:%S%z')),indent=2),encoding='utf-8')
print('DOWNLOAD VERIFIED',out,flush=True)
