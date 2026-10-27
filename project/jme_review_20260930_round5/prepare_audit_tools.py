from pathlib import Path
R=Path(__file__).resolve().parent;OLD=R.parent/'jme_review_20260930_round4';S=R/'support';S.mkdir(exist_ok=True)
for name in ['police_audit.py','render_pdf_pages.py']:
 (S/name).write_text((OLD/'support'/name).read_text(encoding='utf-8'),encoding='utf-8')
text=(OLD/'support/check_docx.py').read_text(encoding='utf-8').replace('第四轮','第五轮')
text=text.replace('assert len(display)==11','assert len(display)==8').replace("))==8","))==5").replace("))==4","))==3").replace('assert len(ref)==23','assert len(ref)==26').replace('display_equations=11','display_equations=8').replace('tables=8,figures=4,references=23','tables=5,figures=3,references=26')
text=text.replace('len(ref)==26','len(ref)==27').replace('references=26','references=27')
tablecheck=''' # Every table cell must survive manuscript conversion; structural counts alone miss truncation.
 md=(D/'论文第五轮修订稿.md').read_text(encoding='utf-8')
 expected=[]
 for block in re.split(r'\\n\\s*\\n',md):
  if block.startswith('|'):
   rows=[r.strip().strip('|').split('|') for r in block.splitlines()]
   expected.append([[v.strip() for v in r] for r in rows if not all(re.fullmatch(r'\\s*:?-+:?\\s*',v) for v in r)])
 actual=[]
 for table in x.xpath('//w:tbl',namespaces=ns):
  actual.append([[''.join(cell.xpath('.//w:t/text()',namespaces=ns)) for cell in row.xpath('./w:tc',namespaces=ns)] for row in table.xpath('./w:tr',namespaces=ns)])
 assert actual==expected, 'Word table cells differ from manuscript'
'''
text=text.replace(' out=dict(',tablecheck+' out=dict(').replace("structural_status='pass',","structural_status='pass',all_table_cells_match=True,")
(S/'check_docx.py').write_text(text,encoding='utf-8')
print('audit tools ready')
