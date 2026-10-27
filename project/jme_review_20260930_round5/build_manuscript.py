"""Assemble an evidence-linked manuscript only after all fixed evaluations complete."""
from pathlib import Path
import json,re,shutil
from train_controlled import R,B,dump,sha
import numpy as np
OLD=B/'jme_review_20260930_round4';D=R/'delivery'
def f(x,d=6):return f'{x:.{d}f}'
def table(head,rows):return '|'+ '|'.join(head)+'|\n|'+ '|'.join(['---']*len(head))+'|\n'+'\n'.join('|'+ '|'.join(str(v) for v in r)+'|' for r in rows)
def main():
 S=json.loads((R/'analysis/summary.json').read_text());assert 'pointwise' in S and 'rollout' in S
 SE=S['seed_effects'];seed_point='、'.join(f"{v['pointwise_change_percent']:+.2f}%" for v in SE);seed_roll='、'.join(f"{v['rollout_change_percent']:+.2f}%" for v in SE)
 clipcheck=json.loads((R/'analysis/clipping_control_audit.json').read_text());assert clipcheck['status']=='pass'
 for name,hash_value in clipcheck['inputs'].items():assert sha(name)==hash_value,name
 clipcases={v['case']:v for v in clipcheck['cases']}
 D.mkdir(exist_ok=True)
 pt=lambda model,group='peer',which='best':next(r for r in S['pointwise'] if (r['model'],r['group'],r['checkpoint'])==(model,group,which))
 rl=lambda model,group='peer',regime='all':next(r for r in S['rollout'] if (r['model'],r['group'],r['regime'])==(model,group,regime))['nrmse']
 c=pt('Cdelta')['nmse'];h=pt('Hdelta')['nmse'];gain=100*(1-h/c);rgain=100*(1-rl('Hdelta')/rl('Cdelta'))
 pr=[r for r in S['pointwise_per_record'] if r['record'].startswith('peer')];pb=sum(r['H_nmse']<r['C_nmse']-1e-12 for r in pr);pg=100*(np.mean([r['resampled_common_nmse'] for r in pr])/np.mean([r['true_common_nmse'] for r in pr])-1)
 rr=S['rollout_per_record'];get=lambda rec,m:next(r['nrmse'] for r in rr if r['record']==rec and r['model']==m and r['regime']=='all');rb=sum(get(i,'Hdelta')<get(i,'Cdelta')-1e-12 for i in range(1,34));cb=sum(get(i,'Hdelta')<get(i,'constant_velocity')-1e-12 for i in range(1,34))
 EQ=S['training_equivalence'];fail=sum(len(r['failed_checkpoints']) for r in EQ);mx=max(r['max_scaled_acc_difference'] for r in EQ);selmx=max(r['selected_max_scaled_acc_difference'] for r in EQ)
 checks=S['numerical_checks'];numfail=sum(len(r['initial_failed_indices']) for r in checks);finefail=sum(len(r['fine_check']['remaining_failed_indices']) for r in checks if r['fine_check']);cov=[r['coverage'] for r in S['resampling_coverage'] if r['record'].startswith('peer')]
 numtext=(f'初始有{numfail}项未通过，按固定规则对失败窗口作局部细化后仍有{finefail}项未通过。主表保留原较严容限结果，局部细化结果单独报告。' if numfail else '1836项均通过预定判据，未触发进一步细化；采用较严容限结果统计位置性能。')
 reversal_count=next(r['records'] for r in S['rollout'] if (r['model'],r['group'],r['regime'])==('Hdelta','peer','reversal'))
 rev=lambda i,m:next(r['nrmse'] for r in rr if r['record']==i and r['model']==m and r['regime']=='reversal')
 reversal_beats_cv=sum(rev(i,'Hdelta') is not None and rev(i,'Hdelta')<rev(i,'constant_velocity')-1e-12 for i in range(1,34))
 text=f'''# 重载机器人速度历史补偿的优化对照研究

## 摘要

针对机器人速度历史补偿中参数化改变与历史输入作用难以区分的问题，建立优化匹配和共同初始函数两类对照。在已有动态等价规律基础上，给出重复输入的共同裁剪度量及普通单一阈值的适用限制，在当前速度与历史差分坐标下比较加速度预测、历史供体重采样及0.6 s位置预测。12个模型均完成10000次更新，三个优化匹配配对的选定检查点满足输出容限，长程训练有{fail}/300个检查点超限。33条同机同日轨迹的事后评价中，历史模型加速度归一化均方误差相对当前速度对照降低{gain:.2f}%，但仍远高于训练均值基准；位置归一化均方根误差变化为{-rgain:+.2f}%，低于恒速外推的轨迹为{cb}/33条，三个初始化中一个在点态和位置指标上均恶化。结果表明，相同初始函数下的点态历史作用仍须与滚动预测用途分别检验。证据限定于固定物理基底及离线平滑记录，不构成摩擦机理辨识或跨载荷推广依据。

关键词：工业机器人；动力学补偿；速度历史；优化对照；多步预测

Optimization controls for velocity history compensation in a heavy-duty robot

## Abstract

This study assesses velocity history in robot dynamics augmentation using two controls: matched optimization and an identical initial prediction function. Building on established dynamic equivalence, the study derives a shared clipping metric for repeated inputs and shows why an ordinary single threshold cannot generally replace it. Pointwise acceleration, resampling of history among donors with similar current velocity, and 0.6 s position prediction are evaluated separately. Twelve models each complete 10,000 updates. All three selected optimization pairs meet the prescribed output tolerance, although {fail} of 300 checkpoints violate it during extended training. In a post-hoc evaluation on 33 trajectories from the same robot and acquisition date, history differences reduce acceleration normalized mean square error by {gain:.2f}% relative to the current-velocity control, while remaining substantially worse than the training-mean baseline. Position normalized root mean square error changes by {-rgain:+.2f}%; the history model outperforms constant-velocity extrapolation on {cb} trajectories. One of three initializations worsens both pointwise and position errors. Pointwise effects therefore require a separate assessment of multistep prediction. The results concern a fixed physical base and offline-smoothed records, and do not identify friction or establish generalization across payloads.

Keywords: industrial robot; dynamics augmentation; velocity history; optimization control; multistep prediction

## 0 前言

工业机器人动力学学习既服务于力矩计算，也服务于给定输入下的状态预测。模型与数据结合能够减少部分建模误差，但预测改善并不自动说明未建模机理已被识别[1]。Retzler等[2]在公开重载机器人基准上比较了多种物理与学习增广结构；激励设计[3]、负载辨识[4]与非线性摩擦参数估计[5]则说明，输入条件和物理参数的可辨识性决定了误差可被怎样解释。

历史特征的机械背景包括摩擦内部状态与迟滞。LuGre模型显式引入内部动态状态[6]；循环网络动力学补偿[7]、物理一致混合逆动力学[8]及动作条件化状态估计[9]也已利用时序结构。Çallar等[10]针对低速、频繁换向运动设计转动历史编码，Scholl等[11]研究新摩擦条件下的残差适配，Vantilborgh等[12]以隐变量处理摩擦状态。上述工作建立了历史建模的技术基础，但其力矩识别或控制结果不能直接替代另一机器人的位置预测评价。

输入选择还受物理可辨识性约束。Nguyen等[24]在解析摩擦模型生成的数据上指出，仅有运动学历史不足以唯一确定部分摩擦状态，并研究了力与速度历史的联合输入。本文不把有限速度滞后视为摩擦状态的充分表示，而是考察这些输入在给定学习规则下对不同预测量的作用。

物理结构网络[13]、惯性物理一致性约束[14]和模型增广正交正则化[15]分别处理结构先验、参数可行性与表示重叠。把相同当前速度重复七次，可增加网络参数并改变正则化与更新尺度，却不增加历史信息。Net2Net[25]与Network Morphism[26]研究了函数保持变换；Ma等[27]进一步给出覆盖Adam及耦合权重衰减的训练动态等价条件。因此，函数表示与训练路径等价的区别已有理论基础。本文将其用于固定输入复制的机器人补偿对照，具体核对输入及跳跃参数块、耦合L2和全局梯度裁剪；不将一般训练路径等价作为新原理。

训练目标与用途也需要区分。分段仿真辨识[16]、带适定性与稳定性约束的增广建模[17]以及学习微分方程的数值积分分析[18-19]均表明，瞬时误差、自由滚动与数值离散各有作用范围。本文围绕一个具体问题展开：在共同初始预测函数下，允许使用128 ms速度历史带来的点态作用，能否转化为可核验的0.6 s位置预测改善？为此，先建立优化等价对照，再进行参照状态上的历史输入评价，最后检查误差控制滚动与运动学基准。研究对象和历史增广思想沿用公开工作。本文将已有动态等价思想具体用于输入复制对照，并通过共同初值、历史配对与误差控制滚动评价，检验观察到的历史作用是否支持机械预测用途。

## 1 模型与优化对照

### 1.1 动力学接口与输入坐标

研究对象为六轴KUKA KR300 R2500。原建模记录对应末端附加质量150 kg；其余记录缺少逐条载荷字段，不据此推定载荷覆盖。保留来源模型的惯性、科里奥利和离心项、重力、传动比、坐标偏移与第二关节液压平衡项。q、v、u依次为关节位置、关节速度和电机侧力矩，固定物理参数记为θ，关闭来源摩擦项后的加速度记为f₀：

$$
\\dot q=v,\\qquad\\dot v=f_0(q,v,u;\\theta)+M^{{-1}}(q;\\theta)r_\\psi(z). \\tag{{1}}
$$

q、v的单位为rad、rad/s，rψ为关节侧N·m；网络输出用训练参考残差M(a−f₀)的均值和标准差还原尺度。因此M⁻¹rψ具有角加速度量纲。残差包含物理参数和信号处理偏差，不能等同于实测摩擦。虽然每关节单独建立两层100单元的tanh网络并设置线性跳跃项，M⁻¹仍保留整机耦合。该模型为刚体与传动动力学，不含柔性模态或弹性关节隐状态。

历史采样间隔为4 ms，正滞后样本数依次为ℓ_k∈{{1,2,4,8,16,32}}，k=1,…,6。采用训练速度均值μ与标准差s_v，定义当前速度及延迟差分坐标：

$$
x_j=(v_j-\\mu_j)/s_{{v,j}},\\qquad\\delta_{{j,k}}=[v_j(t-\\ell_k\\Delta t)-v_j(t)]/s_{{v,j}}. \\tag{{2}}
$$

差分不再单独中心化或缩放。Hδ使用[x,δ₁,…,δ₆]，Cδ使用[x,0,…,0]。两者从同一组参数出发，全部差分列及跳跃差分列为零，故任意历史下的初始函数相同。训练时这些列可更新；Cδ因输入为零而没有相应数据梯度。相同存储参数量不等于相同有效函数类，本对照估计的是固定学习规则下历史可用性的作用。

### 1.2 函数折叠和Adam匹配条件

令K为输入重复次数。对单关节网络，重复输入x1_K时，第一层及跳跃层只通过输入列之和作用于函数。将列相加可得到完全相同的单输入网络；反向把有效列放入第一列、其余置零亦可。因此，重复输入与单输入网络具有相同函数类，六关节K=7时新增的3636个参数均属于冗余方向。对各列w_l及有效列w=Σw_l，有

$$
\\sum_{{l=1}}^K\\|w_l\\|^2=\\|w\\|^2/K+\\sum_{{l=1}}^K\\|w_l-w/K\\|^2. \\tag{{3}}
$$

相同有效函数在重复列参数化下的最小L2惩罚缩小到1/K，因而统一学习率与统一正则系数不足以保证公平优化。令输入层与跳跃层有效参数合记为w，其余参数为ϑ，数据梯度为g_w、g_ϑ。D_s每列初始为w/K，V_m保存w；各重复列的Adam矩初态相同，V_m相应块取任一列的共同矩初态，其余参数及矩状态逐一复制。本研究矩状态均从零开始。D_s的全局梯度范数在V_m中应写为

$$
G=\\sqrt{{K\\|g_w\\|^2+\\|g_\\vartheta\\|^2}},\\qquad c=\\min[1,\\gamma/(G+\\varepsilon_c)]. \\tag{{4}}
$$

裁剪先乘数据梯度，再由Adam[20]加入耦合L2。对D_s设置学习率η、系数λ；V_m的w块设Kη、λ/K，其余块保持η、λ。相同批次、矩衰减系数、步数与分母常数下，各重复列与有效参数的耦合梯度及递推满足

$$
w_l=w/K,\\quad\\widetilde g_l=cg_w+\\lambda w/K=\\widetilde g_w,\\qquad w^+=w-K\\eta\\widehat m/(\\sqrt{{\\widehat v}}+\\varepsilon_A). \\tag{{5}}
$$

各列数据梯度、L2项与矩初态相同，故矩递推相同，列更新相加恰为V_m的更新；其余参数递推也相同。由迭代归纳可得精确算术下的输出函数序列等价。该命题限于列对称初始化、耦合L2及上述裁剪顺序，不直接适用于AdamW、非对称列或额外随机层。实际浮点训练还须保留偏离记录，不能用每步复制参数强制“通过”。

与文献[27]逐式比较，在其参数块尺度映射中取输入复制倍数K、输出复制倍数1，宽块Adam步长为窄块的1/K，耦合L2系数为窄块的K倍，分母常数不变；反向表示即式(5)的Kη与λ/K。该对应说明无裁剪的缩放规律已有基础。其主要命题保持外部输入维数而扩展隐藏宽度，本文在固定观测接口复制速度列，并加入线性跳跃项；这里必须重新核对的是复制梯度进入全局裁剪后的度量，而不是重新命名已有动态等价规律。

式(4)还给出一个可检验的限制：当K>1且两类梯度可独立变化时，不能仅调整普通单输入欧氏范数的一个常数裁剪阈值，使两种裁剪对任意数据梯度都相同。证明可分别取g_ϑ=0与g_w=0，并令非零梯度幅值趋大以消除ε_c的影响。两种情形要求的单输入阈值分别趋于γ/√K与γ，K>1时不相容。因而，需要保持复制参数块的权重K，或实施等价的梯度度量变换。该结论针对裁剪操作；特殊的未触发裁剪路径不受此限制，也不声称每种不匹配必定改变最终预测。

### 1.3 历史作用与预测用途的区分

对平滑速度，历史差分满足

$$
v_j(t-\\tau)-v_j(t)=-\\int_{{t-\\tau}}^t a_j(s)\\,ds. \\tag{{6}}
$$

差分既可能包含未观测状态线索，也编码局部加速度趋势。点态评价在相同参照q、v、u上比较加速度，避免把模型预测送回后续状态，因而不含自由滚动的状态偏离；它仍包含历史输入引起的函数类、梯度与裁剪响应变化。

令参考广义残差r*=M(a−f₀)，训练加速度标准差组成对角矩阵S_a。单状态上的无量纲加速度损失与力矩残差满足

$$
L_a=\\frac{{1}}{{6}}(r-r^*)^T M^{{-T}}S_a^{{-2}}M^{{-1}}(r-r^*). \\tag{{7}}
$$

该等式说明网络并非在各轴等权拟合力矩：姿态相关的逆惯性和关节加速度尺度共同决定损失度量。相同力矩偏差在不同轴或不同姿态上可产生不同的加速度惩罚。因此，本研究同时报告归一化均方误差（normalized mean square error，NMSE）和原量纲逐轴误差；不能仅凭整体NMSE把某轴误差较大解释为摩擦更强。

位置用途需另行评价。模型局部误差经过逆惯性、状态反馈、历史缓冲和时间累积，较低点态损失不能保证更低位置误差。固定网格的扩展状态含q、v与32个过去速度，共204维；自适应积分若跨区间传递下一步长，完整算法状态还需计入步长。本研究不据冻结过去样本的12维局部雅可比宣称完整历史系统稳定。动力学参数误差分析与辨识方法[23]提供了机械解释背景，但不能替代本文具体模型的验证。

## 2 数据与实验设计

### 2.1 记录、预处理和固定物理基底

采用文献[2]公开记录的三个首周期分别训练、验证和评价，每段60 s、15000点、250 Hz。官方基准说明与原始归档来自文献[21]。排除已用文件后，余下11个同日文件各取三种轨迹首周期，共33条记录；它们在原冻结模型评价时未参与网络训练或选择，但本研究后续对照已经参考相关结果，故新的匹配训练与评价属于事后受控分析，不重新赋予这些记录独立确认资格。没有新增实机试验，三个种子也不是三次物理重复。

前三轴次级编码器、后三轴电机位置沿用来源通道定义，角度转为rad，测得力矩为电机侧N·m。每记录独立作快速傅里叶变换（fast Fourier transform，FFT），将实数频谱索引200及以后置零，最高保留频率约3.317 Hz；由频域微分得到速度与加速度。此参照是整段平滑位置的派生量，不是独立加速度传感器真值；整段FFT包含未来样本，限制了在线解释。

位置、速度与加速度尺度使用完整训练轨迹的总体标准差，补偿力矩尺度使用排除32点后的训练残差；其余记录均固定这些尺度。物理基底按原接口执行5000次校准更新，选第4600步的验证最优参数后固定；神经补偿关闭来源摩擦项，学习完整残差。基底并未通过全域物理一致性验证。作为误差来源诊断，在固定惯性下仅用训练数据求解18个速度摩擦系数的有界最小二乘：原约束与放宽上界后，训练加速度NMSE由34.880956变为34.873610和34.584358，均不能消除整体失配。这些数值对应含该静态摩擦项的条件比较，不是关闭摩擦后的f₀误差；诊断参数未替换既有候选。该结果排除了“只要重新优化这18个系数就可消除误差”的解释，不识别全部物理根因。

### 2.2 配对训练及选择规则

表1给出两类对照。四模型共用每种子的10000×256批次序列，批次只取训练有效样本；全部完成10000次更新，不早停，不按评价集搜索学习率。采用float64、CPU、确定性算法，种子为9、19、29。每100步计算完整训练/验证误差；D_s按最低验证加速度NMSE选检查点，V_m沿用同一步。Cδ/Hδ分别按相同规则选模，持平取最早步；另报告共同10000步结果以揭示选择敏感性。

表1 配对模型与学习规则

{table(['模型','输入','参数量','学习率与耦合L2'],[['D_s','当前速度重复7次','66048','全参数0.001；1e−5'],['V_m','当前速度1次','62412','输入/跳跃块0.007；1e−5/7，其余同D_s'],['Cδ','当前速度及六个零差分','66048','全参数0.001；1e−5'],['Hδ','当前速度及六个历史差分','66048','全参数0.001；1e−5']])}

Adam矩系数为(0.9,0.999)，ε_A=10⁻⁸；全局裁剪阈值100，ε_c=10⁻⁶，V_m按式(4)计算范数。每检查点在训练及验证全有效样本上核查D_s/V_m的无量纲加速度差：逐分量须不超过10⁻⁹+10⁻⁷max(|a_D/s_a|,|a_V/s_a|)。记录首次失败、参数与矩差和裁剪次数，不事后放宽阈值。Hδ/Cδ的历史梯度可以改变全局裁剪系数，这属于相同学习规则对不同输入的响应，不写成已排除全部优化效应。

另以同一训练数据进行裁剪条件的构造性路径核验：复制独立初始化网络，K=7，初始化种子9，批次种子73019，连续200步、每批256点，D_s学习率10⁻⁴，L2、矩系数及裁剪阈值同上。完整匹配与仅把式(4)换成普通单输入范数两种情况使用相同批次，其他映射保持不变。比较每步更新后的当前批次网络输出最大绝对差；该输出为未还原力矩尺度的无量纲网络量，不能与后文加速度或位置误差等同。此核验不选验证检查点，也不替代10000步的完整训练。

### 2.3 点态评价与历史供体重采样

加速度NMSE按训练标准差逐关节归一化，先对时间取均方，再对六关节平均；同时报告逐轴原量纲均方根误差（root mean square error，RMSE）。训练加速度均值预测器作为绝对误差基准。

关联诊断冻结选定Hδ权重，只更换六维历史差分的供体。每关节当前速度的20个等频箱边界由训练数据确定，供体与受体在同记录、同箱，速度距离不超过该关节训练标准差的0.05倍，时间间隔大于32采样点；每关节整个六维差分向量一起搬移。三次有放回抽样种子固定为73031、73032、73033，供体可复用，不称一一置换或严格保持边际分布。加速度比较仅使用六轴均有供体的共同样本，并报告覆盖率。该干预不控制位置、力矩及跨关节历史关系，只检验冻结预测器对历史配对关系的依赖，不是物理因果或严格条件独立检验。

### 2.4 多步评价与数值判据

原评价记录等距取9个起点，33条记录各沿用9个既定起点，共306个窗口，每窗150步。起点状态和过去速度取参照记录，之后缓冲只由预测速度更新；已知未来记录力矩在4 ms区间内零阶保持。Hδ先通过首列减其余列之和的精确权重变换还原为标准化历史坐标；阶段正滞后由缓冲线性插值，零延迟取阶段当前速度，因此差分必须减阶段速度。转换输出和编译右端均逐模型核查。

采用已验证Dormand–Prince 5(4)内核[22]，相对容限分别10⁻⁶、10⁻⁸，尺度化绝对容限因子10⁻⁸、10⁻¹⁰；每4 ms输入区间精确终止后更新缓冲。每窗口的整体、低速、换向位置差归一化均方根误差（normalized root mean square error，NRMSE）须≤10⁻⁴，且最大位置差/训练位置标准差≤10⁻³；空掩码记NA。失败窗口进一步采用10⁻¹⁰/10⁻¹²细化并比较同一判据，仍失败则保留为未通过，不无限细化。该操作性判据不是工艺精度或严格全局误差界，亦不检查4 ms历史网格的重构误差。

位置NRMSE定义为

$$
E_G=\\sqrt{{|J_G|^{{-1}}\\sum_{{j\\in J_G}}|I_{{G,j}}|^{{-1}}\\sum_{{(o,h)\\in I_{{G,j}}}}(e_{{o,h,j}}/s_{{q,j}})^2}}. \\tag{{8}}
$$

其中I_(G,j)为满足工况掩码的起点与时刻，J_G为有效关节。低速阈值为训练速度绝对值95分位数的5%；跨阈值符号改变且间隔≤250点时，在最小速度处取前后25点为换向范围。掩码可重叠。另计算位置保持、恒速及恒加速度外推；最后一种使用起点的平滑参照加速度，包含额外初始运动学信息，不等同于力矩驱动模型。每轨迹先平均三初始化，再在33轨迹间等权平均。重叠窗口、同文件轨迹和初始化不用于伪独立显著性检验。

## 3 结果

### 3.1 优化匹配在完整训练中的表现

12个模型均完成10000步，共120000次参数更新。D_s/V_m三个配对共300个检查点，其中{300-fail}个满足预定分量容限；种子19首次超限在9900步，种子29在9300步，种子9无超限（表2）。全程最大标准化加速度差为{mx:.3e}，三个选定检查点均通过，最大差为{selmx:.3e}。因此实际结果支持所选检查点上的任务输出匹配，但不支持“所有浮点更新全过程均通过”这一更强表述。超限未被删除，也没有通过同步参数修正路径。

表2 优化匹配的逐初始化核验

{table(['初始化','共同选定步','超限检查点数','全程最大标准化加速度差','选定检查点通过'],[[r['seed'],r['selected_step'],len(r['failed_checkpoints']),f"{r['max_scaled_acc_difference']:.3e}",'是' if r['selected_check_pass'] else '否'] for r in EQ])}

D_s/V_m逐种子的裁剪触发次数完全一致，分别340、232、276次；Hδ/Cδ则分别为513/408、360/267、528/408次。历史输入的新增梯度确实改变了训练响应，不能仅因初始函数相同就宣称“信息以外的全部因素均已消除”。

200步构造性路径核验中，D_s有{clipcases['matched_symmetric']['clipped_steps']}步触发裁剪。完整匹配的网络输出最大差为{clipcases['matched_symmetric']['max_normalized_output_difference']:.3e}；仅改用普通单输入裁剪范数时，该差增至{clipcases['wrong_clip_norm']['max_normalized_output_difference']:.6f}，末步差为{clipcases['wrong_clip_norm']['final_batch_output_difference']:.6f}。这给出一个实际活跃裁剪反例：保持初始函数、Adam块步长及L2映射仍不足以使该路径相同。其用途是验证式(4)的必要处理范围，不用于宣称预测性能提高。

![图1 配对训练核验。左图为D_s/V_m检查点最大标准化加速度差，叉号表示未满足逐分量容限；右图为Hδ/Cδ验证误差，Cδ/Hδ分别为当前速度/历史差分模型。全部检查点保留，选模仅使用验证记录。](figures/fig1_training.png)

### 3.2 参照状态上的预测作用

表3报告验证选择后的点态指标。33轨迹上Hδ相对Cδ的NMSE变化为{-gain:+.2f}%，其中{pb}/33条轨迹Hδ较低。原评价记录的Hδ/Cδ NMSE分别为{pt('Hdelta','test')['nmse']:.6f}/{pt('Cdelta','test')['nmse']:.6f}。这一比较不存在预测状态回灌，因而表明的是参照状态上的作用。

表3 点态加速度NMSE（三初始化均值）

{table(['模型','训练','验证','原评价记录','33轨迹均值'],[[label]+[f(pt(m,g)['nmse']) for g in ['train','validation','test','peer']] for m,label in [('training_mean','训练均值'),('Ds','D_s'),('Vm','V_m'),('Cdelta','Cδ'),('Hdelta','Hδ')]])}

按初始化9、19、29分别计算，Hδ相对Cδ的33轨迹NMSE变化为{seed_point}；两个初始化改善，初始化9恶化。三初始化均值不表示训练结果方向一致。共同10000步模型的33轨迹NMSE为Cδ {pt('Cdelta','peer','final')['nmse']:.6f}、Hδ {pt('Hdelta','peer','final')['nmse']:.6f}；该固定末步结果与各自验证最优结果同时保留，不把较有利的选择口径写成唯一结果。网络相对彼此的改善仍需与训练均值基准比较。逐关节误差见表4；整体平均不能替代轴间差异。

表4 33轨迹的逐关节加速度误差

{table(['关节','Cδ NMSE','Hδ NMSE','Hδ RMSE/(rad·s⁻²)','训练均值NMSE'],[[j+1,f(pt('Cdelta')['joint_nmse'][j]),f(pt('Hdelta')['joint_nmse'][j]),f(pt('Hdelta')['joint_rmse_rad_s2'][j]),f(pt('training_mean')['joint_nmse'][j])] for j in range(6)])}

历史供体重采样在33轨迹上的六轴共同覆盖率范围为{min(cov)*100:.2f}%～{max(cov)*100:.2f}%。在共同覆盖样本上，真实与重采样历史的NMSE均值分别为{np.mean([r['true_common_nmse'] for r in pr]):.6f}和{np.mean([r['resampled_common_nmse'] for r in pr]):.6f}，后者相对变化{pg:+.2f}%。这是冻结函数对配对关系的诊断，不能与重训Hδ/Cδ的误差之差相减以求“纯历史信息收益”。全部供体索引、复用比例、速度距离和低覆盖记录均保留。

### 3.3 滚动预测及其绝对用途

六个模型各执行306个窗口的两容限评价，共1836项逐窗口检查。{numtext}两容限近似一致只支持当前离散规则下的数值可重复性，不验证真实机械状态。

表5 0.6 s位置NRMSE（三初始化及轨迹等权均值）

{table(['模型','原记录整体','33轨迹整体','33轨迹低速','换向（32条有效）'],[[label,f(rl(m,'test')),f(rl(m)),f(rl(m,regime='low_speed')),f(rl(m,regime='reversal'))] for m,label in [('Cdelta','Cδ'),('Hdelta','Hδ'),('position_hold','位置保持'),('constant_velocity','恒速'),('constant_acceleration','恒加速度')]])}

Hδ相对Cδ的33轨迹整体位置NRMSE变化为{-rgain:+.2f}%，Hδ较低的轨迹为{rb}/33条；相对恒速外推则有{cb}/33条较低。按初始化9、19、29分别计算，整体位置误差变化为{seed_roll}，初始化9与点态结果一样出现恶化。低速范围的三初始化均值变化为{100*(rl('Hdelta',regime='low_speed')/rl('Cdelta',regime='low_speed')-1):+.2f}%。换向掩码有{reversal_count}条记录有效，表5按这些记录等权平均，Hδ相对Cδ变化为{100*(rl('Hdelta',regime='reversal')/rl('Cdelta',regime='reversal')-1):+.2f}%；其余记录记NA，不当作零误差。这说明整体及低速上的平均改善没有同样表现为换向优势。恒加速度基准使用额外的平滑初始加速度，其结果只作为更强运动学参照。

![图2 33轨迹的点态与多步配对结果。每点对应一条轨迹的三初始化均值；对角线表示Hδ与Cδ相同，不将轨迹或窗口视为独立物理重复。](figures/fig2_paired.png)

### 3.4 与原滞后坐标结果的关系

作为参数化与积分敏感性参照，另设原滞后坐标模型H、重复输入D及历史移除H0。H使用当前及六个滞后速度，D重复当前速度，H0冻结H权重并将各滞后替换为当前预测速度；H0改变输入取值与反馈斜率，不作为单独的信息效应对照。H与D采用三个种子、相同候选学习率10⁻⁵、10⁻⁴、10⁻³，每候选最多10000步、连续2000步验证误差未改善则停止，按验证误差选模，但未采用式(4)～(5)的参数块匹配。原评价记录起点间隔25个样本，共593个起点，各预测0.6 s。在这些起点上，固定权重下4 ms四阶Runge–Kutta（RK4）得到H相对D的整体位置NRMSE降幅10.48%，误差控制较严容限下为3.01%；原两容限失败的8个窗口组合经局部细化后满足当时判据。这组既有结果说明数值设置会改变相对幅度（图3），不能将其直接用于替代本研究共同初值Hδ/Cδ比较。

![图3 原滞后坐标模型的积分敏感性。D、H、H0为原坐标对照；固定权重、4 ms历史网格及593起点。带符号曲线为RK4内部步长比较，水平点线为较严容限结果，均为三初始化均值；不与Hδ/Cδ组成统一排名。](figures/fig3_integration.png)

两组实验均属同一研究的对照设计：原滞后坐标揭示比较对参数化与积分条件的敏感性，共同差分坐标则给出初始函数一致后的输入评价。它们的正则化度量、输入坐标和选模轨迹不同，不能把跨组数值差归因于单一因素。两个阶段也没有生成新的独立实机数据。

## 4 讨论

函数保持变换及优化动态等价已有明确先例[25-27]。Ma等的Adam及耦合权重衰减映射与式(5)直接相关，不能仅以采用Adam或同时调整L2作为区别。本文的具体增量是固定观测复制下的共同全局裁剪度量、普通常数阈值不能普遍替代该度量的条件分析，以及活跃裁剪反例。它们把既有动态等价思想落实为机器人补偿的可执行对照，并非通用网络扩展定理或新的优化算法。其工程作用在于排除重复速度输入通过裁剪度量改变学习路径这一具体混杂，随后才能讨论历史可用性的预测作用。

Hδ/Cδ保证相同初始函数，却有不同的有效输入及后续学习轨迹；条件供体重采样进一步检查冻结函数是否依赖真实配对。两类证据均不能识别真实摩擦隐状态。式(6)及文献[24]说明，速度差分可以代理局部趋势，而摩擦还可能依赖力、载荷与未观测状态。本文未将这一物理歧义转化为可识别的摩擦模型。

当前输入D_s/V_m的33轨迹加速度NMSE为{pt('Ds')['nmse']:.6f}，低于Hδ的{pt('Hdelta')['nmse']:.6f}。因此，Hδ相对Cδ的平均改善不能扩展为优于所有已测试的当前输入学习规则。不同初始化也给出相反方向。整体位置指标中Hδ未优于恒速，但换向子集的均值低于恒速，{reversal_count}条有效记录中有{reversal_beats_cv}条较低；整体负结果不能外推为每种工况都无预测作用。上述差异共同限定了历史增广在本配置下的判断范围。

机械预测上的可复核判断是：应先检查参照状态上的绝对误差，再检查自由滚动能否保留相对作用，并使用经过数值核验的共同用途基准。本文物理基底整体误差较大，关节尺度还使不同轴残差受到不同权重。18系数条件最小二乘不能消除失配，并不意味着惯性、传动、输入约束或优化已逐一排除；更好的物理基底可能改变历史输入的相对价值。

结论受同机同日记录、整段非因果滤波、已知未来力矩和事后设计限制。33轨迹具有更多激励变化，但不是跨设备、跨载荷验证。当前结果支持限定的预测与数值判断，不支持在线部署、闭环稳定性或普遍历史优势。

## 5 结论

（1）在已有函数与动态等价规律基础上，给出重复速度输入及跳跃块的共同裁剪度量；普通单输入范数的单一阈值不能对任意两类梯度替代该度量。活跃裁剪路径对照验证了仅匹配步长与L2仍可产生输出偏离。三个完整训练配对的选定检查点通过预定容限，300个检查点中仍有{fail}个晚期超限，精确算术结论不能改写为全程浮点相等。

（2）共同初始函数下，Hδ相对Cδ在33轨迹的平均点态加速度NMSE变化为{-gain:+.2f}%，但三个初始化中仅两个改善。历史供体重采样揭示的依赖限于冻结预测器与当前匹配规则，不能解释为纯信息或真实摩擦因果作用。

（3）0.6 s位置NRMSE对应变化为{-rgain:+.2f}%，Hδ低于恒速外推的轨迹为{cb}/33条。点态作用、相对网络改善和绝对位置用途必须分开判断；这些结论仅适用于本文固定基底与离线记录。

## 数据与代码可用性

来源代码为roblue固定提交9dd1dcbcd97bb90b3cf705250d1c2df18f8a1fe2，官方原始数据数字对象标识符（digital object identifier，DOI）为10.26204/data/5。分别保留数据与来源代码许可，不把GPLv3自动套用于原始数据。完整材料保存参数、批次、初值、训练与选模记录、参照处理、权重、供体映射、逐窗口预测、失败记录及表图重建脚本；目前为本地研究材料，尚无公开归档DOI。本文未声称跨环境复现已完成。
'''
 old=(OLD/'delivery/论文第四轮修订稿.md').read_text(encoding='utf-8');refpart=old.split('## 参考文献\n\n')[1];refs={int(m.group(1)):m.group(2).strip() for m in re.finditer(r'\[(\d+)\] (.*?)(?=\n\n\[\d+\]|\Z)',refpart,re.S)}
 refs[24]='NGUYEN T V, HAN S, WOJTYRA M, et al. Physically informed input design for neural friction models in mechanical simulations[J]. Mechanism and Machine Theory, 2026, 227: 106503. DOI: 10.1016/j.mechmachtheory.2026.106503.'
 refs[25]='CHEN T, GOODFELLOW I, SHLENS J. Net2Net: Accelerating learning via knowledge transfer[C]//International Conference on Learning Representations. 2016. https://arxiv.org/abs/1511.05641v4.'
 refs[26]='WEI T, WANG C, RUI Y, et al. Network morphism[C]//Proceedings of the 33rd International Conference on Machine Learning. PMLR, 2016, 48: 564–572. https://proceedings.mlr.press/v48/wei16.html.'
 refs[27]='MA Y, CHEN N, DÍAZ M, et al. μpscaling small models: Principled warm starts and hyperparameter transfer[EB/OL]. arXiv:2602.10545v2, 2026. https://arxiv.org/abs/2602.10545v2.'
 # Expand ranged citations, then renumber by first appearance, never bibliography alone.
 text=re.sub(r'\[(\d+)-(\d+)\]',lambda m:'['+','.join(map(str,range(int(m[1]),int(m[2])+1)))+']',text)
 order=[]
 for m in re.finditer(r'\[(\d+(?:,\d+)*)\]',text):
  for n in map(int,m[1].split(',')):
   if n not in order:order.append(n)
 assert set(order)==set(refs),(set(refs)-set(order));mapping={v:i+1 for i,v in enumerate(order)}
 text=re.sub(r'\[(\d+(?:,\d+)*)\]',lambda m:'['+','.join(str(mapping[int(n)]) for n in m[1].split(','))+']',text)
 text+='\n## 参考文献\n\n'+'\n\n'.join(f'[{mapping[n]}] {refs[n]}' for n in order)+'\n'
 (D/'论文第五轮修订稿.md').write_text(text,encoding='utf-8');dump(D/'citation_mapping.json',mapping);dump(D/'manuscript_inputs.json',{str(p):sha(p) for p in [Path(__file__),R/'analysis/summary.json',R/'analysis/clipping_control_audit.json',OLD/'delivery/论文第四轮修订稿.md']});print('MANUSCRIPT',len(text),'characters',len(order),'references')
if __name__=='__main__':main()
