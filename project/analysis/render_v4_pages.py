from pathlib import Path
import json,hashlib
import pypdfium2 as pdfium
from PIL import Image,ImageDraw
from pypdf import PdfReader
Q=Path(__file__).resolve().parents[1]/'qa/word'
doc=pdfium.PdfDocument(Q/'manuscript_native.pdf')
for i in range(len(doc)):
    doc[i].render(scale=1.85).to_pil().convert('RGB').save(Q/f'page_{i+1:02}.png')
for start in range(0,len(doc),4):
    sheet=Image.new('RGB',(980,1420),'#e3e6eb');d=ImageDraw.Draw(sheet)
    for j,i in enumerate(range(start,min(start+4,len(doc)))):
        im=Image.open(Q/f'page_{i+1:02}.png');im.thumbnail((470,674))
        x=(j%2)*490+(490-im.width)//2;y=(j//2)*710+25
        sheet.paste(im,(x,y));d.text(((j%2)*490+14,(j//2)*710+6),f'Page {i+1}',fill='black')
    sheet.save(Q/f'contact_{start//4+1:02}.png')
r=PdfReader(Q/'manuscript_native.pdf')
(Q/'native_text.txt').write_text('\n'.join(f'PAGE {i+1}\n'+p.extract_text() for i,p in enumerate(r.pages)),encoding='utf-8')
(Q/'render_info.json').write_text(json.dumps({'engine':'Microsoft Word COM read-only PDF, then PDFium rasterization','pages':len(doc),'scale':1.85,'packaged_renderer_limitation':'soffice.exe not found on PATH; native Word used for authoritative pagination','source_sha256':hashlib.sha256((Q.parents[1]/'manuscript/PADE_Mechanical_Optimization_Full_Paper-v4.docx').read_bytes()).hexdigest()},indent=2),encoding='utf-8')
print('Native Word pages rendered:',len(doc))
