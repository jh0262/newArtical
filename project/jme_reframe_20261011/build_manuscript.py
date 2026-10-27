"""Reframe the complete manuscript from frozen evidence; never change old draft."""
from pathlib import Path
import re,json,csv,hashlib,shutil
R=Path(__file__).resolve().parent;B=R.parent;OLD=B/'jme_review_20260930_round5';D=R/'delivery';D.mkdir(exist_ok=True)
TITLE='基于梯度度量匹配的重载机器人速度历史补偿模型优化'
EN='Optimization of velocity history compensation models for a heavy-duty robot based on gradient metric matching'
old=(OLD/'delivery/论文第五轮修订稿.md').read_text(encoding='utf-8')
assert hashlib.sha256((OLD/'delivery/论文第五轮修订稿.md').read_bytes()).hexdigest()=='4d5d47997287a595fc7960186e661ebf1315fc8d0aaef2f2a0061f135d726fa0'
cases=json.loads((R/'metric_experiment/summary.json').read_text());audit=json.loads((R/'analysis/independent_audit.json').read_text());assert audit['status']=='pass'
readcsv=lambda p:list(csv.DictReader(Path(p).open(encoding='utf-8-sig')))
groups=readcsv(R/'analysis/mechanism_groups.csv');storage=readcsv(R/'analysis/storage.csv')
mx=max(c['methods']['M']['max_probe_output_difference'] for c in cases)
nmax=max(c['methods']['N']['max_probe_output_difference'] for c in cases)
raw=(R/'metric_experiment').as_posix()
def segment(start,end):return old.split(start,1)[1].split(end,1)[0].strip()

abstract=f'''针对重载机器人速度历史补偿模型构建中重复速度输入造成的参数冗余与训练尺度不一致，研究基于梯度度量匹配的模型优化方法。以固定动力学基底上的加速度拟合为目标，将重复输入支路折叠为有效参数，推导等价正则化目标及全局裁剪的参数块度量，并结合已有Adam动态等价规律保持指定训练路径。真实滞后输入予以保留，不纳入重复列折叠。三种复制次数、三种裁剪设置和三个初始化构成27组条件实验，完整匹配的固定探针最大输出差为{mx:.3e}；七次复制下参数及权重与双矩张量存储均减少5.51%。完整训练的300个检查点仍有7个超出预定浮点容限。预测用途评价中，历史差分模型相对共同初值的当前速度对照，33条同机同日轨迹的加速度归一化均方误差和0.6 s位置归一化均方根误差分别变化−1.34%和−5.16%，但一个初始化恶化，整体位置误差优于恒速外推的轨迹为0/33条。上述预测差值不归因于度量匹配。研究给出了冗余表示压缩及训练尺度保持的可核验方法，并明确了其与历史模型预测精度的区别。'''
enabstract=f'''Repeated velocity inputs in robot dynamics compensation introduce redundant parameters and alter training scales. This study optimizes the redundant representation by folding identical input columns and matching the gradient metric used for global clipping. The training objective combines acceleration fitting on a fixed physical model with coupled L2 regularization. An equivalent regularized objective is derived, and established Adam scaling rules are combined with a matched clipping metric to preserve a specified optimization path. Genuine delayed inputs are retained. A fixed-factor experiment covers three replication factors, three clipping settings, and three initializations. Across all 27 cases, the maximum output difference on a fixed training probe is {mx:.3e} for the fully matched models. Folding seven identical inputs reduces the parameter count and the combined weight and two-moment tensor storage by 5.51%. Seven of 300 checkpoints nevertheless exceed the prescribed floating-point tolerance during longer training. In a separate evaluation of predictive use on 33 same-day trajectories from one robot, the history-difference model changes acceleration normalized mean square error and 0.6 s position normalized root mean square error by −1.34% and −5.16%, respectively, relative to a current-velocity model with the same initial function. One initialization worsens both measures, and the history model outperforms constant-velocity extrapolation on 0 of 33 trajectories in the overall position measure. These prediction differences are not attributed to metric matching. The results support redundant-representation compression with preserved training scales, while distinguishing that benefit from predictive accuracy. The evidence is limited to a fixed physical model and offline-smoothed observations.'''

