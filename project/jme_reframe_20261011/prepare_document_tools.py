from pathlib import Path
import shutil
R=Path(__file__).resolve().parent;OLD=R.parent/'jme_review_20260930_round5';D=R/'delivery';S=R/'support';S.mkdir(exist_ok=True)
title='基于梯度度量匹配的重载机器人速度历史补偿模型优化'
t=(OLD/'delivery/build_docx.py').read_text(encoding='utf-8')
t=t.replace('重载机器人速度历史补偿的优化对照研究',title).replace('论文第五轮修订稿.md','论文重构修订稿.md').replace('重载机器人速度历史补偿_第五轮修订稿.docx',title+'.docx').replace("block.startswith('Optimization controls')","block.startswith('Optimization of velocity')")
t=t.replace("doc.add_paragraph(block[2:],style='Title')","doc.add_paragraph(block[2:].replace('重载机器人速度','重载机器人\\n速度'),style='Title')")
t=t.replace('assert eqi==8 and figures==3 and len(doc.tables)==5','assert eqi==11 and figures==3 and len(doc.tables)==7')
insertion="""
# Three added equations correspond exactly to source equations3,5,7.
objective=row(sub(mi('J'),'D'),br(mi('ψ')),mo('='),frac(mn(1),mi('6N')),summ('i=1','N'),sup(norm(row(sup(sub(mi('S'),'a'),'-1'),br(row(sub(mi('f'),'0'),br(mi('qᵢ,vᵢ,uᵢ;θ')),mo('+'),sup(sub(mi('M'),'i'),'-1'),sub(mi('r'),'ψ'),br(sub(mi('z'),'i')),mo('−'),sub(mi('a'),'i'))))),2),mo('+'),frac(mi('λ'),mn(2)),sup(norm(mi('ψ')),2))
folded=row(sub(mi('J'),'V'),br(mi('w,ϑ')),mo('='),sub(mi('J'),'data'),br(mi('w,ϑ')),mo('+'),frac(mi('λ'),mi('2K')),sup(norm(mi('w')),2),mo('+'),frac(mi('λ'),mn(2)),sup(norm(mi('ϑ')),2))
energy=sup(norm(sub(mi('g'),'w')),2)
total=row(energy,mo('+'),sup(norm(sub(mi('g'),'ϑ')),2))
ratio=row(mi('ρ'),mo('='),frac(energy,total),mo(','),frac(mi('G'),sub(mi('G'),'0')),mo('='),m('msqrt',row(mn(1),mo('+'),br(row(mi('K'),mo('−'),mn(1))),mi('ρ'))),mo(','),mn(1),mo('≤'),frac(sub(mi('c'),'0'),mi('c')),mo('≤'),m('msqrt',mi('K')))
eqs=[eqs[0],eqs[1],objective,eqs[2],folded,eqs[3],ratio,eqs[4],eqs[5],eqs[6],eqs[7]]
"""
t=t.replace("transform=E.XSLT",insertion+"\ntransform=E.XSLT",1)
# The table has six genuinely parallel columns; use the full page equally.
t=t.replace("head=''.join(rs[0])","head=''.join(rs[0])\n  if head.startswith('复制次数'):widths=[2.0,2.0,3.25,3.25,3.25,3.25]\n  if head.startswith('K折叠'):widths=[1.2,3.6,3.6,3.6,5.0]")
(D/'build_docx.py').write_text(t,encoding='utf-8')
for name in ['police_audit.py','check_docx.py','render_pdf_pages.py']:
    a=(OLD/'support'/name).read_text(encoding='utf-8').replace('论文第五轮修订稿.md','论文重构修订稿.md').replace('重载机器人速度历史补偿_第五轮修订稿.docx',title+'.docx')
    if name=='check_docx.py':
        a=a.replace('len(display)==8','len(display)==11').replace("namespaces=ns))==5","namespaces=ns))==7").replace('display_equations=8','display_equations=11').replace('tables=5','tables=7')
        a=a.replace("official template retrieved; documented formatting applied; native visual inspection and missing author metadata remain separate","layout inherited from previously retrieved template; current native QA and real author metadata remain separate")
    (S/name).write_text(a,encoding='utf-8')
print('Prepared editable Word builder,11 equations,7 tables,3 figures and audit tools')
