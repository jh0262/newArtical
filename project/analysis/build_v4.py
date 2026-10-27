"""Build the actual v4 manuscript from frozen protocol and completed MATLAB data.
OfficeCLI does the authoring; OOXML fallback preserves supplied model equations.
Run only after statistical analysis and independent raw-run audit complete.
"""
from pathlib import Path
import re, json, copy, zipfile, subprocess, shutil, sys, csv
from lxml import etree as E
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
OLD=ROOT.parent/'论文修订_20261015'
DEST=ROOT/'manuscript'; DEST.mkdir(exist_ok=True)
OUT=DEST/'PADE_Mechanical_Optimization_Full_Paper-v4.docx'
CLI=r'C:\Users\hp\AppData\Local\OfficeCli\officecli.exe'
W='http://schemas.openxmlformats.org/wordprocessingml/2006/main'
M='http://schemas.openxmlformats.org/officeDocument/2006/math'
NS={'w':W,'m':M}
with zipfile.ZipFile(ROOT.parent/'PADE_Mechanical_Optimization_Full_Paper-v2.docx') as z:
    source=E.fromstring(z.read('word/document.xml'))
source_p=source.findall('w:body/w:p',NS)
commands=[]; segments=[]; text_log=[]; ntables=0; eqno=0

def cmd(c): commands.append(c)
def flush():
    if commands: segments.append(('batch',commands.copy()));commands.clear()
def raw(el):
    flush();segments.append(('raw',E.tostring(el,encoding='unicode')))
def p(text='',style='Normal',size=11,align='justify',bold=False,keep=False):
    text=text.replace('**','').strip(); text_log.append(text)
    props={'text':text if r'\(' not in text else '', 'style':style,'size':f'{size}pt',
      'font':'Times New Roman','font.ea':'宋体','color':'000000','bold':str(bold).lower(),
      'align':align,'lineSpacing':'1.22x','spaceBefore':'0pt','spaceAfter':'5pt',
      'firstLineIndent':'22pt' if style=='Normal' and align=='justify' else '0pt',
      'keepNext':str(keep).lower(),'keepLines':'false'}
    cmd({'command':'add','parent':'/body','type':'paragraph','props':props})
    if r'\(' in text:
        for part in re.split(r'(\\\(.*?\\\))',text):
            if not part:continue
            if part.startswith(r'\('):
                cmd({'command':'add','parent':'/body/p[last()]','type':'equation',
                    'props':{'formula':mathfix(part[2:-2]),'mode':'inline'}})
            else:
                cmd({'command':'add','parent':'/body/p[last()]','type':'run',
                    'props':{'text':part,'font':'Times New Roman','font.ea':'宋体','size':f'{size}pt','color':'000000'}})
def h(text,level=1):p(text,'2' if level==1 else '3' if level==2 else '4',14 if level==1 else 12 if level==2 else 11,'left',True,True)
def mathfix(s):
    return s.replace(r'\mathbf1',r'\mathbf{1}').replace(r'\mathbb R',r'\mathbb{R}').replace(r'\mathcal N',r'\mathcal{N}').replace(r'\mathcal S',r'\mathcal{S}').replace('\n',' ')
def eq(s):
    global eqno
    eqno+=1;p('',size=10.5,align='center')
    cmd({'command':'add','parent':'/body/p[last()]','type':'equation','props':{'formula':mathfix(s),'mode':'inline'}})
    text_log.append('[equation] '+s)
def orig_eq(i):
    el=copy.deepcopy(source_p[i-1]); pp=el.find('w:pPr',NS)
    if pp is not None:
        for n in ['keepNext','pageBreakBefore']:
            for c in pp.findall('w:'+n,NS):pp.remove(c)
    raw(el);text_log.append('[supplied model equation] '+''.join(el.xpath('.//w:t/text()|.//m:t/text()',namespaces=NS)))
def table(rows,widths=None):
    global ntables
    ntables+=1;n=len(rows);m=len(rows[0]);base=f'/body/tbl[{ntables}]'
    if widths is None:widths=[int(8500/m)]*m
    cmd({'command':'add','parent':'/body','type':'table','props':{'rows':str(n),'cols':str(m),'width':'100%','layout':'fixed','colWidths':','.join(map(str,widths)),'border.all':'single;4;D9D9D9'}})
    for ri,row in enumerate(rows,1):
        rowprops={f'c{j}':str(v).replace('\\(','').replace('\\)','') for j,v in enumerate(row,1)}
        if ri==1:rowprops['header']='true'
        cmd({'command':'set','path':base+f'/tr[{ri}]','props':rowprops})
        for ci in range(1,m+1):
            cmd({'command':'set','path':base+f'/tr[{ri}]/tc[{ci}]/p[1]','props':{'font':'Times New Roman','font.ea':'宋体','size':'8pt' if m>=7 else '9pt','lineSpacing':'1.05x','spaceBefore':'3pt','spaceAfter':'3pt','align':'center','firstLineIndent':'0pt','bold':str(ri==1).lower(),'keepLines':'true','keepNext':'false','color':'000000'}})
    text_log.append('[table] '+json.dumps(rows,ensure_ascii=False))
