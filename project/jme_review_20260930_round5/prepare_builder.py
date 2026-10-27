from pathlib import Path
R=Path(__file__).resolve().parent;D=R/'delivery';D.mkdir(exist_ok=True)
src=(R.parent/'jme_review_20260930_round4/delivery/build_docx.py').read_text(encoding='utf-8')
insert="""
# Select only equations present in the focused manuscript; all remain editable OMML.
delta_eq=row(sub(mi('x'),'j'),mo('='),frac(row(sub(mi('v'),'j'),mo('−'),sub(mi('μ'),'j')),sub(mi('s'),'v,j')),mo(','),sub(mi('δ'),'j,k'),mo('='),frac(row(sub(mi('v'),'j'),br(row(mi('t'),mo('−'),sub(mi('ℓ'),'k'),mi('Δt'))),mo('−'),sub(mi('v'),'j'),br(mi('t'))),sub(mi('s'),'v,j')))
eqs=[eqs[0],delta_eq,eqs[2],eqs[4],eqs[5],eqs[6],eqs[8],eqs[10]]
"""
src=src.replace('transform=E.XSLT',insert+'\ntransform=E.XSLT')
src=src.replace('论文第四轮修订稿.md','论文第五轮修订稿.md').replace('重载机器人速度历史补偿_第四轮修订稿.docx','重载机器人速度历史补偿_第五轮修订稿.docx')
src=src.replace('重载机器人速度历史补偿的对照与积分敏感性','重载机器人速度历史补偿的优化对照研究')
src=src.replace("block.startswith('Controlled comparisons')","block.startswith('Optimization controls')")
src=src.replace('assert eqi==11 and figures==4 and len(doc.tables)==8','assert eqi==8 and figures==3 and len(doc.tables)==5')
src=src.replace("if head.startswith('关节'):widths=[4.4,4.2,4.2,4.2]", "if head.startswith('关节'):widths=[1.4,3.2,3.2,5.0,4.2]")
src=src.replace('  for i,r in enumerate(rs):', "  assert len(widths)==len(rs[0]),(head,widths)\n  assert all(len(r)==len(rs[0]) for r in rs),head\n  for i,r in enumerate(rs):")
src=src.replace("inline={k:inline[k] for k in sorted(inline,key=len,reverse=True)}", "inline.update({'D_s':sub(mi('D'),'s'),'V_m':sub(mi('V'),'m'),'ℓ_k':sub(mi('ℓ'),'k'),'s_v':sub(mi('s'),'v'),'a_D':sub(mi('a'),'D'),'a_V':sub(mi('a'),'V'),'s_a':sub(mi('s'),'a')})\ninline={k:inline[k] for k in sorted(inline,key=len,reverse=True)}")
(D/'build_docx.py').write_text(src,encoding='utf-8')
print(D/'build_docx.py')
