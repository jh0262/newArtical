from pathlib import Path
import shutil
R=Path(__file__).resolve().parent;OLD=R.parent/'jme_review_20260929';D=R/'delivery';S=R/'support';S.mkdir(exist_ok=True)
for name in ['police_audit.py','adjudicate_police.py','render_pdf_pages.py']:
 shutil.copy2(OLD/'support'/name,S/name)
t=(OLD/'delivery/build_docx.py').read_text(encoding='utf-8')
t=t.replace('论文三轮修订稿.md','论文第四轮修订稿.md').replace('重载机器人速度历史补偿_三轮修订稿.docx','重载机器人速度历史补偿_第四轮修订稿.docx')
insert="""
eqs[4:4]=[
row(mi('G'),mo('='),m('msqrt',row(mi('K'),sup(norm(sub(mi('g'),'w')),2),mo('+'),sup(norm(sub(mi('g'),'ϑ')),2))),mo(','),mi('c'),mo('='),mi('min'),br(row(mn(1),mo(','),frac(mi('γ'),row(mi('G'),mo('+'),sub(mi('ε'),'c')))))),
row(sub(mi('w'),'l'),mo('='),frac(mi('w'),mi('K')),mo(','),sub(m('mover',mi('g'),mo('~')),'l'),mo('='),mi('c'),sub(mi('g'),'w'),mo('+'),frac(mi('λw'),mi('K')),mo('='),sub(m('mover',mi('g'),mo('~')),'w'),mo(','),sup(mi('w'),'+'),mo('='),mi('w'),mo('−'),mi('Kη'),frac(m('mover',mi('m'),mo('^')),row(m('msqrt',m('mover',mi('v'),mo('^'))),mo('+'),sub(mi('ε'),'A'))))
]
"""
t=t.replace('transform=E.XSLT',insert+'\ntransform=E.XSLT')
t=t.replace("inline={k:inline[k]", "inline.update({'g_w':sub(mi('g'),'w'),'g_ϑ':sub(mi('g'),'ϑ'),'ε_A':sub(mi('ε'),'A'),'ε_c':sub(mi('ε'),'c')})\ninline={k:inline[k]")
t=t.replace('assert eqi==9 and figures==7 and len(doc.tables)==7','assert eqi==11 and figures==7 and len(doc.tables)==8')
t=t.replace("if '最小实部' in head:","if '积分设置' in head:widths=[4.4,3.2,3.2,3.2,3.0]\n  if '最小实部' in head:")
t=t.replace("if block.startswith('### 3.5 '):p.paragraph_format.page_break_before=True","# Pagination checked on the final native render.")
(D/'build_docx.py').write_text(t,encoding='utf-8')
t=(OLD/'support/check_docx.py').read_text(encoding='utf-8').replace('重载机器人速度历史补偿_三轮修订稿.docx','重载机器人速度历史补偿_第四轮修订稿.docx')
t=t.replace(r'\([1-9]\)',r'\((?:[1-9]|10|11)\)')
t=t.replace('len(display)==9','len(display)==11').replace("namespaces=ns))==7\n assert len(x.xpath('//wp:inline'","namespaces=ns))==8\n assert len(x.xpath('//wp:inline'")
t=t.replace('len(ref)==20','len(ref)==21').replace('display_equations=9','display_equations=11').replace('tables=7','tables=8').replace('references=20','references=21')
(S/'check_docx.py').write_text(t,encoding='utf-8')
t=(OLD/'support/audit_results.py').read_text(encoding='utf-8')
t=t.replace("E=R/'experiments'","E=R.parent/'jme_review_20260929/experiments'").replace('论文三轮修订稿.md','论文第四轮修订稿.md')
t=t.replace('vals=b[f"{r[\'dt_ms\']:g}"]','vals=b[f"RK4，{r[\'dt_ms\']:g} ms"]')
insert="""
for r in json.loads((R/'adaptive/summary.json').read_text()):
 if r['regime']!='all':continue
 label='误差控制，较松容限' if r['tolerance']=='loose' else '误差控制，较严容限';vals=table(4)[label]
 for i,model in enumerate(['capacity_control','history','history_removed']):check('t4 '+label+' '+model,vals[i],r[model])
 check('t4 '+label+' reduction',vals[3],r['reduction_percent'],.0051)
sv=json.loads((R/'repeat_check/verification.json').read_text())['summary']
for model,label in [('training_mean','训练均值预测'),('velocity','V'),('capacity_control','D'),('history','H'),('history_removed','H0')]:
 for period in [1,2]:check('t8 '+label+' '+str(period),table(8)[label][period-1],next(r['mean'] for r in sv if r['model']==model and r['period']==period))
"""
t=t.replace('refs=re.findall',insert+'\nrefs=re.findall')
t=t.replace('list(range(1,21))','list(range(1,22))').replace("t.count('$$')==18","t.count('$$')==22").replace('references=20','references=21').replace('numbered_equations=9','numbered_equations=11')
(S/'audit_results.py').write_text(t,encoding='utf-8')
print('Prepared DOCX builder and audit scripts; DOCX not built.')
