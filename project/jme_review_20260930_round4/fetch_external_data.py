from pathlib import Path
import urllib.request,hashlib,json,time
R=Path(__file__).resolve().parent;D=R/'external_data';D.mkdir(exist_ok=True)
url='https://fdm-fallback.uni-kl.de/TUK/FB/MV/WSKL/0001/Robot_Identification_Benchmark_With_Raw_Data.rar'
out=D/'Robot_Identification_Benchmark_With_Raw_Data.rar';partial=out.with_suffix('.rar.part')
expected=urllib.request.urlopen(url+'.md5',timeout=30).read().decode().strip();md5=expected.split()[0]
(D/'publisher.md5').write_text(expected+'\n',encoding='utf-8')
if not out.exists():
 assert not partial.exists(),'Do not overwrite incomplete retrieval silently'
 start=time.time();total=0;last=0
 with urllib.request.urlopen(url,timeout=60) as response,partial.open('wb') as f:
  size=int(response.headers['Content-Length'])
  while chunk:=response.read(1024*1024):
   f.write(chunk);total+=len(chunk)
   if total-last>=32*1024*1024:print('downloaded_MB',round(total/1e6,1),'seconds',round(time.time()-start,1),flush=True);last=total
 assert total==size,(total,size)
 assert hashlib.md5(partial.read_bytes()).hexdigest()==md5,'Publisher MD5 mismatch'
 partial.rename(out)
assert hashlib.md5(out.read_bytes()).hexdigest()==md5
(D/'retrieval.json').write_text(json.dumps(dict(url=url,source='official dataset repository; DOI10.26204/data/5',publisher_md5=md5,md5_verified=True,size=out.stat().st_size,sha256=hashlib.sha256(out.read_bytes()).hexdigest(),acquired_at=time.strftime('%Y-%m-%dT%H:%M:%S%z')),indent=2),encoding='utf-8')
print('DOWNLOAD VERIFIED',out,flush=True)