enabstract=enabstract.replace('A fixed-factor experiment covers','A factorial design combines').replace('on a fixed training probe','on a fixed set of training samples')
intro='''工业机器人动力学补偿通过学习物理模型的残差，为给定力矩下的运动预测提供模型基础。模型辨识与学习需要同时考虑物理结构、输入信息及参数可辨识性[1]。Retzler等[2]在重载机器人公开基准中比较物理与学习增广结构，为研究补偿输入及训练行为提供了可复核对象。激励设计[3]、负载辨识[4]和非线性摩擦参数估计[5]表明，模型精度受到数据条件与结构假设共同限制。因此，增加输入或参数后观察到的误差变化，需要与相应优化问题的变化一起解释。

速度历史具有明确的机械背景。LuGre模型采用内部动态状态描述摩擦[6]，循环网络补偿[7]、混合逆动力学学习[8]与动作条件化状态估计[9]则以时序结构表示动力学。针对低速与换向，已有研究采用转动历史编码[10]、摩擦残差适配[11]以及隐变量状态估计[12]。不过，速度历史并非摩擦状态的充分表示；Nguyen等[13]指出部分摩擦状态在仅使用运动学历史时不可唯一确定。本文研究历史输入的模型与预测作用，不将速度滞后直接解释为已辨识摩擦状态。

补偿模型优化还涉及表示与训练之间的一致性。物理结构网络[14]、惯性一致性约束[15]及增广模型正交正则化[16]分别从结构、参数与表示重叠处理这一问题。为比较速度历史模型，本文设置当前速度的等维复制输入对照。复制既不产生新的运动观测，也不增加有效函数类，却改变参数量、正则惩罚和裁剪范数。如果只统一学习率、L2系数和裁剪阈值，就可能把表示改变产生的训练差异归入历史作用。

函数保持变换已有Net2Net[17]和Network Morphism[18]等基础。Ma等[19]进一步建立覆盖Adam和耦合权重衰减的训练动态等价条件。本文沿用其尺度映射思想，将研究集中在机器人补偿中重复观测进入全局裁剪后的梯度度量，并据此实现冗余支路的参数折叠。所研究的优化，是以较少参数和优化器状态保持指定的有效目标及训练行为；并非将经验风险训练本身重新命名为新算法，也不是预设预测精度一定提高。真正不同时刻的速度输入一般不相等，不能套用重复列折叠。

训练行为保持仍不能替代机械用途评价。分段仿真辨识[20]、受约束的模型增广[21]以及神经微分方程积分研究[22,23]分别涉及拟合、状态演化和数值求解，说明点态误差与多步预测需要分别检查。本文的研究问题是：消除重复速度表示的参数冗余时，如何保持有效正则化目标和含裁剪的训练路径；在这些条件明确后，历史输入的点态作用是否转化为位置预测改善？围绕这一问题，推导折叠目标与梯度度量，给出路径保持条件和普通阈值的适用限制；以复制次数、裁剪设置和初始化构成条件实验，并测量实际张量存储；最后利用完整训练和数值核验后的轨迹预测，界定模型优化的资源收益与历史模型的预测表现。三部分证据各自回答一个问题，不把不同对照之间的变化合并为同一方法的精度收益。'''

