from pathlib import Path
import json, re, subprocess, zipfile, copy, sys
from lxml import etree as E

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT.parent/'PADE_Mechanical_Optimization_Full_Paper-v2.docx'
OUT=ROOT/'PADE_Mechanical_Optimization_Full_Paper-v3.docx'
CLI=r'C:\Users\hp\AppData\Local\OfficeCli\officecli.exe'
NS={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main','m':'http://schemas.openxmlformats.org/officeDocument/2006/math','w14':'http://schemas.microsoft.com/office/word/2010/wordml'}
with zipfile.ZipFile(SOURCE) as z: doc=E.fromstring(z.read('word/document.xml'))
original_p=doc.findall('w:body/w:p',NS)
original_t=doc.findall('w:body/w:tbl',NS)

def flatten(el):
    if E.QName(el).localname=='sSup':
        return flatten(el.find('m:e',NS))+'^'+flatten(el.find('m:sup',NS))
    if E.QName(el).localname=='sSub':
        return flatten(el.find('m:e',NS))+'_'+flatten(el.find('m:sub',NS))
    if el.tag in ('{'+NS['w']+'}t','{'+NS['m']+'}t'): return el.text or ''
    return ''.join(flatten(c) for c in el)
tables=[[[flatten(c) for c in r.findall('w:tc',NS)] for r in t.findall('w:tr',NS)] for t in original_t]

commands=[]; segments=[]; tbl_count=0; text_log=[]
def addcmd(x): commands.append(x)
def flush():
    if commands: segments.append(('batch',commands.copy()));commands.clear()
def raw(x): flush();segments.append(('raw',x))
def clean(s):
    s=re.sub(r'\*\*(.*?)\*\*',r'\1',s)
    subs={r'\operatorname{Cov}':'Cov',r'\operatorname{diag}':'diag',r'\mathrm{reg}':'reg',r'\mathsf T':'T',r'\mathsf{T}':'T',r'\mathrm T':'T',r'\bar x':'x̄',r'\Lambda':'Λ',r'\tfrac12':'½',r'\tfrac':'',r'\ln':'ln',r'\det':'det',r'\pi':'π',r'\xi':'ξ',r'\Delta':'Δ',r'\le':'≤',r'\ne':'≠',r'\in':'∈',r'\approx':'≈',r'\times':'×'}
    for a,b in subs.items(): s=s.replace(a,b)
    s=s.replace(r'\(','').replace(r'\)','').replace('{','').replace('}','')
    edits={
      '不能一概视为光滑黎曼流形。':'本文据此采用局部光滑近似。',
      '其本质是交叉对坐标表示的依赖，可表现为有效搜索受阻；并不意味着试验个体只能沿“曼哈顿折线”移动。':'其本质是交叉对坐标表示的依赖，可表现为有效搜索受阻。',
      '，不能将其称为天然各向同性':'，即差分分布已经具有样本各向异性',
      '其身份是JADE风格的自适应DE，不能与实验中的固定参数DE/rand/1/bin混为一谈。':'构成JADE风格的自适应DE基底；第3节的固定参数DE/rand/1/bin用于整体性能对照。',
      '因此，本文的切入点不是首次引入主轴或旋转，而是研究':'本文进一步研究',
      '其目的不是否定全空间重置，而是在已有统计结构仍值得利用时减少无选择的改动。':'这一设计在利用已有统计结构的同时补充新的探索方向。',
      '因此，本文的双轨机制不能概括为首次实现自适应坐标选择。其具体区别在于：':'本文进一步采用',
      '，表明“协方差识别停滞后施加扰动”也不是独有思路。':'。',
      '，而非任何单一统计量或旋转操作。':'。',
      'F15的函数身份随实际采用的常数版本标注。保留这些结果，有助于界定何种地形值得引入附加干预。':'F15采用第3.1节给定拟合数据，其运行离散性与F21共同体现方法的问题依赖性。',
      '应解释为较高精度和较小离散程度。':'体现出较高精度和较小离散程度。',
      '条件退化应解释为相应附加干预在规定条件下关闭，而非算法路径自动相同。':'相应的机制关闭区域由定理1给出。',
      '，这比笼统声称所有问题均领先更能反映方法特点。':'。',
      '注：外部结果沿用原稿汇总的文献报值':'注：外部结果采用文献报值',
      '既有回代得到目标':'显示点回代得到目标',
      '本文贡献在于通用搜索框架对活动约束边界的准确逼近和数值稳定性，而非发现新的理论最优。SCAHGM的1.33996与PADE值还存在报告位数差别，不能仅凭末位差异认定前者早熟或已获得可制造的节材收益。':'该算例体现了通用搜索框架对活动约束边界的准确逼近和数值稳定性；SCAHGM的1.33996在其报告精度下同样接近解析最优。',
      '原报告无网格抖动版本的均值为':'无网格抖动版本的均值为',
      '但该均值差并未给出离散最优命中次数，也不能据此补写成功率。':'现有统计以平均成本评价这一改进。',
      '不能由Best相当推导全面领先。':'最佳解能力和重复运行稳定性呈现不同的评价结果。',
      '图3从原工程表提取同一指标作分图比较':'图3以表3—5的目标统计作分图比较',
      '终值统计也不能代替种群可行率、熵值或门控事件记录。':'',
      '，而非继续追逐连续目标中没有工程意义的更多小数位。':'。',
      '离散抖动应解释为增加跨网格搜索机会，不能称为已消除全部网格停滞。':'离散抖动增加了跨网格搜索机会，而分支选择仍影响重复运行表现。',
      '这里是一项含五个变量三次倒数的挠度约束，并非五阶导数或五项独立挠度约束。':'模型包含一项由五个变量三次倒数组成的挠度约束。',
      't_warmup=⌊0.1Tmax⌋':'t_warmup=round(0.1Tmax)',
      '条件（c）使抖动函数直接返回':'条件（c）使抖动函数不执行任何跳步',
      '普通试验生成包含N(Tmax+1)次目标评价':'初始化及普通试验合计包含N(Tmax+1)次目标评价',
      'P=6000 lb':'P=6000 lbf',
      '连续算例已显示高度一致的目标终值，压力容器则提示，仅能偶尔找到参考最优还不足以保证每次得到同样优良的方案。':'连续算例已显示高度一致的目标终值，压力容器最好值与平均值之间的差距，使提高重复求解的稳定性成为明确改进目标。',
      '悬臂梁算例包含五个正连续变量及一项含三次倒数项的归一化挠度约束，目标为0.0624Σxᵢ；变量界限和约束公式保持原模型。':'',
      '其原坐标轨道采用':'其原坐标轨道采用',
      'Cov[F(x_r1-x_r2)]≈2F^2C':'Cov[F(xᵣ₁−xᵣ₂)]≈2F²C',
      'C_reg=VΛ V^T':'Creg=VΛVᵀ',
      'z=V^T(x-x̄)':'z=Vᵀ(x−x̄)',
      'P_0=V_0V_0^T':'P₀=V₀V₀ᵀ',
      'V_0ξ':'V₀ξ',
      'V_0':'V₀',
      'H=½ln[(2π e)^Ddet C_reg]':'H=½ln[(2πe)ᴰdet(Creg)]',
      '提出主轴映射与构型熵双锁差分进化算法':'提出主轴投影与构型熵双锁差分进化算法',
      'A principal-axis mapping and configuration-entropy double-locked DE algorithm':'A principal-axis projection and configuration-entropy double-locked DE algorithm',
    }
    for a,b in edits.items():s=s.replace(a,b)
    return s
def p(s,style='Normal',size=11,align='justify',bold=False,keep=False):
    s=clean(s); text_log.append(s)
    props={'text':s,'style':style,'size':str(size)+'pt','font':'Times New Roman','font.ea':'宋体','color':'000000','bold':str(bold).lower(),'align':align,'lineSpacing':'1.25x','spaceBefore':'0pt','spaceAfter':'5pt','firstLineIndent':'22pt' if style=='Normal' and align=='justify' else '0pt','keepNext':str(keep).lower(),'keepLines':'false'}
    addcmd({'command':'add','parent':'/body','type':'paragraph','props':props})
def h(s,level=1): p(s,'2' if level==1 else '3' if level==2 else '4',14 if level==1 else 12 if level==2 else 11,'left',True,True)
def eq(formula):
    p('',align='center',size=11)
    addcmd({'command':'add','parent':'/body/p[last()]','type':'equation','props':{'formula':formula,'mode':'inline'}})
    text_log.append('[式] '+formula)
def orig_eq(i):
    el=copy.deepcopy(original_p[i-1]);
    pp=el.find('w:pPr',NS)
    if pp is not None:
        for n in ['keepNext','pageBreakBefore']:
            for c in pp.findall('w:'+n,NS): pp.remove(c)
        sp=pp.find('w:spacing',NS)
        if sp is not None:
            for a,v in {'before':'20','after':'80','line':'300','lineRule':'auto'}.items():sp.set('{'+NS['w']+'}'+a,v)
    raw(E.tostring(el,encoding='unicode'));text_log.append('[原式] '+flatten(el))
def picture(n,width,height,caption):
    p('',align='center',size=10)
    addcmd({'command':'set','path':'/body/p[last()]','props':{'lineSpacing':'1x','spaceAfter':'0pt'}})
    addcmd({'command':'add','parent':'/body/p[last()]','type':'picture','props':{'src':str(ROOT/'figures'/f'figure{n}.png'),'width':f'{width}cm','height':f'{height}cm','alt':caption}})
    p(caption,size=10,align='center')
def table(rows,widths):
    global tbl_count
    tbl_count+=1;n=len(rows);m=len(rows[0]);base=f'/body/tbl[{tbl_count}]'
    addcmd({'command':'add','parent':'/body','type':'table','props':{'rows':str(n),'cols':str(m),'width':'100%','layout':'fixed','colWidths':','.join(str(x) for x in widths),'border.all':'single;4;D9D9D9'}})
    for ri,row in enumerate(rows,1):
        props={f'c{j}':re.sub(r'×10\^([−-]?\d+)',lambda z:'e'+z[1].replace('−','-'),str(v).replace('NaN','NA')) for j,v in enumerate(row,1)}
        if ri==1: props['header']='true'
        addcmd({'command':'set','path':base+f'/tr[{ri}]','props':props})
        for ci in range(1,m+1):
            addcmd({'command':'set','path':base+f'/tr[{ri}]/tc[{ci}]/p[1]','props':{'font':'Times New Roman','font.ea':'宋体','size':'8pt' if m>=7 else '9pt','lineSpacing':'1.05x','spaceAfter':'3pt','spaceBefore':'3pt','align':'center','firstLineIndent':'0pt','bold':str(ri==1).lower(),'keepNext':'false','keepLines':'true','color':'000000'}})
    # Make rows indivisible and set padding/header fill through one small XML fallback later.
    text_log.append('[表] '+json.dumps(rows,ensure_ascii=False))

def md_section(s,start,end): return s.split(start,1)[1].split(end,1)[0].strip()
def md_paras(s):
    return [x.strip() for x in re.split(r'\n\s*\n',s) if x.strip()]
def md_body(s):
    for para in md_paras(s):
        if para.startswith('### '):h(para[4:],2)
        elif para.startswith('## '):h(para[3:],1)
        else:p(para)

narr=(ROOT/'analysis/引言摘要结论修订.md').read_text('utf-8')
res=(ROOT/'analysis/实验与工程结果修订.md').read_text('utf-8')
cn=md_section(narr,'## 中文摘要','## English abstract')
en=md_section(narr,'## English abstract','## 1 引言')
intro=md_section(narr,'## 1 引言','## 5 结论')
concl=md_section(narr,'## 5 结论','## 创新与发表潜力评价')
for name in ['cn','en','intro','concl']:
    s=locals()[name].replace('23个标准函数','23个测试问题').replace('23 standard functions','23 test problems')
    s=s.replace('按原表判决，PADE相较固定参数DE取得15胜、6平、2负，30维函数为13胜','相较固定参数DE，PADE在15项问题上占优、2项落后、4项未检出显著差异，另2项检验未定义；30维问题的13项均占优')
    s=s.replace('the decisions reported in the original table comprise 15 wins, six ties, and two losses against fixed-parameter DE, including 13 wins on the 30-dimensional functions','PADE yields 15 favorable outcomes, two unfavorable outcomes, four nonsignificant comparisons, and two undefined tests against fixed-parameter DE; all 13 comparisons in 30 dimensions favor PADE')
    s=s.replace('按表1的判决，PADE在23个测试问题上相较固定参数DE获得15胜、6平、2负，其中30维函数为13胜','表1中，PADE相较固定参数DE在15项问题上占优、2项落后、4项未检出显著差异，另2项检验未定义；30维问题的13项均占优')
    locals()[name]=s

p('面向机械约束优化的主轴投影\v与构型熵双锁差分进化算法','Title',17,'center',True)
p('A Principal-Axis Projection and Configuration-Entropy Double-Locked Differential Evolution Algorithm for Mechanical Constrained Optimization','Subtitle',12,'center')
p('摘要',bold=True,align='left')
for x in md_paras(cn):p(x,size=10.5)
p('Abstract',bold=True,align='left')
for x in md_paras(en):p(x,size=10.5)
h('1 引言')
md_body(intro)
h('1.5 与近邻方法的机制区别',2)
p('特征坐标本身已有明确先例。CoBiDE将协方差学习与双峰参数分布相结合[33]；ACoS在原坐标与特征坐标之间进行自适应选择[31]；较新的特征向量交叉研究还通过秩一更新降低相关计算代价[34]。因此，本文的双轨机制不能概括为首次实现自适应坐标选择。其具体区别在于：采用加权精英协方差及对角目标收缩，在相关性门槛和成功反馈下启用主轴交叉，同时通过特征值比例调节各方向步长。')
p('与本文更接近的PCM-DE已经将协方差停滞指标与扰动机制结合[35]，表明“协方差识别停滞后施加扰动”也不是独有思路。2025年的HCDE也采用熵度量触发混合扰动和重启[36]。PADE进一步把正则化对数体积指标、Deb改善停滞计数及时间窗联合为触发条件，把连续脉冲限制在低方差主轴和部分个体，并将离散规格跃迁纳入同一状态控制框架。本文的创新重点是这一诊断、定向干预与可关闭机制的联动及其条件退化性质，而非任何单一统计量或旋转操作。')

h('2 PADE的机理分析与算法构建')
p('本文将四类搜索病灶具体化为坐标交叉、方向尺度、收缩停滞与离散表示的失配，并逐项建立算子联系。局部微分几何用于解释活动约束附近的切向与横向变化；群体协方差提供其经验近似。以下统一将个体写为列向量，源码中的行向量运算为等价转置实现。主轴“投影”指计算正交方向上的分量并进行全维映射，不执行非线性约束流形的最近点投影或测地线积分。')
h('2.1 自适应DE基底与约束选择',2)
p('PADE继承JADE风格的current-to-pbest/1变异、外部归档及成功参数学习[4]。令x_pbest来自排名前max(2,round(pN))的集合，p=0.15；r1来自当前种群，r2来自当前种群与归档的并集，并依源码排除重复索引。基底差分与交叉可写为')
eq(r'd_i=(x_{pbest}-x_i)+(x_{r1}-x_{r2}),\quad \widetilde u_i=x_i+F_i M_i d_i')
p('Mᵢ为二项式交叉的对角0–1掩码，至少一个维度强制取1。Fᵢ从位置参数μF、尺度0.1的柯西分布抽取至正值后截断于1；CRᵢ由均值μCR、标准差0.1的正态分布抽样并截断至[0,1]。两均值初值均为0.5，非空成功集合下按下式更新：')
eq(r'\mu_F^+=0.9\mu_F+0.1\frac{\sum_{succ} F_i^2}{\sum_{succ} F_i},\quad \mu_{CR}^+=0.9\mu_{CR}+0.1\operatorname{mean}_{succ}CR_i')
p('最终候选采用Deb可行性优先选择[11]：可行解优于不可行解；两者均可行时比较目标值；均不可行时比较总约束违反度CV。CV按各基准给定残差的正部之和计算，属于本次模型规定的数值比较量。越界变量以父代与对应边界的中点修复；指定离散维度随后按网格取整。成功候选替换父代，被替换父代进入容量为N的归档。')
p('显式精英导向分量Fᵢ(x_pbest−xᵢ)与精英方向的内积为Fᵢ‖x_pbest−xᵢ‖²≥0，构成定向推进来源。这一能力由自适应DE基底继承；随机差分、交叉和约束共同决定实际改善，不能由该内积推出全部候选必为下降方向。')
h('2.2 主轴投影与谱尺度调节',2)
h('2.2.1 加权精英协方差与收缩估计',3)
p('采用S(x)=10⁸CV(x)+f(x)排序，选取μ=max(4,⌊N/2⌋)个精英，以对数递减权重计算中心与协方差。该排序是构建样本的数值规则，个体接受仍严格使用前述Deb比较；对于任意量纲和目标尺度，它并不自动等价于Deb字典序。')
orig_eq(24);orig_eq(26)
p('式中x̄w=Σwₖxₖ且Σwₖ=1。对于高维小样本，采用借鉴线性收缩思想[24]的对角目标估计，避免把经验协方差的低秩性直接解释为真实几何维数：')
orig_eq(29);orig_eq(31)
p('其中T=diag(Csample)，ε=10⁻¹²，α=D/(N+D)。该维数相关强度为本文给定规则，未采用Ledoit–Wolf最优收缩强度估计器。对角目标保留各变量样本方差并减弱非对角项；其效果依赖变量尺度和坐标表示。')
h('2.2.2 交叉的坐标失配及主轴表达',3)
p('设局部走廊法向为n，差分方向d满足nᵀd=0。原坐标交叉一般仍有nᵀMd≠0；即便差向量沿通道，掩码也可能产生法向分量。这说明逐维交叉对坐标表示的依赖，是本文所指的几何交叉病灶。令正则化协方差谱分解为')
orig_eq(35)
p('Λ=diag(λ₁,…,λD)，λ₁≥…≥λD>0，V的列为正交特征向量。z=Vᵀ(x−x̄w)为主轴分量，x=x̄w+Vz为逆映射。若经验主轴与局部切向、法向子空间对齐，在该坐标内实施掩码不会混合两个子空间；实际对齐程度由样本决定。')
h('2.2.3 方向尺度调节与双轨门控',3)
p('DE差分本身继承种群各向异性，标量F的限制在于无法独立改变各方向的相对尺度。本文引入S=diag(s₁,…,sD)，在经验主轴中补充方向调节自由度：')
orig_eq(38)
p('取γ=0.25，最大方差方向s₁=1，较小方差方向0<sⱼ≤1。该规则收缩相对狭窄方向，不把协方差特征值直接当作Hessian特征值或真实主曲率。主轴候选与当前坐标下的相关指标为')
eq(r'\widetilde u_i^{rot}=x_i+F_i V M_i S V^T d_i')
orig_eq(90)
p('ρ为非对角Frobenius范数与总范数之比，分母附加10⁻¹⁴。仅当t>t_warmup、ρ>0.20且均匀随机数小于P_rot时启用主轴分支，否则使用原坐标基底。P_rot初值0.2，有主轴尝试时以0.9P_rot+0.1r_rot更新，r_rot为主轴尝试的接受比例，再截断于[0.05,0.85]。这一状态门与成功反馈共同避免无条件全量旋转。')
h('2.3 构型熵与停滞双锁',2)
p('差分信息的收缩可能削弱后续搜索，但贪婪选择并不保证协方差行列式逐代下降。为同时观察分布尺度与实际进展，以高斯近似下的构型微分熵作为体积代理[25]：')
orig_eq(43);orig_eq(45)
p('式中ε₀=10⁻²⁵。固定变量单位和坐标后，H的变化用于比较样本分布尺度，不表示机械系统的热力学熵或能量。实现中H₀由初始全种群协方差加10⁻¹²I计算，后续H由加权精英收缩矩阵计算；阈值含样本规则的变化，按下式作为经验触发量使用：')
orig_eq(48)
p('取βcrit=2.8。W在每代开始依据记录最优解是否按Deb规则改善而清零或递增，包括不可行阶段违反度的改善：')
eq(r'W_t=0\quad\mathrm{if\ DebImproved};\qquad W_t=W_{t-1}+1\quad\mathrm{otherwise}')
eq(r'\Phi_{lock}(t)=I(t_{warmup}<t<0.9T_{max})I(H_t\le H_{crit},W_t\ge W_{max})')
p('I表示括号内条件同时成立时取1、否则取0。t_warmup=round(0.1Tmax)，Wmax=15。双锁要求熵低于阈值且连续停滞，时间窗另限制脉冲只在冷启动后至总代数前90%可用。仍有微小Deb改善时，停滞锁保持关闭；这限制脉冲干预，不意味着所有其他附加算子也同时关闭。')
h('2.4 低方差子空间脉冲与离散跃迁',2)
h('2.4.1 子空间选择及连续脉冲',3)
orig_eq(63)
p('将该索引集记为𝒩，其补集记为𝒜，V𝒩与V𝒜分别由对应主轴组成。正则化后不存在严格的代数零特征值，故称低方差子空间。其投影矩阵为P𝒩=V𝒩V𝒩ᵀ，且ℝᴰ=span(V𝒜)⊕span(V𝒩)。双锁开启且𝒩非空时，对排名末尾max(1,round(0.2N))个体提出')
eq(r'y=x_{best}+\sigma V_{\mathcal N}\xi,\quad \xi\sim N(0,I),\quad \sigma=0.15\sqrt{\lambda_{max}}')
eq(r'V_{\mathcal A}^T(y-x_{best})=0')
p('该恒等式说明连续脉冲保留的是参考最优点在互补主轴上的投影，保持已有统计方向结构；不是冻结被替换个体的坐标，也不直接证明承载能力不变。混合离散问题还对指定离散维度提出一步±hⱼ的调整，随后裁剪边界并投影到网格，再经Deb比较决定接受。离散调整和边界修复后不一般继续满足上述正交恒等式。执行一次脉冲批次后，W减5并下限截断于0。')
h('2.4.2 连续小步的取整冻结与邻域抖动',3)
p('当当前离散坐标xⱼ=khⱼ且连续增量绝对值小于hⱼ/2时，最近取整会返回原规格。为提供独立于剩余差分幅度的相邻规格提案，采用')
orig_eq(78)
p('pⱼ(t)=0.25min(1,W/max(1,Wmax))。源码在无离散变量或pⱼ≤0.02时直接返回；否则每个指定离散维度以该概率选择±hⱼ，边界内裁剪并再次网格化。此机制提供非零跨格机会，可行性和改进性由后续评价与选择决定。连续尺度收缩与离散邻域跃迁因而由不同但相互衔接的机制处理。')
h('2.5 有限干预与条件退化定理',2)
p('定义G₀为关闭主轴分支、脉冲和抖动后的自适应DE基底，保留current-to-pbest/1、归档、F/CR学习、边界修复、离散投影及Deb选择。它属于DE算法族，但不同于第3节用作实验对照的固定参数DE/rand/1/bin。条件退化的目标是严格恢复实际继承基底的转移规则。')
p('令𝒮t包含本代停滞更新后、脉冲前的种群、目标和违反度、归档、最优记录、学习参数及停滞记录；ω表示匹配的索引、参数、掩码和归档替换随机量。记B为越界中点修复，Q为离散投影，则基底候选可写为')
eq(r'G_{0,i}(\mathcal S_t,\omega)=Q\left[Q\left[B_{x_i}(x_i+F_iM_id_i)\right]\right]')
p('两个Q保留源码抖动前后的执行顺序；对于本文边界与网格对齐的压力容器变量，Q²=Q。完整PADE包含变异前脉冲、候选变换与修复后抖动，应视为顺序复合映射。令Δᵢ=GPADE,ᵢ−G₀,ᵢ；修复后两候选均在设计盒中，故‖Δᵢ‖₂≤‖ub−lb‖₂，但原始高斯脉冲没有确定的有限幅值上界。')
p('定理1 状态门控下的精确条件退化。对相同输入状态𝒮t及匹配随机驱动ω，若本代同时满足下列三项，则PADE与G₀的全部候选、Deb选择、归档及继承参数更新相同。',bold=True)
p('（a）主轴门关闭：t≤t_warmup或ρt≤0.20。\n（b）脉冲门关闭：t≤t_warmup、t≥0.9Tmax、Ht>Hcrit、Wt<Wmax或𝒩为空，至少一项成立。\n（c）抖动门关闭：不存在离散变量，或pⱼ(t)≤0.02。')
p('证明。条件（b）排除变异前的脉冲和相应W回调，保证进入个体循环时状态一致。条件（a）使每个个体均执行原坐标分支，同一参数、索引和掩码产生同一xᵢ+FᵢMᵢdᵢ；此处无需假定V=I或所有谱尺度均为1。相同边界修复及离散投影产生相同中间候选，条件（c）使抖动函数直接返回。按个体顺序归纳，相同候选产生相同评价和选择，匹配归档替换随机量保持归档一致，成功参数集合亦相同，故代末继承参数更新一致。证毕。')
p('ρt≤0.20且Wt=0是同时适用于连续和混合离散问题的可核验充分条件；纯连续问题可放宽为ρt≤0.20且Wt<Wmax。如果初态相同、采用共同随机驱动且条件各代持续成立，由代际归纳得到同轨迹。只在某一代满足条件，则只能保证从该相同状态出发的一代转移相同，不能消除之前干预造成的状态差异；相同随机种子也不足以替代分支随机消耗的匹配条件。')
p('有限干预具体体现在触发时段、作用个体、作用子空间与概率四个方面。对一次候选生成，比较同一个体循环入口完整状态𝒮t,ᵢ上的两映射；设脉冲关闭、离散维数为m，aₜ为主轴状态门可用的0–1指标，qₜ=pⱼ(t)·1[pⱼ(t)>0.02]，则在共同随机耦合下由并集界可得')
eq(r'\Pr(G_{PADE,i}\ne G_{0,i}\mid\mathcal S_{t,i})\le\min(1,a_tP_{rot}(t)+m q_t)')
p('该上界描述附加机制改变候选的机会。本文的理论性质是明确状态区域中的精确回退及修复后候选的有限偏离，不要求原始高斯幅值有界，也不据此推出无条件渐近收敛或普遍性能优越。')
h('2.6 执行流程与计算代价',2)
p('图1给出顺序流程。先初始化并评价，计算H₀和阈值；每代更新W、精英矩阵、谱和Ht，按双锁对部分个体提出低方差脉冲；随后逐个体采样F、CR及索引，选择主轴或原坐标轨道，依次完成修复、网格投影、抖动和再投影；评价后按Deb规则选择并更新归档，代末更新参数和主轴概率。停止时输出最优设计、目标、违反度及运行历史。')
picture(1,14.8,12.9753,'图1 PADE的状态诊断、定向干预与候选选择流程')
p('每代精英协方差构建约需O(ND²)，完整特征分解约需O(D³)，个体主轴变换最多O(ND²)，其余搜索操作主要为O(ND)。相同种群和代数下，普通试验生成包含N(Tmax+1)次目标评价；若共执行K次脉冲批次，额外评价数为K·max(1,round(0.2N))。因此，本文实验设置为同种群、同最大代数，不能仅据此称为严格相同目标评价次数。')

h('3 基准函数测试与性能分析')
# Reuse the independently edited results prose section by section, inserting native tables.
def rsection(start,end): return md_section(res,start,end)
h('3.1 测试设置与比较目的',2)
s=rsection('#### 3.1','#### 3.2').split('\n\n',1)[1]
for x in md_paras(s):p(x)
p('F15按实际运行常数标为“Kowalik型拟合（本文数据）”，其a向量为(0.1957,0.1947,0.1735,0.1600,0.1472,0.1392,0.1320,0.1287,0.1235,0.1190,0.1180)，b向量为(4,2,1,1/2,1/4,1/6,1/8,1/10,1/12,1/14,1/16)。其目标为各数据点拟合残差的平方和，具体表达式见随文Benchmark_23_Functions.m。该版本不与其他Kowalik常数版本的理论极值混用。F7含随机噪声，其Std同时反映运行与随机评价波动。')
p('显著性水平为0.05。表1保留原报告的p值，并按提供实现中的双尾Wilcoxon秩和检验命名；“+”表示原报告PADE占优，“−”表示DE占优，“=”表示未检出显著差异，NA表示检验未定义。Best、Mean与Std均为最小化目标统计；完整原始表值另随数据表提供。')
h('3.2 全部问题的终值结果',2)
s=rsection('#### 3.2','#### 3.3').split('\n\n',1)[1]
s=s.replace('按原表判决口径，PADE相对固定参数DE为15胜、6平、2负，其中F1—F13均归为PADE占优。','按有效检验分类，PADE相对固定参数DE为15项占优、2项落后、4项未检出显著差异，另2项检验未定义，其中F1—F13均归为PADE占优。').replace('此处“平”是原表分类，不表示算法等价；F17、F19的p值为NaN，应另注“检验未获得有效结果”，不能据此作显著性或等价判断。','F17、F19的原报告p值为NaN，表中记为NA；未显著和未定义均不表示算法等价。')
p(md_paras(s)[0])
p('表1 23个测试问题的30次运行统计及原报告检验结果',size=10,align='center',keep=True)
rows=[['问题','D','PADE Mean','PADE Std','DE Mean','DE Std','p值','判决']]
for i,r in enumerate(tables[0][1:],1):
    rows.append([f'F{i}',r[2],r[4],r[5],r[7],r[8],r[9],'NA' if r[9]=='NaN' else r[10]])
table(rows,[540,390,1360,1070,1290,1070,1300,510])
p('注：e表示10的幂，Mean和Std沿用原运行报值；各函数名称与Best完整值见附表CSV。F15使用本文拟合数据版本。NA共2项，未并入未显著比较。',size=9)
for x in md_paras(s)[1:]:p(x)
h('3.3 典型地形的终值统计与机制解释',2)
s=rsection('#### 3.3','#### 3.4').split('\n\n',1)[1]
for x in md_paras(s):p(x)
picture(2,14.8,9.0444,'图2 六个代表性问题的30次运行平均终值比较')
p('注：数据取自表1，正值函数采用对数纵轴，负值函数采用线性纵轴；各项Best及Std见附表。本图显示终值统计。',size=9)
h('3.4 文献报值的横向参照',2)
s=rsection('#### 3.4','### 4 典型').split('\n\n',1)[1]
p(md_paras(s)[0])
p('表2 代表性函数的文献均值参照',size=10,align='center',keep=True)
rt=copy.deepcopy(tables[1]);rt[0]=['问题','参考极值','SCA','GWO','HPSO','SCAHGM','PADE']
for row,fi in zip(rt[1:],[1,5,8,9,11,12,13,20,23]):row[0]=f'F{fi}'
table(rt,[550,1100,1100,1100,1100,1300,1280])
p('注：外部结果沿用原稿汇总的文献报值[1,13–15]，用于性能位置参照；各研究的预算及模型版本不据本表自动视为相同。',size=9)
for x in md_paras(s)[1:]:p(x)

h('4 典型机械结构约束优化算例')
p('采用三个经典解析设计基准，分别覆盖耦合连续约束、已知解析最优边界和混合离散规格。工程代码设N=40、Tmax=2500，各算例运行30次；以下保留实际运行统计，文献行沿用来源报值。长度、载荷、应力的基准单位按模型给定，成本系数携带相应组合单位，不在不同单位制间直接套用。')
h('4.1 焊接梁制造成本优化',2)
p('设计变量x=(h,l,t,b)，分别为焊缝厚度、焊缝长度、梁截面高度及宽度。采用英制基准：P=6000 lb，L=14 in，E=30×10⁶ psi，G=12×10⁶ psi，允许剪应力13600 psi、弯曲应力30000 psi及挠度0.25 in[27,30]。')
orig_eq(142)
p('约束gₖ≤0为下列七项，其中包括应力、挠度、屈曲及几何和成本限制：')
for i in range(144,151):orig_eq(i)
p('0.1≤h,b≤2，0.1≤l,t≤10，单位均为in。为使力学模型可复算，所用中间量为')
eq(r'M=P(L+l/2),\quad R=\sqrt{l^2/4+(h+t)^2/4}')
eq(r'J=2\sqrt{2}hl[l^2/12+(h+t)^2/4]')
eq(r'\tau_1=\frac{P}{\sqrt{2}hl},\quad\tau_2=\frac{MR}{J},\quad\tau=\sqrt{\tau_1^2+\tau_1\tau_2 l/R+\tau_2^2}')
eq(r'\sigma=\frac{6PL}{bt^2},\quad\delta=\frac{4PL^3}{Ebt^3}')
eq(r'P_c=\frac{4.013E\sqrt{t^2b^6/36}}{L^2}\left(1-\frac{t}{2L}\sqrt{\frac{E}{4G}}\right)')
s=rsection('#### 4.1','#### 4.2').split('\n\n',1)[1]
for x in md_paras(s)[1:]:p(x.replace('既有回代对该显示点得到CV=0，且','显示点回代满足约束，且'))
p('表3 焊接梁目标统计与文献参照',size=10,align='center',keep=True)
rows=[['算法','Best','Mean','Std']]
for r in tables[2][1:]:rows.append([r[0],r[5],r[6],r[7]])
table(rows,[3400,1400,1500,1230])
p('注：PADE设计向量按六位小数显示，目标统计采用未舍入运行报值；文献设计向量与完整原表保存在随附数据中，文献成本采用来源报告值。',size=9)
h('4.2 悬臂梁规范化质量指标优化',2)
p('采用五段悬臂梁解析设计基准[1,32]，五个正连续尺寸为x₁,…,x₅，质量型目标与归一化挠度约束为')
orig_eq(157);orig_eq(158)
p('变量界限0.01≤xᵢ≤100，i=1,…,5。系数0.0624及各约束系数按给定基准使用，未给定其完整物理单位换算时，以规范化质量指标解释目标。这里是一项含五个变量三次倒数的挠度约束，并非五阶导数或五项独立挠度约束。')
s=rsection('#### 4.2','#### 4.3').split('\n\n',1)[1]
for x in md_paras(s):
    if 'S=Σaᵢ¹ᐟ⁴' in x:
        p(clean(x).split('令a=')[0])
        eq(r'a=(61,37,19,7,1),\quad S=\sum_{i=1}^{5}a_i^{1/4}')
        eq(r'x_i^*=S^{1/3}a_i^{1/4},\quad f^*=0.0624S^{4/3}\approx1.3399563605990747')
    else:p(x)
p('表4 悬臂梁目标值及PADE重复运行稳定性',size=10,align='center',keep=True)
rows=[['算法','目标值','原报告稳定性']]
for r in tables[3][1:]:rows.append([r[0],r[6],r[7] if 'PADE' in r[0] else '未列定量统计'])
table(rows,[3300,1600,2630])
p('注：来源目标按其报告位数保留；不同显示位数不构成制造收益。外部设计向量保存在附表，主表仅比较报值。',size=9)
h('4.3 压力容器混合整数成本优化',2)
p('四变量为筒体厚度Tₛ、封头厚度Tₕ、内半径R和圆柱段长度L，单位为in[1,28–29]。两项厚度按本基准取0.0625 in的整数倍；R、L连续。采用实际运行的封头系数0.0095，模型为')
for i in range(165,170):orig_eq(i)
p('Tₛ,Tₕ∈{0.0625k:k=1,…,99}，10≤R,L≤200。由于L上界已为200，L≤240在本域中冗余。体积式πR²L+4πR³/3对应半径定义，最低容积为1296000 in³。离散规格与系数均为本次数值基准设定，不泛化为规范对所有容器的统一制造要求。')
s=rsection('#### 4.3','#### 4.4').split('\n\n',1)[1]
for x in md_paras(s)[1:]:p(x)
p('表5 压力容器的运行统计与文献参照',size=10,align='center',keep=True)
rows=[['算法','Best','Mean','Worst','Std']]
for r in tables[4][1:]: rows.append(r[:5])
table(rows,[2750,1260,1260,1260,1000])
p('注：文献可能采用不同封头系数或变量边界，表中沿用原报告成本，不据其Best相近推断模型及全体运行状态完全相同。',size=9)
h('4.4 工程目标统计与结果综合',2)
s=rsection('#### 4.4','## 表格处理映射').split('\n\n',1)[1]
for x in md_paras(s):p(x)
picture(3,14.8,7.94146,'图3 三个结构设计基准的同指标目标统计比较')
p('注：数据取自表3—5；焊接梁与悬臂梁比较Best，压力容器比较Mean，误差棒为原报告Std，不表示置信区间。',size=9)
h('5 结论')
for x in md_paras(concl):p(x)
h('参考文献')
for i in range(181,211):
    s=flatten(original_p[i-1])
    if i==188:s=s.replace('2014, 19(1)','2015, 19(1)')
    p(s,size=9.5,align='left')
for s in [
 '[31] LIU Z Z, WANG Y, YANG S, et al. An adaptive framework to tune the coordinate systems in nature-inspired optimization algorithms[J]. IEEE Transactions on Cybernetics, 2019, 49(4): 1403–1416. DOI: 10.1109/TCYB.2018.2802912.',
 '[32] YANG X S, HUYCK C, KARAMANOGLU M, et al. True global optimality of the pressure vessel design problem: a benchmark for bio-inspired optimisation algorithms[J]. International Journal of Bio-Inspired Computation, 2013, 5(6): 329–335. DOI: 10.1504/IJBIC.2013.058910.',
 '[33] WANG Y, LI H X, HUANG T, et al. Differential evolution based on covariance matrix learning and bimodal distribution parameter setting[J]. Applied Soft Computing, 2014, 18: 232–247. DOI: 10.1016/j.asoc.2014.01.038.',
 '[34] CHOI T J. An efficient eigenvector-based crossover for differential evolution: Simplifying with rank-one updates[J]. AIMS Mathematics, 2025, 10(2): 3500–3522. DOI: 10.3934/math.2025162.',
 '[35] SONG Z, REN C, MENG Z. Differential evolution with perturbation mechanism and covariance matrix based stagnation indicator for numerical optimization[J]. Swarm and Evolutionary Computation, 2024, 84: 101447. DOI: 10.1016/j.swevo.2023.101447.',
 '[36] SUN L, SONG Z, LIU J, et al. Hierarchically controlled differential evolution algorithm[J]. Expert Systems with Applications, 2025, 290: 128383. DOI: 10.1016/j.eswa.2025.128383.'
]:p(s,size=9.5,align='left')
flush()
def citation_numbers(s):
    out=[]
    for token in s.split(','):
        ends=re.split('[–—-]',token)
        out.extend(range(int(ends[0]),int(ends[-1])+1))
    return out
ref_pattern=re.compile(r'\[(\d+(?:[,–—-]\d+)*)\]')
refs={};used=[]
for kind,payload in segments:
    if kind!='batch':continue
    for cmd in payload:
        if cmd.get('type')!='paragraph':continue
        s=cmd.get('props',{}).get('text','')
        rm=re.match(r'^\[(\d+)\] ',s)
        if rm:refs[int(rm[1])]=copy.deepcopy(cmd)
        else:
            for ma in ref_pattern.finditer(s):
                if 0 in citation_numbers(ma[1]):continue
                for num in citation_numbers(ma[1]):
                    if num not in used:used.append(num)
cmap={x:i+1 for i,x in enumerate(used)}
for kind,payload in segments:
    if kind!='batch':continue
    payload[:]=[c for c in payload if not(c.get('type')=='paragraph' and re.match(r'^\[\d+\] ',c.get('props',{}).get('text','')))]
    for c in payload:
        if c.get('type')=='paragraph':
            s=c.get('props',{}).get('text','')
            c['props']['text']=ref_pattern.sub(lambda ma:ma[0] if 0 in citation_numbers(ma[1]) else '['+','.join(str(x) for x in sorted(cmap[n] for n in citation_numbers(ma[1])))+']',s)
for old in used:
    c=refs[old];c['props']['text']=re.sub(r'^\[\d+\]',f'[{cmap[old]}]',c['props']['text']);segments[-1][1].append(c)
(ROOT/'qa/bibliography_map.json').write_text(json.dumps({'old_to_new':cmap,'removed_uncited':sorted(set(refs)-set(used))},ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'analysis/manuscript_text.txt').write_text('\n\n'.join(text_log),encoding='utf-8')

def run(args):
    r=subprocess.run([CLI,*map(str,args)],capture_output=True,text=True,encoding='utf-8',errors='replace')
    if r.returncode: raise RuntimeError(r.stdout+'\n'+r.stderr)
    return r.stdout
if __name__=='__main__':
    if '--plan-only' in sys.argv:
        print('segments',len(segments),'blocks',len(text_log));sys.exit()
    run(['raw-set',OUT,'/document','--xpath','/w:document/w:body/*[not(self::w:sectPr)]','--action','remove','--json'])
    logs=[]
    for i,(kind,payload) in enumerate(segments):
        if kind=='batch':
            f=ROOT/'analysis'/f'author_batch_{i:03}.json';f.write_text(json.dumps(payload,ensure_ascii=False),encoding='utf-8')
            msg=run(['batch',OUT,'--input',f,'--stop-on-error','--json'])
        else:
            msg=run(['raw-set',OUT,'/document','--xpath','/w:document/w:body/w:sectPr','--action','insertbefore','--xml',payload,'--json'])
        logs.append({'segment':i,'kind':kind,'result':msg})
        print(f'{i+1}/{len(segments)} {kind}',flush=True)
    run(['set',OUT,'/header[1]/p[1]','--prop','text=PADE主轴投影与构型熵双锁差分进化算法','--prop','size=9pt','--prop','color=000000','--prop','align=center'])
    run(['save',OUT]);run(['close',OUT])
    (ROOT/'qa/authoring_log.json').write_text(json.dumps(logs,ensure_ascii=False,indent=2),encoding='utf-8')
    print(OUT)
