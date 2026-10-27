from pathlib import Path
import subprocess,json,zipfile,re,hashlib
from lxml import etree as E
ROOT=Path(__file__).resolve().parents[1];D=ROOT/'manuscript'
OUT=D/'PADE_Mechanical_Optimization_Full_Paper-v4.docx'
Q=ROOT/'qa/word';Q.mkdir(exist_ok=True)
CLI=r'C:\Users\hp\AppData\Local\OfficeCli\officecli.exe'
W='http://schemas.openxmlformats.org/wordprocessingml/2006/main';M='http://schemas.openxmlformats.org/officeDocument/2006/math'
N={'w':W,'m':M}
def run(args):
    r=subprocess.run([CLI,*map(str,args)],capture_output=True,text=True,encoding='utf-8',errors='replace')
    if r.returncode:
        if args[0]=='raw-set' and '"code": "not_found"' in r.stdout:return r.stdout
        raise RuntimeError(r.stdout+r.stderr)
    return r.stdout
run(['open',OUT])
ops=[
('/w:document/w:body/w:tbl/w:tblPr','append',f'<w:tblCellMar xmlns:w="{W}"><w:top w:w="55" w:type="dxa"/><w:left w:w="60" w:type="dxa"/><w:bottom w:w="55" w:type="dxa"/><w:right w:w="60" w:type="dxa"/></w:tblCellMar>'),
('/w:document/w:body/w:tbl/w:tr/w:tc[not(w:tcPr)]/w:p[1]','insertbefore',f'<w:tcPr xmlns:w="{W}"/>'),
('/w:document/w:body/w:tbl/w:tr[1]/w:tc/w:tcPr','append',f'<w:shd xmlns:w="{W}" w:fill="E9EEF3" w:val="clear"/>'),
('/w:document/w:body/w:tbl/w:tr/w:tc/w:tcPr','append',f'<w:vAlign xmlns:w="{W}" w:val="center"/>'),
('/w:document/w:body/w:tbl/w:tr/w:trPr[not(w:cantSplit)]','append',f'<w:cantSplit xmlns:w="{W}"/>'),
('/w:document/w:body/w:tbl/w:tr[not(w:trPr)]/w:tc[1]','insertbefore',f'<w:trPr xmlns:w="{W}"><w:cantSplit/></w:trPr>')]
logs=[]
for xp,act,xml in ops:logs.append(run(['raw-set',OUT,'/document','--xpath',xp,'--action',act,'--xml',xml,'--json']))
run(['save',OUT]);run(['close',OUT])
val=json.loads(run(['validate',OUT,'--json']))
html=json.loads(run(['view',OUT,'html','--json']))
(Q/'preview.html').write_text(html['data'],encoding='utf-8')
run(['close',OUT])
with zipfile.ZipFile(OUT) as z:doc=E.fromstring(z.read('word/document.xml'))
plain='\n'.join(''.join(p.xpath('.//w:t/text()',namespaces=N)) for p in doc.findall('w:body/w:p',N))
full='\n'.join(''.join(p.xpath('.//w:t/text()|.//m:t/text()',namespaces=N)) for p in doc.findall('w:body/w:p',N))
(Q/'plain_text.txt').write_text(plain,encoding='utf-8');(Q/'all_text.txt').write_text(full,encoding='utf-8')
assert not re.search(r'TODO|TBD|待填写|\\\(|\\frac|\\sqrt|\\operatorname',plain)
tables=doc.findall('w:body/w:tbl',N)
assert len(tables)==8
assert [len(t.findall('w:tr',N)) for t in tables]==[7,4,7,7,27,7,10,4]
assert '194577300' in full and '5640' in full
input_checks=[]
for a in json.loads((ROOT/'INPUT_MANIFEST.json').read_text('utf-8')):
    p=Path(a['path']);sha=hashlib.sha256(p.read_bytes()).hexdigest();input_checks.append(dict(path=str(p),unchanged=sha==a['sha256'],sha256=sha))
assert all(x['unchanged'] for x in input_checks)
report=dict(validation=val,input_checks=input_checks,tables=len(tables),table_rows=[len(t.findall('w:tr',N)) for t in tables],
 images=len(doc.findall('.//w:drawing',N)),native_math_objects=len(doc.findall('.//m:oMath',N)),
 references=len(re.findall(r'^\[\d+\]',plain,re.M)),paragraphs=len(doc.findall('w:body/w:p',N)),
 sha256=hashlib.sha256(OUT.read_bytes()).hexdigest(),format_logs=logs)
(Q/'structural_checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ['format_logs','input_checks']},ensure_ascii=False))
