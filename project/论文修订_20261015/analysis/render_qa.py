from pathlib import Path
import pypdfium2 as pdfium
from PIL import Image,ImageDraw
from pypdf import PdfReader
P=Path(__file__).resolve().parents[1]/'qa'
r=pdfium.PdfDocument(P/'manuscript_native.pdf')
for f in P.glob('page_*.png'):
    if int(f.stem.split('_')[-1])>len(r):f.unlink()
for i in range(len(r)):
    im=r[i].render(scale=1.7).to_pil().convert('RGB');im.save(P/f'page_{i+1:02}.png')
for start in range(0,len(r),4):
    inds=list(range(start,min(start+4,len(r))))
    sheet=Image.new('RGB',(2*460,2*680),'#e3e6eb');d=ImageDraw.Draw(sheet)
    for j,i in enumerate(inds):
        im=Image.open(P/f'page_{i+1:02}.png');im.thumbnail((444,640));x=(j%2)*460+(460-im.width)//2;y=(j//2)*680+24
        sheet.paste(im,(x,y));d.text(((j%2)*460+15,(j//2)*680+5),f'Page {i+1}',fill='black')
    sheet.save(P/f'contact_{start//4+1:02}.png')
rr=PdfReader(P/'manuscript_native.pdf')
(P/'native_text.txt').write_text('\n'.join(f'PAGE {i+1}\n'+p.extract_text() for i,p in enumerate(rr.pages)),encoding='utf-8')
print('Rendered',len(r),'pages')