model=segment('## 1 模型与优化对照','## 2 数据与实验设计')
model=model.replace('### 1.1 动力学接口与输入坐标','### 1.1 动力学接口与补偿模型')
anchor='### 1.2 函数折叠和Adam匹配条件'
objective=r'''### 1.2 训练目标与等价参数折叠

本文将模型优化限定为重复速度表示的冗余消除与训练尺度保持。机械结构、校准参数θ及归一化尺度固定；待优化变量ψ为六关节补偿网络的权重与偏置。设训练有效样本数为N，S_a由各轴训练加速度标准差构成，数据目标及原重复输入模型的正则化目标为

$$
J_D(\psi)=\frac{1}{6N}\sum_{i=1}^{N}\left\|S_a^{-1}\left[f_0(q_i,v_i,u_i;\theta)+M_i^{-1}r_\psi(z_i)-a_i\right]\right\|^2+\frac{\lambda}{2}\|\psi\|^2. \tag{new_objective}
$$

其中M_i=M(q_i;θ)。括号内为角加速度误差，归一化后的数据项无量纲。参数正则项作用于所采用的网络数值坐标，不具有机械能量含义。实际算法先裁剪数据梯度再加入耦合L2；因此不能将每一步解释为目标的严格下降方向，也不据训练预算结束宣称达到全局最优。

'''
model=model.replace(anchor,objective)
start='相同有效函数在重复列参数化下的最小L2惩罚缩小到1/K，因而统一学习率与统一正则系数不足以保证公平优化。'
expanded=r'''当λ>0时，固定有效列w，零和偏离Σ(w_l−w/K)=0所对应的第二项在各列相等时达到唯一最小值。以下将输入层与跳跃层的有效参数合记为w，其余网络参数记为ϑ，J_data表示式(objective)中的数据拟合项。消除零和冗余方向后，紧凑网络的等价正则化目标为

$$
J_V(w,\vartheta)=J_{\mathrm{data}}(w,\vartheta)+\frac{\lambda}{2K}\|w\|^2+\frac{\lambda}{2}\|\vartheta\|^2. \tag{new_folded}
$$

因此，折叠仅改变冗余表示，保留有效函数类及原目标关于冗余方向最小化后的值；输入与跳跃块使用λ/K，其余块仍使用λ。任意非对称列也能保持瞬时函数地折叠，但其冗余正则项和后续Adam路径一般不能仅由w恢复。真实历史差分不是同值复制，其权重自由度予以保留。六关节、首隐层100单元及线性跳跃项下，参数数目为P(K)=62412+606(K−1)，K=7时可消除3636个重复输入参数，而Hδ的66048个参数不按此式压缩。

### 1.3 梯度度量匹配与训练路径保持

相同有效函数在重复列参数化下的最小L2惩罚缩小到1/K，因而统一学习率与统一正则系数不足以保证公平优化。'''
model=model.replace(start,expanded)
model=model.replace('D_s的全局梯度范数在V_m中应写为','折叠映射w=Σw_l的转置将有效数据梯度g_w复制至每一列，故冗余坐标的欧氏范数在紧凑坐标中对应参数块度量diag(KI,I)，I为相应维数的单位阵。D_s的全局梯度范数在V_m中应写为')
marker='裁剪先乘数据梯度，再由Adam[24]加入耦合L2。'
ratio=r'''设G₀为紧凑参数普通欧氏梯度范数，ρ为输入及跳跃块占总数据梯度平方范数的比例。非零梯度满足

$$
\rho=\frac{\|g_w\|^2}{\|g_w\|^2+\|g_\vartheta\|^2},\quad \frac{G}{G_0}=\sqrt{1+(K-1)\rho},\quad 1\leq\frac{c_0}{c}\leq\sqrt K. \tag{new_ratio}
$$

其中c₀=min[1,γ/(G₀+ε_c)]，c由式(metric)给出，γ>0且ε_c≥0。全梯度为零时两个范数相同，裁剪不会改变零向量；记录时约定ρ=0。该界直接来自G₀≤G≤√K G₀与裁剪函数的分段形式，在仅一侧激活时仍成立。它定量说明普通范数可能放大施加到紧凑参数上的数据梯度，但不意味着Adam参数步长或预测误差也按同一倍数变化。

裁剪先乘数据梯度，再由Adam[24]加入耦合L2。'''
model=model.replace(marker,ratio)
model=model.replace('当K>1且两类梯度可独立变化时','当0<γ<∞、K>1且两类梯度可独立变化时')
model=model.replace('### 1.3 历史作用与预测用途的区分','''实现时，先确认输入列确为同一观测的复制，汇总输入层和跳跃层有效权重；再按式(folded)设置块正则系数，并映射学习率和矩状态；每批计算共同度量、裁剪数据梯度及更新Adam；在预定探针和完整记录上记录数值偏离。输入列不满足同值条件时保留原历史模型，不以高相关性代替严格相等。压缩收益、指定路径保持及历史预测表现分别计量。

### 1.4 历史作用与机械预测用途''')
model=model.replace('该等式说明网络并非在各轴等权拟合力矩：','该输出误差度量与式(metric)的参数梯度度量含义不同：前者由机器人逆惯性和输出尺度确定，后者由重复输入的参数映射确定，不将后者解释为惯性度量或自然梯度。该等式说明网络并非在各轴等权拟合力矩：')

