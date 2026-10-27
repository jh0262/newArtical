from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
import csv

root = Path(__file__).resolve().parents[1]
source = root.parent / '论文修订_20261015' / 'PADE_Mechanical_Optimization_Full_Paper-v3.docx'
ns = {'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
      'm':'http://schemas.openxmlformats.org/officeDocument/2006/math',
      'w14':'http://schemas.microsoft.com/office/word/2010/wordml'}
with ZipFile(source) as z:
    doc = E.fromstring(z.read('word/document.xml'))
body = doc.find('w:body', ns)
rows=[]
pnum=tnum=0
previous=''
for xmlindex, element in enumerate(body, 1):
    name=element.tag.rsplit('}',1)[-1]
    text=''.join(x.text or '' for x in element.iter()
                 if x.tag in ('{'+ns['w']+'}t','{'+ns['m']+'}t'))
    text=text.replace('\t',' ').replace('\n',' ')
    if name=='p':
        pnum+=1
        style=element.find('w:pPr/w:pStyle',ns)
        style=style.get('{'+ns['w']+'}val','') if style is not None else ''
        pid=element.get('{'+ns['w14']+'}paraId','')
        rows.append(['P',pnum,pid,xmlindex,style,text])
        if text: previous=text
    elif name=='tbl':
        tnum+=1
        nrows=len(element.findall('w:tr',ns))
        first=element.find('w:tr',ns)
        ncols=len(first.findall('w:tc',ns)) if first is not None else 0
        rows.append(['T',tnum,'',xmlindex,f'{nrows}x{ncols}',previous+' | '+text[:250]])
out=root/'analysis'/'V3段落定位.tsv'
with out.open('w',encoding='utf-8-sig',newline='') as f:
    writer=csv.writer(f,delimiter='\t')
    writer.writerow(['type','index','paraId','body_xml_index','style_or_shape','text'])
    writer.writerows(rows)
print('Source:',source)
print('Paragraphs:',pnum,'Tables:',tnum)
print('Written:',out)
for r in rows:
    if r[0]=='T' or r[4] in ['1','2','3','4','Title','Subtitle'] or (r[5].startswith(('摘要','Abstract','图1','图2','图3','表1','表2','表3','表4','表5','参考文献','注：'))):
        print('\t'.join(map(str,r)))
