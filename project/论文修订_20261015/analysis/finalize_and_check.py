from pathlib import Path
import json,zipfile,re,hashlib,subprocess
from lxml import etree as E
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'PADE_Mechanical_Optimization_Full_Paper-v3.docx'
CLI=r'C:\Users\hp\AppData\Local\OfficeCli\officecli.exe'
W='http://schemas.openxmlformats.org/wordprocessingml/2006/main';M='http://schemas.openxmlformats.org/officeDocument/2006/math';N={'w':W,'m':M,'w14':'http://schemas.microsoft.com/office/word/2010/wordml'}
def run(args):
    r=subprocess.run([CLI,*map(str,args)],capture_output=True,text=True,encoding='utf-8',errors='replace')
    if r.returncode:
        if args[0]=='raw-set' and '"code": "not_found"' in r.stdout:return r.stdout
        raise RuntimeError(r.stdout+r.stderr)
    return r.stdout
run(['open',OUT])
log=[]
for xpath,action,xml in [
 ('/w:document/w:body/w:tbl/w:tr[1]/w:tc[not(w:tcPr)]/w:p[1]','insertbefore',f'<w:tcPr xmlns:w="{W}"><w:shd w:fill="E9EEF3" w:val="clear"/><w:tcMar><w:top w:w="40" w:type="dxa"/><w:left w:w="60" w:type="dxa"/><w:bottom w:w="40" w:type="dxa"/><w:right w:w="60" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr>'),
 ('/w:document/w:body/w:tbl/w:tr[position()>1]/w:tc[not(w:tcPr)]/w:p[1]','insertbefore',f'<w:tcPr xmlns:w="{W}"><w:tcMar><w:top w:w="40" w:type="dxa"/><w:left w:w="60" w:type="dxa"/><w:bottom w:w="40" w:type="dxa"/><w:right w:w="60" w:type="dxa"/></w:tcMar><w:vAlign w:val="center"/></w:tcPr>'),
 ('/w:document/w:body/w:tbl/w:tr/w:trPr[not(w:cantSplit)]','append',f'<w:cantSplit xmlns:w="{W}"/>'),
 ('/w:document/w:body/w:tbl/w:tr[not(w:trPr)]/w:tc[1]','insertbefore',f'<w:trPr xmlns:w="{W}"><w:cantSplit/></w:trPr>')]:
    log.append(run(['raw-set',OUT,'/document','--xpath',xpath,'--action',action,'--xml',xml,'--json']))
run(['save',OUT]);run(['close',OUT])
with zipfile.ZipFile(OUT) as z:root=E.fromstring(z.read('word/document.xml'))
cmd=[];image_i=0
for p in root.findall('w:body/w:p',N):
    if p.find('.//w:drawing',N) is not None:
        image_i+=1
        pid=p.get('{'+N['w14']+'}paraId')
        if pid:
            cmd.append({'command':'set','path':f'/body/p[@paraId={pid}]','props':{'keepNext':'true','lineSpacing':'1x','spaceAfter':'0pt'}})
            dims={1:(14.8,12.9753),2:(14.8,9.0444),3:(14.8,7.94146)}
            wd,ht=dims[image_i]
            runs=p.findall('w:r',N);ri=next(j for j,r in enumerate(runs,1) if r.find('.//w:drawing',N) is not None)
            cmd.append({'command':'set','path':f'/body/p[@paraId={pid}]/r[{ri}]','props':{'src':str(ROOT/'figures'/f'figure{image_i}.png'),'width':f'{wd}cm','height':f'{ht}cm'}})
if cmd:
    f=ROOT/'analysis/final_format.json';f.write_text(json.dumps(cmd),encoding='utf-8');run(['batch',OUT,'--input',f,'--stop-on-error','--json']);run(['close',OUT])
validation=json.loads(run(['validate',OUT,'--json']))
html=json.loads(run(['view',OUT,'html','--json']))
(ROOT/'qa/preview.html').write_text(html['data'],encoding='utf-8')
with zipfile.ZipFile(OUT) as z:
    root=E.fromstring(z.read('word/document.xml'))
    full='\n'.join(''.join(p.xpath('.//w:t/text()|.//m:t/text()',namespaces=N)) for p in root.findall('w:body/w:p',N))
(ROOT/'qa/final_document_text.txt').write_text(full,encoding='utf-8')
inputs=json.loads((ROOT/'qa/inputs_start.json').read_text('utf-8-sig'))
checks=[]
for a in inputs:
    p=ROOT.parent/a['name'];sha=hashlib.sha256(p.read_bytes()).hexdigest();checks.append({'name':a['name'],'sha256':sha,'unchanged':sha==a['sha256']})
assert all(x['unchanged'] for x in checks)
assert not re.search(r'TODO|TBD|替换P|待填写|\\frac|\\sqrt|\\operatorname',full)
tables=root.findall('w:body/w:tbl',N)
assert len(tables)==5
source=json.loads((ROOT/'analysis/source_tables.json').read_text('utf-8'))['tables']
def tx(el):return ''.join(el.xpath('.//w:t/text()|.//m:t/text()',namespaces=N))
vals=[[[tx(c) for c in r.findall('w:tc',N)] for r in t.findall('w:tr',N)] for t in tables]
assert len(vals[0])==24
assert vals[2][-1][1:3]==['1.724852','1.724852']
assert vals[3][-1][1]=='1.339956'
assert vals[4][-1][1:]==['6059.714335','6143.699569','6410.086760','140.9']
def norm(s):
    s=s.replace('−','-').replace(' ','').replace('NA','NaN')
    return re.sub(r'×10\^\(?([+-]?\d+)\)?',lambda m:'e'+m[1],s)
numeric_checks=[]
for i,r in enumerate(vals[0][1:],1):
    for new,old in [(1,2),(2,4),(3,5),(4,7),(5,8),(6,9)]:
        numeric_checks.append(norm(r[new])==norm(source[0]['rows'][i][old]))
for i,r in enumerate(vals[1][1:],1):
    for j in range(1,7):numeric_checks.append(norm(r[j])==norm(source[1]['rows'][i][j]))
for i,r in enumerate(vals[2][1:],1):
    for new,old in [(1,5),(2,6),(3,7)]:numeric_checks.append(norm(r[new])==norm(source[2]['rows'][i][old]))
for i,r in enumerate(vals[3][1:],1):numeric_checks.append(norm(r[1])==norm(source[3]['rows'][i][6]))
for i,r in enumerate(vals[4][1:],1):
    for j in range(1,5):numeric_checks.append(norm(r[j])==norm(source[4]['rows'][i][j]))
assert all(numeric_checks)
verdicts=[r[-1] for r in vals[0][1:]]
counts={s:verdicts.count(s) for s in set(verdicts)}
assert counts.get('+')==15 and counts.get('NA')==2 and counts.get('=')==4
report={'validation':validation,'inputs':checks,'tables':len(tables),'table_rows':[len(v) for v in vals],'images':len(root.findall('.//w:drawing',N)),'native_math_objects':len(root.findall('.//m:oMath',N)),'matched_table_values':len(numeric_checks),'verdict_counts':counts,'body_paragraphs':len(root.findall('w:body/w:p',N)),'reference_count':len(re.findall(r'^\[\d+\]',full,re.M)),'source_code_execution':'NOT_RUN','new_optimization_experiments':'NONE','format_logs':log}
(ROOT/'qa/final_checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ['format_logs','inputs']},ensure_ascii=False))