def figure(path,caption,width=14.8):
    path=Path(path);im=Image.open(path);height=width*im.height/im.width
    p('',size=10,align='center',keep=True)
    cmd({'command':'set','path':'/body/p[last()]','props':{'lineSpacing':'1x','spaceAfter':'0pt'}})
    cmd({'command':'add','parent':'/body/p[last()]','type':'picture','props':{'src':str(path),'width':f'{width}cm','height':f'{height:.4f}cm','alt':caption}})
    p(caption,size=10,align='center')
def md(text):
    """Small deterministic parser: prose, native inline/display math and tables."""
    lines=text.strip().splitlines();i=0
    while i<len(lines):
        line=lines[i].strip()
        if not line:i+=1;continue
        if line.startswith('#'):
            level=len(line)-len(line.lstrip('#'));h(line[level:].strip(),min(3,max(1,level-1)));i+=1;continue
        if line==r'\[':
            buf=[];i+=1
            while i<len(lines) and lines[i].strip()!=r'\]':buf.append(lines[i]);i+=1
            eq(' '.join(buf));i+=1;continue
        if line.startswith('|'):
            rows=[]
            while i<len(lines) and lines[i].strip().startswith('|'):
                row=[v.strip().replace('**','') for v in lines[i].strip().strip('|').split('|')]
                if not all(re.fullmatch(r'[:\- ]+',v) for v in row):rows.append(row)
                i+=1
            table(rows);continue
        buf=[line];i+=1
        while i<len(lines) and lines[i].strip() and not lines[i].lstrip().startswith(('#','|')) and lines[i].strip()!=r'\[':
            buf.append(lines[i].strip());i+=1
        p(' '.join(buf))
def section(text,start,end=None):
    t=text.split(start,1)[1];return t.split(end,1)[0].strip() if end else t.strip()
def run(args):
    rr=subprocess.run([CLI,*map(str,args)],capture_output=True,text=True,encoding='utf-8',errors='replace')
    if rr.returncode:raise RuntimeError(rr.stdout+'\n'+rr.stderr)
    return rr.stdout