design=segment('## 2 数据与实验设计','## 3 结果')
oldshort='另以同一训练数据进行裁剪条件的构造性路径核验：'
pos=design.index(oldshort);end=design.index('### 2.3',pos)
design=design[:pos]+design[end:]
design=design.replace('### 2.3 点态评价与历史供体重采样','### 2.4 点态评价与历史供体重采样').replace('### 2.4 多步评价与数值判据','### 2.5 多步评价与数值判据')
short='''### 2.3 度量条件实验与资源统计

为检验参数折叠后的训练尺度，固定K∈{1,3,7}、γ∈{1,100,不裁剪}及初始化9、19、29，构成27组条件。γ=1为主动裁剪的压力条件，γ=100沿用完整训练设置；不按评价误差选择K或γ。每组200步、批量256，基准学习率10⁻⁴，其余Adam与L2设置同2.2节。每种子以73000加初始化编号生成批次序列，所有K及裁剪条件共用。数据仅取训练有效样本，预先等距固定1024个训练探针；第1步及每10步保存探针最大输出差，全部逐步梯度、参数、矩状态与损失均保存。

每组包含重复输入参考D、完整匹配M、仅普通裁剪范数N、仅统一学习率L和仅统一L2系数R。M按式(metric)及式(adam)设置；N只将参数块范数权重K改成1，L只取消输入/跳跃块学习率的K倍映射，R只取消相应L2的1/K映射。其他条件、初值和批次保持相同。K=1时所有规则退化为同一规则；不裁剪时N应与M相同。三类失配不预设必然造成相同程度的输出偏离。

短程路径的操作性判据为所有固定探针输出绝对差≤10⁻⁹；输出是网络未还原力矩尺度的无量纲值，与加速度NMSE和位置归一化均方根误差（normalized root mean square error，NRMSE）分开。解析范数与实际范数相对残差判据为10⁻¹⁰，逐步检查式(ratio)的裁剪比界。27组共执行27000次优化器更新，无早停或检查点选择。它们检验有限条件下的机制，不替代10000步训练和整段记录评价。

资源统计直接读取最终权重及已建立的Adam一、二阶矩张量，并交叉检查完整训练保存的D_s/V_m状态。报告参数元素数及权重加双矩的实际字节数，不含梯度、激活、步号标量、序列化开销或进程内存，不据此声明运行加速。全部条件按运行前协议保存，属于同一机器人数据上的事后方法检验。

'''
design=design.replace('### 2.4 点态评价与历史供体重采样',short+'### 2.4 点态评价与历史供体重采样')

results=segment('## 3 结果','## 4 讨论')
results=results.replace('### 3.1 优化匹配在完整训练中的表现','### 3.1 完整训练的路径保持与数值偏离')
start=results.index('200步构造性路径核验中');end=results.index('![图1',start);results=results[:start]+results[end:]
table='|复制次数K|裁剪阈值|M最大差|N最大差|L最大差|R最大差|\n|---|---|---|---|---|---|\n'
for g in groups:
    table+='|'+str(g['K'])+'|'+('不裁剪' if g['gamma']=='off' else g['gamma'])+'|'+ '|'.join(f"{float(g[n+'_max_difference']):.3e}" for n in ['M','N','L','R'])+'|\n'
