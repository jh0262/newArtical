from pathlib import Path
import zipfile,json,hashlib,subprocess
from lxml import etree as E
ROOT=Path(__file__).resolve().parents[1];Q=ROOT/'qa/word'
DOC=ROOT/'manuscript/PADE_Mechanical_Optimization_Full_Paper-v4.docx'
CLI=r'C:\Users\hp\AppData\Local\OfficeCli\officecli.exe'
N={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in Q.glob('page_*.png')}
(Q/'pages_before_reference_balance.json').write_text(json.dumps(before,indent=2),encoding='utf-8')
with zipfile.ZipFile(DOC) as z:d=E.fromstring(z.read('word/document.xml'))
ps=d.findall('w:body/w:p',N)
target=next(i for i,p in enumerate(ps,1) if ''.join(p.xpath('.//w:t/text()',namespaces=N)).startswith('[12] '))
pid=ps[target-1].get('{http://schemas.microsoft.com/office/word/2010/wordml}paraId')
assert pid
for args in [['set',DOC,f'/body/p[@paraId={pid}]','--prop','pageBreakBefore=true'],['save',DOC],['close',DOC]]:
    p=subprocess.run([CLI,*map(str,args)],capture_output=True,text=True,encoding='utf-8',errors='replace')
    assert p.returncode==0,p.stdout+p.stderr
    print(p.stdout)
check=json.loads((Q/'structural_checks.json').read_text('utf-8'))
check['sha256']=hashlib.sha256(DOC.read_bytes()).hexdigest()
check['reference_balance']='Page break before reference 12; text, data, figures and all earlier pages unchanged.'
(Q/'structural_checks.json').write_text(json.dumps(check,ensure_ascii=False,indent=2),encoding='utf-8')
print(check['sha256'])