def main():
    # Result prose and table/figure specification are generated from actual CSVs.
    spec=json.loads((ROOT/'analysis/paper_results.json').read_text('utf-8'))
    assert spec['raw_runs']==5640 and spec['audit_passed']
    p('面向机械约束优化的主轴投影与构型熵双锁差分进化算法','Title',17,'center',True)
    p('Principal Axis Projection and Configuration Entropy Double Locked Differential Evolution for Mechanical Constrained Optimization','Subtitle',12,'center')
    p('摘要',align='left',bold=True);p(spec['abstract_cn'],size=10.5)
    p('关键词：差分进化；演化动力学；主轴适配；有限干预；约束优化',size=10.5)
    p('Abstract',align='left',bold=True);p(spec['abstract_en'],size=10.5)
    p('Keywords: differential evolution; evolutionary dynamics; principal axis adaptation; limited intervention; constrained optimization',size=10.5)
    h('1 引言')
    intro=(OLD/'analysis/引言摘要结论修订.md').read_text('utf-8')
    intro=section(intro,'## 1 引言','## 5 结论')
    intro=intro.replace('PADE的原坐标轨道采用精英引导、归档和参数学习，其身份是JADE风格的自适应DE，不能与实验中的固定参数DE/rand/1/bin混为一谈。','PADE的原坐标轨道采用精英引导、归档和参数学习，构成JADE风格的自适应DE父算法。本文在该同父算法上进行机制归因，并设置固定参数DE/rand/1/bin经典对照。')
    intro=intro.replace('以23个标准函数考察整体性能','以23个测试问题考察整体性能').replace('评价同时保留优势与不利结果，用于界定PADE所体现的精细搜索能力及尚未消除的离散分支敏感性。','统一记录实际评价预算，进行30种子配对、嵌套全因素消融与Holm校正，用于分辨自适应父算法、主轴方向、谱尺度、脉冲和网格抖动的增量。')
    intro=intro.replace(r'z=V^{\mathsf T}(x-\bar x)',r'z=(x-\bar x)V').replace(r'x=\bar x+Vz',r'x=\bar x+zV^{\mathsf T}')
    intro=intro.replace(r'V_0\xi',r'\xi^{\mathsf T}V_0^{\mathsf T}')
    intro=intro.replace(r'u=x+M(v-x)',r'u=x+(v-x)M')
    intro=intro.replace('对收缩加权协方差进行谱分解','分解收缩加权协方差')
    md(intro)
    h('1.5 与近邻方法的区别',2)
    p('协方差学习、双坐标反馈和熵触发恢复分别已有成熟前作。CoBiDE[33]在当前较优子集协方差的特征坐标中交叉，其方法明确主要使用特征向量；ACoS[31]使用后代FIFO档案、累计协方差及逐个体坐标概率，且已将关闭坐标分支的JADE作为对照。Choi[34]以演化路径的秩一更新降低协方差学习开销。本文使用当前精英的对角收缩矩阵、额外相关门和谱比例，并将方向适配与恢复状态联系起来。')
    p('PCM-DE[35]将协方差停滞指标与方差信息扰动结合；HCDE[36]按维度的熵指标触发混合扰动和重启。PADE的具体研究对象是正则化对数体积、Deb改善停滞和FE时窗的联合门，以及低方差子空间恢复与邻网格动作。表1比较所读原始资料中的操作层次，单个概念与操作本身不独立作为首创声明。')
    p('表1 PADE与近邻工作的机制比较',size=10,align='center',keep=True)
    table(spec['literature_table'],[1300,2350,2650,2200])
    p('注：CoBiDE、ACoS和Choi依据完整方法与伪代码；PCM-DE、HCDE依据出版社摘要及章节预览，未取得的细节记为“预览未披露”。本表比较机制，不是对这五种方法完成本轮性能实测。',size=9)
    method=(ROOT/'analysis/V4方法与设置替换稿.md').read_text('utf-8')
    method=method[method.index('## 2 方法'):]
    method=method.replace('每个配置记录30次终值','每个配置记录30次终值')
    method=method.replace('本文模型严格以','本文采用Deb可行性优先规则[11]，严格以')
    method=method.replace('该收缩以当前样本的对角部分为目标','该规则借鉴线性协方差收缩思想[24]，以当前样本的对角部分为目标')
    method=method.replace('它为相关变量方向提供几何代理。','它为相关变量方向提供几何代理。收缩强度α=D/(N+D)由本文指定，未采用最优收缩强度估计器。')
    method=method.replace('采用高斯近似构型微分熵刻画','采用高斯近似构型微分熵[25]刻画')
    method=method.replace(r'完成本次可用脉冲阶段后，令\(W\leftarrow\max\{0,W-5\}\)。',r'阶段完成后更新\(W\leftarrow\max\{0,W-5\}\)。')
    method=method.replace('| 焊接梁、悬臂梁、压力容器 |','| 三项机械设计 |')
    # Captions for protocol tables are inserted in the manuscript source.
    method=method.replace('| 问题 | 种群规模N |','表2 共同函数评价预算\n\n| 问题 | 种群规模N |')
    method=method.replace('| 配置 | 几何操作 |','表3 几何与脉冲的嵌套配置\n\n| 配置 | 几何操作 |')
    methods,settings=method.split('## 3 比较实验设计',1)
    md(methods)
    figure(ROOT/'figures/00_algorithm_flow_en.png','图1 以实际函数评价为时钟的PADE执行与停止流程')
    md('## 3 比较实验设计'+settings)
    h('3.6 实现核验与执行记录',2)
    p('正式批处理采用MATLAB R2025b、6个独立进程且每进程单计算线程。实现核验覆盖精确FE停止、部分代与脉冲中止、连续和离散的同状态条件退化、随机噪声隔离及模型接口，11组诊断均通过。完整运行后独立核对所有配对初始化、预算、轨迹、网格和工程解回代，检验与审计代码随补充材料提供。')
    h('4 等评价预算结果与机制分析')
    for block in spec['results_blocks']:
        if block['type']=='heading':h(block['text'],2)
        elif block['type']=='paragraph':p(block['text'])
        elif block['type']=='equation':eq(block['formula'])
        elif block['type']=='table':p(block['caption'],size=10,align='center',keep=True);table(block['rows'],block.get('widths'));p(block.get('note',''),size=9)
        elif block['type']=='figure':figure(ROOT/block['file'],block['caption']);p(block.get('note',''),size=9)
    h('5 机械设计模型与解的复核')
    p('三个问题均为解析机械设计基准。变量、边界、单位和约束沿用作者实际运行模型，所有对照一致；工程最优行从严格可行解中按成本选取，向量以完整精度回代，显示时舍入。经典解析基准反映约束求解能力。')
    h('5.1 焊接梁',2)
    p('设计变量x=(h,l,t,b)依次为焊缝厚度、焊缝长度、矩形梁截面高度及宽度，单位in。P=6000 lbf，L=14 in，E=30×10⁶ psi，G=12×10⁶ psi；剪应力、弯曲应力、挠度上限依次为13600 psi、30000 psi、0.25 in[27,30]。目标和七项g≤0约束为')
    orig_eq(142)
    for i in range(144,151):orig_eq(i)
    p('边界为0.1≤h,b≤2，0.1≤l,t≤10。下列中间量使模型可直接复算：')
    eq(r'M=P(L+l/2),\quad R=\sqrt{l^2/4+(h+t)^2/4}')
    eq(r'J=2\sqrt{2}hl[l^2/12+(h+t)^2/4]')
    eq(r'\tau_1=P/(\sqrt{2}hl),\quad \tau_2=MR/J,\quad \tau=\sqrt{\tau_1^2+\tau_1\tau_2 l/R+\tau_2^2}')
    eq(r'\sigma=6PL/(bt^2),\quad\delta=4PL^3/(Ebt^3)')
    eq(r'P_c=4.013E\sqrt{t^2b^6/36}L^{-2}[1-t(2L)^{-1}\sqrt{E/(4G)}]')
    h('5.2 五变量悬臂梁',2)
    p('采用经典五段尺寸设计问题[1,32]，0.01≤xᵢ≤100。目标作为给定系数下的规范化质量指标；一项挠度约束包含五个尺寸的三次倒数。模型为')
    orig_eq(157);orig_eq(158)
    p('对a=(61,37,19,7,1)，拉格朗日驻点和活动约束给出已知解析最优：')
    eq(r'S=\sum_{i=1}^{5}a_i^{1/4},\quad x_i^*=S^{1/3}a_i^{1/4},\quad f^*=0.0624S^{4/3}')
    p('f*=1.3399563605990747。该值用于判断数值逼近程度，不能把报值1.339956与1.33996的不同显示位数解释为实质减重。')
    h('5.3 压力容器',2)
    p('四变量(Tₛ,Tₕ,R,L)为筒体厚度、封头厚度、内半径和圆柱段长度，单位in[28,29,32]。厚度取0.0625k、k=1,…,99，10≤R,L≤200；实际封头约束系数为0.0095。成本与约束为')
    for i in range(165,170):orig_eq(i)
    p('最低容积1296000 in³，L≤240在本边界中冗余。离散网格是该数值基准的设定；体积公式中的R为半径。不同封头系数或长度边界的文献成本只作相应条件下的参考。')
    h('5.4 最佳解及约束残差',2)
    for text in spec['engineering_prose']:p(text)
    p('表8 完整PADE的严格可行最佳设计与回代',size=10,align='center',keep=True)
    table(spec['best_design_table'],[700,4100,1500,1600])
    p('注：完整精度变量、每项约束残差与单位另见engineering_best.csv和engineering_best.json；表中向量仅为显示舍入值。CV使用原始残差正部和，严格零判定，未用容差放宽可行域。',size=9)
    h('6 讨论与结论')
    for text in spec['conclusion']:p(text)
    h('数据与代码可用性')
    p('随附补充实验包提供冻结协议、188单元配置、5640份逐次MAT运行记录、共同FE轨迹、机制计数、配对观测、精确检验及Holm结果、独立审计和完整精度工程解。MATLAB入口pade_reproduce支持恢复未完成任务及后处理；已有完成结果不会按性能选择覆盖。原始代码、v2初稿、v3修订稿及原表保留，原代数实验与本轮FE实验分开使用。')
    h('参考文献')
    for i in range(181,211):
        t=''.join(source_p[i-1].xpath('.//w:t/text()|.//m:t/text()',namespaces=NS))
        if i==188:t=t.replace('2014, 19(1)','2015, 19(1)')
        p(t,size=9.5,align='left')
    for t in json.loads((OLD/'qa/bibliography_map.json').read_text('utf-8')).get('extra_entries',[]):p(t,size=9.5,align='left')
    extras=[
    '[31] LIU Z Z, WANG Y, YANG S, et al. An adaptive framework to tune the coordinate systems in nature-inspired optimization algorithms[J]. IEEE Transactions on Cybernetics, 2019, 49(4): 1403–1416. DOI: 10.1109/TCYB.2018.2802912.',
    '[32] YANG X S, HUYCK C, KARAMANOGLU M, et al. True global optimality of the pressure vessel design problem: a benchmark for bio-inspired optimisation algorithms[J]. International Journal of Bio-Inspired Computation, 2013, 5(6): 329–335. DOI: 10.1504/IJBIC.2013.058910.',
    '[33] WANG Y, LI H X, HUANG T, et al. Differential evolution based on covariance matrix learning and bimodal distribution parameter setting[J]. Applied Soft Computing, 2014, 18: 232–247. DOI: 10.1016/j.asoc.2014.01.038.',
    '[34] CHOI T J. An efficient eigenvector-based crossover for differential evolution: Simplifying with rank-one updates[J]. AIMS Mathematics, 2025, 10(2): 3500–3522. DOI: 10.3934/math.2025162.',
    '[35] SONG Z, REN C, MENG Z. Differential evolution with perturbation mechanism and covariance matrix based stagnation indicator for numerical optimization[J]. Swarm and Evolutionary Computation, 2024, 84: 101447. DOI: 10.1016/j.swevo.2023.101447.',
    '[36] SUN L, SONG Z, LIU J, et al. Hierarchically controlled differential evolution algorithm[J]. Expert Systems with Applications, 2025, 290: 128383. DOI: 10.1016/j.eswa.2025.128383.']
    for t in extras:p(t,size=9.5,align='left')
    flush(); renumber_references()
    (DEST/'manuscript_text.txt').write_text('\n\n'.join(text_log),encoding='utf-8')
    if '--plan-only' in sys.argv:print('planned',len(segments),'segments',ntables,'tables');return
    assert not OUT.exists(),'Preserve existing v4; explicitly archive before rebuilding.'
    shutil.copy2(OLD/'PADE_Mechanical_Optimization_Full_Paper-v3.docx',OUT)
    run(['open',OUT]);run(['raw-set',OUT,'/document','--xpath','/w:document/w:body/*[not(self::w:sectPr)]','--action','remove','--json'])
    logs=[]
    for i,(kind,payload) in enumerate(segments):
        if kind=='batch':
            fp=DEST/f'batch_{i:03}.json';fp.write_text(json.dumps(payload,ensure_ascii=False),encoding='utf-8')
            msg=run(['batch',OUT,'--input',fp,'--stop-on-error','--json'])
        else:msg=run(['raw-set',OUT,'/document','--xpath','/w:document/w:body/w:sectPr','--action','insertbefore','--xml',payload,'--json'])
        logs.append({'segment':i,'kind':kind,'result':msg});print(i+1,'/',len(segments),flush=True)
    run(['save',OUT]);run(['close',OUT]);(DEST/'author_log.json').write_text(json.dumps(logs,ensure_ascii=False,indent=2),encoding='utf-8');print(OUT)

