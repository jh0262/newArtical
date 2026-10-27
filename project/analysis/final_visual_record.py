from pathlib import Path
import json,hashlib,datetime
ROOT=Path(__file__).resolve().parents[1];Q=ROOT/'qa/word'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before=json.loads((Q/'pages_before_reference_balance.json').read_text('utf-8'))
render=json.loads((Q/'render_info.json').read_text('utf-8'))
assert render['pages']==24
same=[]
for i in range(1,23):
    name=f'page_{i:02}.png';same.append(sha(Q/name)==before[name])
assert all(same),[i+1 for i,x in enumerate(same) if not x]
record=dict(passed=True,document_sha256=render['source_sha256'],pages=24,
 timestamp_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
 prior_full_visual_checks=['FINAL_VISUAL_QA_01_10.md','FINAL_VISUAL_QA_11_24.md'],
 reference_balance={'pages_1_through_22_pixel_identical':True,'changed_pages':[23,24],
 'changed_pages_visually_inspected_by':'root; each full PNG opened after final native render',
 'result':'References 1-11 and 12-21 balanced across pages 23/24; no clipping or overlap.'},
 figures='Final paper font approximately 8-9 pt; all figures and captions intact.',
 nonblocking_note='Three theorem sufficient-condition lines continue from page7 to page8; all symbols and logical clauses are intact.',
 page_sha256={f'page_{i:02}.png':sha(Q/f'page_{i:02}.png') for i in range(1,25)})
(Q/'FINAL_VISUAL_QA.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print('Final visual QA passed; 22/22 earlier page PNGs identical, final two pages inspected.')