st='|K|折叠前参数|折叠后参数|参数减少/%|权重与双矩节省/B|\n|---|---|---|---|---|\n'
for v in storage:st+='|'+ '|'.join([v['K'],v['wide_parameters'],v['compact_parameters'],f"{float(v['parameter_reduction_percent']):.2f}",v['bytes_saved']])+'|\n'
mechanism=f'''### 3.2 梯度度量条件与模型存储

27组全部完成预定200步。完整匹配M在567个预定探针检查中均满足10⁻⁹容限，最大输出差{mx:.3e}。K=1时M、N、L、R均与参考D保持相同输出；不裁剪时，N在全部K和初始化下也通过相同容限。后者表明普通范数只有进入活跃裁剪后才产生这一条件差异，不将未激活的度量变化误判为失败。表3报告每组条件跨三个初始化和全部探针检查的最大值，完整逐初始化及末步结果保留在数据记录中。

表3 三种初始化下固定探针的最大网络输出差

{table}

全部5400条逐步记录的解析范数相对残差不超过{audit['norm_max_relative_error']:.3e}，裁剪因子比均处于[1,√K]。在相同匹配模型梯度上同时计算普通与加权范数，可直接核对这一关系，避免用已经分岔的两条路径反推同一梯度公式（图2）。N、L、R各自只改变一项条件，其输出差分别反映该固定协议下的范数、步长及正则尺度失配；不能由差值大小断言一种失配在所有训练阶段都更重要，也不能将网络输出差解释为位置精度收益。

![图2 梯度度量条件及参数资源。左图为全部条件记录在相同匹配梯度上的范数比与输入块梯度能量比例，曲线为解析关系；右图为折叠前后参数数目。重复输入压缩不作用于真实历史差分模型。](figures/fig_metric.png)

表4 实际张量统计与参数折叠收益

{st}

K=7时，参数由66048减至62412，减少3636个，占5.51%；float64权重与Adam双矩共节省87264 B，即85.22 KiB（1 KiB=1024 B）。短程实验中135个模型及优化器的实际张量统计均与P(K)一致，完整训练三组D_s/V_m保存状态也给出相同存储差。减少的是重复当前速度支路的冗余载荷，Hδ仍保留66048个参数；该5.51%不作为历史模型压缩率、进程内存降幅或运行加速率。

'''
results=results.replace('### 3.2 参照状态上的预测作用',mechanism+'### 3.3 参照状态上的预测作用').replace('### 3.3 滚动预测及其绝对用途','### 3.4 滚动预测及其绝对用途').replace('### 3.4 与原滞后坐标结果的关系','### 3.5 参数化与积分条件的敏感性')
# Renumber only old downstream tables; newly inserted tables3/4 remain fixed.
idx=results.index('### 3.3 参照状态');pre,post=results[:idx],results[idx:]
post=re.sub(r'表([345])',lambda m:'表'+str(int(m[1])+2),post)
post=re.sub(r'!\[图3[^\n]+\n\n','',post).replace('（图3）','')
results=pre+post
results=results.replace('![图2 33轨迹','![图3 33轨迹')

discussion='''本文优化的是重复速度表示的参数与训练尺度，而非直接压缩真实历史信号。折叠后的输入/跳跃块正则系数、Adam步长及全局裁剪度量必须共同匹配，才能在明确条件下保持训练路径。函数保持与Adam动态等价已有直接先例[17,18,19]；本文的有限扩展在于固定观测复制和跳跃块进入全局裁剪后的共同度量、普通常数阈值的限制及机器人训练中的可执行核验。5.51%的参数和相应张量载荷减少是可测量的资源结果，但幅度有限，不以此声称高效实时部署或提出通用新优化器。

短程机制实验和完整训练具有不同作用。复制次数、裁剪开关和单项失配用于检验条件是否必要处理，K=1及不裁剪的结果提供相应退化对照；它们既不估计泛化误差，也不取代长程有限精度检查。300个完整检查点中的7个超限说明，精确算术的归纳保持不等于实际计算的全程容限保证。完整匹配只保持指定基准的训练行为，基准预测精度低时也会保留其不足，不会因等价而自动改善。

实际历史输入的评价与上述资源优化相互衔接，但处理变量不同。Hδ/Cδ保证共同初始函数，其有效函数类、后续梯度及裁剪响应仍然不同；因此点态和位置误差的−1.34%及−5.16%仅表示固定规则下允许历史输入的平均变化，不能归因于D_s/V_m的度量匹配。D_s/V_m的33轨迹加速度NMSE为21.355270，低于Hδ的21.648953，也不支持历史模型优于全部当前输入方案。

机械解释还受误差来源限制。速度差分包含局部加速度趋势，供体重采样只能诊断冻结预测器对历史配对的依赖；与文献[13]所讨论的非唯一性一致，不能把这种依赖视为真实摩擦隐状态辨识。整体位置指标中Hδ优于恒速的轨迹为0/33条，但换向子集中有28/32条较低；这说明用途随工况而变，不能把整体负结果推广为所有区间均无历史作用。固定物理基底整体误差较大，18个摩擦系数的条件重估也不能消除全部失配；惯性、传动、输入和优化各自的物理误差尚未完整分离。

本研究使用同机同日记录、整段非因果平滑及已知未来力矩，方法设计亦参考过既有评价。新增条件实验增加的是机制覆盖，不增加独立机器人或载荷覆盖。结论限定于冗余表示、规定训练规则和离线预测，不证明跨设备推广、真实闭环稳定性或在线控制效果。'''
conclusion=f'''（1）针对速度历史补偿模型构建中的同值输入冗余，将模型优化落实为有效参数折叠与训练尺度保持。由零和参数分解得到输入/跳跃块λ/K的等价正则系数，由梯度复制映射得到K加权裁剪度量；在对称初始化及指定Adam条件下结合已有尺度规律保持训练路径。真实历史输入不执行重复列折叠。

（2）27组条件实验中，完整匹配的567个固定探针检查全部满足预定容限，最大网络输出差为{mx:.3e}；K=1及不裁剪的退化结果与理论相符。K=7时减少3636个参数及87264 B的权重与双矩张量存储，均占相应载荷的5.51%。该结果支持有限的资源优化，未证明运行加速；长程300个检查点仍有7个浮点容限失败。

（3）预测用途评价中，Hδ相对Cδ的平均点态与位置误差变化分别为−1.34%和−5.16%，但三个初始化中一个恶化，整体位置误差优于恒速外推的轨迹为0/33条。历史输入作用、重复表示优化收益及机械预测精度须分别报告，现有证据不支持将历史模型的相对改善归因于梯度度量匹配。'''

