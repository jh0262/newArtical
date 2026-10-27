from pathlib import Path
import urllib.request,concurrent.futures,json,hashlib,time
R=Path(__file__).resolve().parent;D=R/'primary_sources';D.mkdir(exist_ok=True)
sources=[('zhu2022','https://proceedings.mlr.press/v162/zhu22f.html','https://proceedings.mlr.press/v162/zhu22f/zhu22f.pdf'),('westny2024','https://proceedings.mlr.press/v235/westny24a.html','https://arxiv.org/pdf/2311.15890v3')]
def get(row):
 name,landing,pdf=row;out=dict(key=name,metadata_url=landing,pdf_url=pdf)
 for kind,url in [('metadata',landing),('fulltext',pdf)]:
  try:
   with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Research source verification'}),timeout=35) as response:data=response.read()
   if kind=='fulltext':assert data.startswith(b'%PDF-')
   p=D/(name+('.pdf' if kind=='fulltext' else '.html'));p.write_bytes(data);out[kind]=dict(path=p.name,sha256=hashlib.sha256(data).hexdigest(),bytes=len(data))
  except Exception as e:out[kind]=dict(error=repr(e))
 return out
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(get,sources))
(D/'retrieval.json').write_text(json.dumps(dict(retrieved_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),sources=rows),ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(rows,ensure_ascii=False))