def renumber_references():
    pat=re.compile(r'\[(\d+(?:[,–—-]\d+)*)\]');refs={};used=[]
    def nums(s):
        a=[]
        for tok in s.split(','):
            ends=re.split('[–—-]',tok);a.extend(range(int(ends[0]),int(ends[-1])+1))
        return a
    for kind,payload in segments:
        if kind!='batch':continue
        for c in payload:
            if c.get('type') not in ('paragraph','run'):continue
            t=c.get('props',{}).get('text','');rm=re.match(r'^\[(\d+)\] ',t)
            if rm:refs[int(rm[1])]=copy.deepcopy(c)
            else:
                for ma in pat.finditer(t):
                    ns=nums(ma[1])
                    if 0 in ns:continue
                    for n in ns:
                        if n not in used:used.append(n)
    cmap={n:i+1 for i,n in enumerate(used)}
    for kind,payload in segments:
        if kind!='batch':continue
        payload[:]=[c for c in payload if not(c.get('type')=='paragraph' and re.match(r'^\[\d+\] ',c.get('props',{}).get('text','')))]
        for c in payload:
            if c.get('type') in ('paragraph','run'):
                s=c.get('props',{}).get('text','')
                c['props']['text']=pat.sub(lambda ma:ma[0] if 0 in nums(ma[1]) else '['+','.join(str(cmap[n]) for n in nums(ma[1]))+']',s)
    for n in used:
        c=refs[n];c['props']['text']=re.sub(r'^\[\d+\]',f'[{cmap[n]}]',c['props']['text'])
        if cmap[n]==12:c['props']['pageBreakBefore']='true'
        segments[-1][1].append(c)
    (DEST/'bibliography_map.json').write_text(json.dumps(cmap,ensure_ascii=False,indent=2),encoding='utf-8')

if __name__=='__main__':main()