tail='## 数据与代码可用性\n\n'+segment('## 数据与代码可用性','## 参考文献')+'\n\n## 参考文献\n\n'+old.split('## 参考文献\n\n',1)[1]
t=f'# {TITLE}\n\n## 摘要\n\n{abstract}\n\n关键词：重载机器人；动力学补偿；速度历史；梯度裁剪；参数化等价性\n\n{EN}\n\n## Abstract\n\n{enabstract}\n\nKeywords: heavy-duty robot; dynamics compensation; velocity history; gradient clipping; parameterization equivalence\n\n## 0 前言\n\n{intro}\n\n## 1 补偿模型与梯度度量匹配方法\n\n{model}\n\n## 2 数据与实验设计\n\n{design}\n\n## 3 结果\n\n{results}\n\n## 4 讨论\n\n{discussion}\n\n## 5 结论\n\n{conclusion}\n\n{tail}'
t=t.replace('位置差归一化均方根误差（normalized root mean square error，NRMSE）须','位置差NRMSE须')
# Equation tags and citations into a continuous final order.
tagmap={};counter=[0]
def renumber(m):counter[0]+=1;tagmap[m[1]]=str(counter[0]);return r'\tag{'+str(counter[0])+'}'
t=re.sub(r'\\tag\{([^}]+)\}',renumber,t)
# Rewrite old references (old equations4/5/6 etc); ranges before singles.
t=re.sub(r'式\(([34567])\)(?:～\(([34567])\))?',lambda m:'式('+tagmap[m[1]]+')'+('～('+tagmap[m[2]]+')' if m[2] else ''),t)
for key,tag in [('metric','4'),('folded','new_folded'),('adam','5'),('ratio','new_ratio'),('objective','new_objective')]:t=t.replace('式('+key+')','式('+tagmap[tag]+')')
assert counter[0]==11 and not any(v in t for v in ['补充实验','追加实验','本轮实验','式(metric)'])
refs=re.findall(r'^\[(\d+)\]',t.split('## 参考文献')[1],re.M);assert len(refs)==27
assert t.split('## 参考文献')[1]==old.split('## 参考文献')[1]
(D/'论文重构修订稿.md').write_text(t,encoding='utf-8')
(D/'equation_mapping.json').write_text(json.dumps(tagmap,ensure_ascii=False,indent=2),encoding='utf-8')
fig=D/'figures';fig.mkdir(exist_ok=True)
for p in ['fig1_training.png','fig2_paired.png']:shutil.copy2(OLD/'delivery/figures'/p,fig/p)
print(json.dumps(dict(title=TITLE,characters=len(t),equations=counter[0],references=len(refs)),ensure_ascii=False))
