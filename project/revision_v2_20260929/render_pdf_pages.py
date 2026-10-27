from pathlib import Path
import json
import pypdfium2 as pdfium
ROOT=Path(__file__).resolve().parent
pdf=pdfium.PdfDocument(ROOT/'render_qa/manuscript.pdf')
OUT=ROOT/'render_qa/final';OUT.mkdir(exist_ok=True)
pages=[]
for i in range(len(pdf)):
    page=pdf[i]
    image=page.render(scale=1.6).to_pil()
    image.save(OUT/f'page-{i+1}.png')
    text=page.get_textpage().get_text_range()
    pages.append({'page':i+1,'characters':len(text),'text':text})
(OUT/'page_text.json').write_text(json.dumps(pages,ensure_ascii=False,indent=2),encoding='utf-8')
print('Rendered',len(pdf),'pages')
