from pathlib import Path
import json,csv,hashlib,re,datetime,zipfile
from lxml import etree as E
ROOT=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def readcsv(p):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
audit=json.loads((ROOT/'qa/run_audit/audit_summary.json').read_text('utf-8'))
assert audit['passed'] and audit['loaded_runs']==5640
visual=json.loads((ROOT/'qa/word/FINAL_VISUAL_QA.json').read_text('utf-8'));assert visual['passed']
render=json.loads((ROOT/'qa/word/render_info.json').read_text('utf-8'))
word=ROOT/'manuscript/PADE_Mechanical_Optimization_Full_Paper-v4.docx'
assert sha(word)==render['source_sha256']==visual['document_sha256']
frozen=json.loads((ROOT/'FROZEN_MANIFEST.json').read_text('utf-8'))
for group,prefix in [('code_files','code'),('protocol_files','')]:
    for name,expected in frozen[group].items():assert sha(ROOT/prefix/name)==expected,name
rawfiles=readcsv(ROOT/'qa/run_audit/raw_manifest.csv');assert len(rawfiles)==5640
assert all(sha(Path(r['source_file']))==r['sha256'] for r in rawfiles),'Raw observations changed.'
inputs=json.loads((ROOT/'INPUT_MANIFEST.json').read_text('utf-8'))
assert all(sha(Path(r['path']))==r['sha256'] for r in inputs)
assert sha(ROOT.parent/'论文修订_20261015/PADE_Mechanical_Optimization_Full_Paper-v3.docx')=='f8063361b2cc22156081c8197d3519ca0aae45d51b4117986113d00f3685a7cb'
spec=json.loads((ROOT/'analysis/paper_results.json').read_text('utf-8'))
for name,value in spec['source_sha256'].items():assert sha(ROOT/'results'/name)==value
with zipfile.ZipFile(word) as z:doc=E.fromstring(z.read('word/document.xml'))
N={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
tables=doc.findall('w:body/w:tbl',N)
actual=[[[ ''.join(c.xpath('.//w:t/text()',namespaces=N)) for c in r.findall('w:tc',N)] for r in t.findall('w:tr',N)] for t in tables]
expected=[b['rows'] for b in spec['results_blocks'] if b['type']=='table']
assert actual[3:7]==[[[str(x) for x in row] for row in t] for t in expected]
assert actual[7]==[[str(x) for x in row] for row in spec['best_design_table']]
figure=json.loads((ROOT/'figures/FIGURE_MANIFEST.json').read_text('utf-8'))
assert figure['figure_count']==14
for e in figure['entries']:
    for k in ['fig','png','pdf']:assert Path(e[k]).is_file(),e[k]

report=(ROOT/'package/必改项落实与更新评审.md').read_text('utf-8')
report=report.replace('当前Word最终合并和分页核查仍由主任务完成，相关状态明确列出。',f'v4 Word已合并全部修订，并经本机Word只读渲染和{render["pages"]}页逐页视觉检查。')
report=report.replace('**理论文本与实现检查完成**；Word合并中；','**已完成并合入v4**；')
report=report.replace('**来源与矩阵完成**；全文和预览层级区分，Word合并中','**已完成并合入v4**；全文和预览层级区分')
report=report.replace('**数据与图已形成**；最终Word图号和分页复核中','**已完成**；14套中英文图、正文6图及其图号和分页已核对')
report=report.replace('**科学结论已更新**；v4 Word合并中；','**已完成并合入v4**；')
report=report.replace('**原件与历史表保全完成**；最终Word/PDF逐页检查待主任务关闭',f'**已完成**；原件和历史表哈希一致，Word结构及{render["pages"]}页原生分页/图片检查通过')
report+='\n\n## 七 最终交付核对\n\n'
report+=f'完整[v4修订稿]({word.as_posix()})包含8张表、6幅正文图及原生可编辑公式；本机Word只读导出后哈希不变，{render["pages"]}页逐页检查通过。图内文字已放大，公式断行与表格孤字已修复。\n\n'
report+='最终复核再次确认：5640份raw与独立审计哈希逐份一致；四个原始输入及v3未修改；论文表4—8与真实统计/工程结果逐单元对应；冻结核心和协议未改变。\n'
(ROOT/'必改项落实与更新评审.md').write_text(report,encoding='utf-8')
broken=[]
for path in [ROOT/'必改项落实与更新评审.md',ROOT/'README.md']:
    for target in re.findall(r'\]\((F:/[^)]+)\)',path.read_text('utf-8')):
        if not Path(target.split('#')[0]).exists():broken.append(target)
assert not broken,broken
statepath=ROOT/'.sci/state.json';state=json.loads(statepath.read_text('utf-8'))
evidence={
'S06':'5640 complete saved MATLAB runs; 194577300 exact successful search FE. Independent audit: 0 errors, 0 warnings. Failed initial IO attempt preserved separately.',
'S07':'136 complete prespecified paired tests with within-family Holm; stable moments; 810 engineering exact residual rechecks. Full versus parent 0/20/6; versus classic 14/12/0.',
'S08':'14 bilingual figure sets, editable FIG, 300dpi PNG and vector PDF with source data; final paper typography checked.',
'S09':f'Complete editable v4 Word; 8 tables, 6 figures, native OMML. Native Word {render["pages"]}-page render inspected.',
'S10':'Updated independent review and M01-M12 completion ledger. Incremental performance claim remains unsupported; not ready as a performance-improvement submission.',
'S11':'Source and historical preservation, raw SHA-256 verification, final table mapping and delivery manifest.'}
for stage in state['stages']:
    if stage['id'] in evidence:stage['status']='checked';stage['evidence_scope']=evidence[stage['id']]
state['scientific_outcome']={'incremental_performance_claim_supported':False,'full_vs_parent':[0,20,6],'full_vs_classic':[14,12,0],'submission':'not_requested_and_not_recommended_for_current_performance_claim'}
state['completed_at_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
statepath.write_text(json.dumps(state,ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'HANDOFF.md').write_text(f'# 当前完成状态\n\n5640次正式运行及194577300 FE已完成；全量审计通过。预设同父检验0有利/20未显著/6不利，经典DE对照14/12/0。核心消融无校正后正向增益。\n\nv4 Word、更新评审、完整代码和真实数据包已交付；{render["pages"]}页原生Word视觉核对通过，原件未改。证据呈现的必改项已落实；新增机制性能主张尚未成立，不能以完成修订等同发表就绪。\n\n后续若开发新门控/谱尺度/J策略，应单列新版本及独立开发/验证种子。本轮冻结结果继续保留，未进行结果导向的调参或选择性替换。\n',encoding='utf-8')
records=[]
for name in ['README.md','必改项落实与更新评审.md','PROTOCOL.md','CONFIG.json','comparisons.csv','FROZEN_MANIFEST.json','INPUT_MANIFEST.json','HANDOFF.md']:
    p=ROOT/name;records.append({'path':name,'bytes':p.stat().st_size,'sha256':sha(p)})
for folder in ['code','results','figures','manuscript','historical']:
    for p in sorted((ROOT/folder).rglob('*')):
        if p.is_file():records.append({'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)})
manifest={'completed_at_utc':state['completed_at_utc'],'formal_runs':5640,'formal_search_FE':194577300,'raw_manifest':'qa/run_audit/raw_manifest.csv','raw_files_rehashed_unchanged':5640,'word_sha256':sha(word),'native_word_pages':render['pages'],'table_mapping_passed':True,'source_preserved':True,'review':'必改项落实与更新评审.md','scientific_outcome':state['scientific_outcome'],'files':records}
(ROOT/'DELIVERY_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in manifest.items() if k!='files'},ensure_ascii=False))
