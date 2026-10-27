from pathlib import Path
import json, hashlib, math
from PIL import Image, ImageDraw
from pypdf import PdfReader
R=Path(__file__).resolve().parents[1]
def main():
    entries=[];tiles=[]
    for png in sorted((R/'figures').glob('*.png')):
        im=Image.open(png).convert('RGB');pdf=png.with_suffix('.pdf');reader=PdfReader(pdf)
        assert len(reader.pages)==1 and im.width>1000 and im.height>400
        txt=reader.pages[0].extract_text();assert len(txt)>40
        entries.append({'figure':png.stem,'png_pixels':[im.width,im.height],'pdf_pages':len(reader.pages),'pdf_text_characters':len(txt),'png_sha256':hashlib.sha256(png.read_bytes()).hexdigest()})
        im.thumbnail((1200,480));tile=Image.new('RGB',(1220,520),'white');tile.paste(im,((1220-im.width)//2,30));ImageDraw.Draw(tile).text((15,8),png.stem,fill='black');tiles.append(tile)
    assert len(entries)==7
    sheet=Image.new('RGB',(2440,520*math.ceil(len(tiles)/2)),'#e9e9e9')
    for i,tile in enumerate(tiles):sheet.paste(tile,((i%2)*1220,(i//2)*520))
    sheet.save(R/'audit/figure_contact_sheet.png')
    audit={'status':'pass','figure_pairs':entries,'visual_check':'contact sheet and selected full-resolution figures require manual inspection'}
    (R/'audit/artifact_qa.json').write_text(json.dumps(audit,indent=2),encoding='utf-8');print(json.dumps(audit,indent=2))
if __name__=='__main__':main()
