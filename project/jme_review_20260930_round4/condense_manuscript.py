"""Focus the article; preserve full analysis and removed displays as companion material."""
from pathlib import Path
import re,json,hashlib,csv
R=Path(__file__).resolve().parent;D=R/'delivery';p=D/'论文第四轮修订稿.md'
t=p.read_text(encoding='utf-8');assert '表10 未见轨迹' in t
(R/'support/full_analysis_before_concision.md').write_text(t,encoding='utf-8')
comp=['# 实验分析与复现图表\n\n以下材料与正文属于同一项研究，保存各项分析的完整数值及图形。正文采用统一连续编号，本文件使用分析名称标识。']
def take(pattern):
 global t
 m=re.search(pattern,t,re.S);assert m,pattern
 comp.append(m[0]);t=t[:m.start()]+t[m.end():];return m[0]
for n in (2,3,4,5):
 take(r'!\[图'+str(n)+r' [^\n]+\n\n')
 t=t.replace('（图'+str(n)+'）','')
# Combine pointwise results, retaining all distribution columns in companion material.
s=json.loads((R/'external_validation/summary.json').read_text())
mapping={'训练均值预测':'training_mean','无原摩擦物理基底':'physics_no_friction','V':'velocity','D':'capacity_control','H':'history'}
m=re.search(r'表5 [^\n]+\n\n((?:\|[^\n]+\n)+)',t);assert m
lines=m[1].strip().splitlines();new=['表5 原建模记录与未见轨迹的加速度NMSE','',
 '|模型|原训练|原验证|原测试|33轨迹均值|33轨迹中位数|','|---|---|---|---|---|---|']
for line in lines[2:]:
 vals=line.strip('|').split('|');a=next(v for v in s['pointwise_summary'] if v['model']==mapping[vals[0]])
 new.append(line.rstrip('|')+f"|{a['mean']:.6f}|{a['median']:.6f}|")
t=t[:m.start()]+'\n'.join(new)+'\n'+t[m.end():]
take(r'表8 同一测试轨迹[^\n]+\n\n(?:\|[^\n]+\n)+\n')
take(r'表9 未见轨迹[^\n]+\n\n(?:\|[^\n]+\n)+\n')
t=t.replace('表9给出33条轨迹的点态加速度误差分布。','表5同时列出33条轨迹的点态加速度误差。')
t=t.replace('表10给出','表8给出').replace('表10 未见','表8 未见')
t=t.replace('表内各统计量对33个轨迹值等权汇总。','表内各统计量对33个轨迹值等权汇总；完整范围及H0结果保存在复现材料中。H在32/33条轨迹上低于D，但全部网络的逐初始化误差均高于相应训练均值基准。')
joint_file=R/'joint_acceleration/summary.json'
if joint_file.exists():
 js=json.loads(joint_file.read_text());assert js['status']=='complete'
 h=next(x for x in js['summary'] if x['model']=='history');mean=next(x for x in js['summary'] if x['model']=='training_mean')
 with (R/'joint_acceleration/per_record_joint.csv').open(encoding='utf-8-sig',newline='') as f:jr=list(csv.DictReader(f))
 j1_lower=sum(float(next(r['nmse'] for r in jr if int(r['record'])==i and r['model']=='history' and r['joint']=='1'))<float(next(r['nmse'] for r in jr if int(r['record'])==i and r['model']=='training_mean' and r['joint']=='1')) for i in range(1,34))
 fraction=sum(h['joint_nmse'][4:])/sum(h['joint_nmse'])*100
 paragraph=(f"对已保存点态输出按关节作描述性分解，H在第5、6关节的未见轨迹NMSE分别为{h['joint_nmse'][4]:.6f}和{h['joint_nmse'][5]:.6f}，"
  f"占六关节归一化均方误差之和的{fraction:.2f}%；相应角加速度RMSE为{h['joint_rmse_rad_s2'][4]:.6f}和{h['joint_rmse_rad_s2'][5]:.6f} rad/s²。"
  f"第1关节H的NMSE均值为{h['joint_nmse'][0]:.6f}，低于均值基准{mean['joint_nmse'][0]:.6f}，逐轨迹有{j1_lower}/33条较低。"
  "这说明整体不足集中于特定关节，不能概括为每个关节均劣于基准。该分解在点态结果后进行，只定位误差分布，不识别其物理成因。\n\n")
 t=t.replace('表6 六关节整体位置RMSE',paragraph+'表6 六关节整体位置RMSE')
 desc=['## 未见轨迹点态误差的逐关节分解\n\n先对每个关节的有效时刻取均方，再平均初始化和33条轨迹；RMSE在平均均方后开根。属于已保存结果的描述性分解，不参与训练或选模。','|模型|关节1 NMSE|关节2 NMSE|关节3 NMSE|关节4 NMSE|关节5 NMSE|关节6 NMSE|','|---|---|---|---|---|---|---|']
 for x in js['summary']:desc.append('|'+x['model']+'|'+'|'.join(f'{v:.6f}' for v in x['joint_nmse'])+'|')
 comp.append('\n'.join(desc))
t=t.replace('第二周期中H仍低于D及H0，但所有网络均明显高于均值基准。','第二周期H、D和H0的NMSE分别为21.880978、22.213529和23.176719，均高于训练均值基准1.544984。')
# One substitution prevents cascading figure renumbering.
t=re.sub(r'图([678])',lambda m:'图'+{'6':'2','7':'3','8':'4'}[m[1]],t)
# Condense source/implementation bookkeeping, with the original paragraphs retained.
a=t.index('### 2.5 未见轨迹确认与汇总');b=t.index('## 3 结果',a)
comp.append(t[a:b])
t=t[:a]+'''### 2.5 未见轨迹确认与汇总

官方原始归档[21]含同一机器人的12个采集文件，每文件有3种参考轨迹及其重复周期。已用文件的10个字段、6个周期的位置和力矩片段与文献[2]数据逐元素一致。排除全部已用文件后，从余下11个文件各取3种轨迹的首周期，共33条60 s记录。采集状态、有限值、6通道、250 Hz和长度检查均通过。位置沿用前三轴次级编码器与后三轴电机位置的原通道定义，角度转为rad，测得力矩保持电机侧定义。每条轨迹独立执行第2.1节的谱处理。

时间对齐参考位置的相对Frobenius差以候选去均值位置范数归一化；与已用及此前候选的最近差值最小为1.118，高于预定近重复阈值10⁻⁶。该指标不排除任意相移或重标度后的等价。33条记录均未参与本项目网络更新、选模及此前方案设计，但来自同机同日；更早物理初始参数的辨识数据未重新审计，不宣称与全部先验隔离。原始250 Hz记录的自定处理不同于官方10 Hz标准评分协议。

点态计算前固定数据资格、权重、物理参数、训练尺度及主要规则。点态评价排除32点预热；多步评价每条等距取9个整数起点，从第33至第14850个样本，各预测150步，共297个窗口，不跨记录边界。D、H、H0各三个初始化使用两组既定容限。D沿用原函数执行，H/H0使用冻结编译图，分配在后两者输出前固定。全部9模型的动态批规模右端计算和18组含拒绝步的短程预测与原执行一致，另核对一个困难起点的完整0.6 s预测。该有限实现核验不能替代逐案例容限检查。

每条轨迹先平均三个初始化，再在轨迹间等权报告均值和中位数；降幅为1减去两模型跨轨迹均值之比。分别统计33条轨迹及11个三轨迹文件组的配对方向，绝对差≤10⁻¹²为持平。此持平口径在点态结果后、多步输出前记录，不称为全部结果之前的预注册。无掩码记NA，失败及不一致单独报告，不作伪独立显著性检验。各轨迹仅覆盖9个窗口，不能视为原测试593起点的全量重复。

'''+t[b:]
# Integrate any completed independent long-horizon diagnostic without relabelling failures.
q=R/'failed_origin_check/verification.json'
compiled_diagnostic=False
if not q.exists() and (R/'failed_origin_check_compiled/verification.json').exists():
 q=R/'failed_origin_check_compiled/verification.json';compiled_diagnostic=True
if q.exists():
 v=json.loads(q.read_text());assert v['status']=='complete'
 diag=(f"对由预定阈值识别出的第一个初始化的唯一失败窗口，采用相对容限10⁻¹⁰、绝对容限因子10⁻¹²完成全0.6 s的独立Radau核验。"
       f"细化Dormand–Prince与Radau的最大标准化位置差为{v['dp_vs_radau']['max_normalized_position_difference']:.3e}，"
       f"原较严、较松结果相对Radau分别为{v['original_tight_vs_radau']['max_normalized_position_difference']:.3e}和{v['original_loose_vs_radau']['max_normalized_position_difference']:.3e}。"+
       ("Radau采用经核验的冻结计算图，与显式方法共享动力学方程；独立性指积分方法而非物理模型。" if compiled_diagnostic else "")+
       "该诊断覆盖一个按失败规则选取的窗口，不改变原两容限检查的失败记录，也不代表全部历史预测的独立求解核验。\n\n")
 t=t.replace('### 3.5 绝对误差与朴素基准',diag+'### 3.5 绝对误差与朴素基准')
 comp.append('## 独立长时域核验\n\n'+diag)
else:
 comp.append('## 独立长时域核验\n\n正在执行的Radau诊断尚未形成完成记录，不在正文报告结果。')
local_files=[R/f'failed_window_refinement/tight_fine_check_{seed}.json' for seed in [9,19]]
if all(p.exists() for p in local_files):
 checks=[x for p in local_files for x in json.loads(p.read_text())['checks']]
 assert len(checks)==8
 npass=sum(x['pass_original_thresholds'] for x in checks)
 mx=max(x['max_normalized_position_difference'] for x in checks)
 mr=max(y for x in checks for y in x['difference_nrmse'].values() if y is not None)
 local=(f'对原检查识别的全部8个起点—初始化组合，将相对容限进一步收紧至10⁻¹⁰、绝对容限因子至10⁻¹²，并与原较严结果逐窗口比较。'
        f'其中{npass}/8项满足原位置差判据，最大标准化位置差为{mx:.6e}，最大非空工况差NRMSE为{mr:.6e}。'
        '这是按原失败规则进行的局部细化诊断，不重算其余已通过窗口；主表仍保留原两容限结果与失败标签，不用局部替换后重新排列模型。\n\n')
 t=t.replace('对由预定阈值识别出的第一个初始化',local+'对由预定阈值识别出的第一个初始化')
 t=t.replace('未满足判据的模型仍需更严格的容限或独立方法核验，不能把较严容限结果直接当作精确解，也不能宣称所有模型已数值收敛。','原未通过项另作下述局部细化及独立方法诊断；较严容限仍不是精确解，有限诊断不构成全局收敛证明。')
 if npass==8:
  t=t.replace('历史模型的三个初始化中仅一个通过原测试两容限检查。','原测试两容限检查中历史模型仅1/3个初始化通过；8个失败窗口组合经局部细化后均满足原判据。')
  t=t.replace('Only one of its three initializations passes the original-test agreement criteria between tolerances.','One of three initializations passes the original-test criteria between tolerances; all eight failing origin–initialization pairs meet the original position-agreement criteria after further local refinement.')
  t=t.replace('但历史模型仅1/3个初始化通过原测试的两容限一致性检查。','但原两容限一致性检查仅1/3个历史初始化通过；识别出的8个失败窗口组合经进一步局部细化后均满足原判据。')
 comp.append('## 原未通过窗口的局部细化\n\n'+local)
# Update statements that refer only to original exploration.
t=t.replace('### 3.4 预测时域与评价敏感性','### 3.4 积分敏感性与误差控制')
t=t.replace('共同物理模型及补偿网络的加速度NMSE远高于常值预测基准，且未验证收敛，','共同物理模型及补偿网络的加速度NMSE远高于常值预测基准，且训练收敛尚未验证，')
t=t.replace('本文保留的是刚体动力学与传动结构，没有建立柔性模态、关节弹性内部状态或新的刚柔耦合模型。','本文采用刚体动力学与传动结构，不含柔性模态或关节弹性内部状态。')
start=t.index('### 4.1 历史依赖与预测改善的证据边界');end=t.index('### 4.2 ',start)
comp.append(t[start:end])
t=t[:start]+'''### 4.1 历史依赖与预测改善的证据边界

函数类、输入依赖和预测优势是三个不同问题。命题1说明D的重复输入不扩大V的函数类；点态H/H0干预表明已训练网络的输出依赖延迟差分；H/D的多步比较则同时受训练与积分设置影响。原测试的整体降幅从4 ms下的10.48%缩小到较严容限下的3.01%，且一个初始化方向反转。因此，对历史的函数依赖不足以证明稳定的预测优势，也不能由参数量相同排除优化差异。

命题2给出了可检验的匹配条件，但原候选不满足这些条件。初始化、Adam矩状态、输入层正则化、裁剪和早停对所选解的影响尚未分别识别。固定学习率与候选搜索同时改变了搜索范围和最大预算，不能拆分各自贡献；共同最大更新数也不等于实际计算量相同。恒速及加速度均值基准进一步显示，对指定网络对照的相对改善与工程预测有效性必须分别评价。

'''+t[end:]
# English technical prose: avoid suggesting stronger causal identification.
t=t.replace('the assessment of velocity-history dynamics augmentation','the assessment of dynamics augmentation using velocity history')
t=t.replace('函数折叠及条件Adam路径等价关系','函数折叠关系及Adam更新等价的充分条件')
t=t.replace('与D比较真实历史输入的作用','与D比较延迟速度输入的作用')
t=t.replace('真实历史误差较低','保留延迟输入时误差较低')
t=t.replace('A_k和B_k在名义轨迹、零扰动处对X_k及δr_k求导。','在F_Δ局部可微处，A_k和B_k分别为名义轨迹、零扰动处对X_k及δr_k的导数。')
t=t.replace('令F_Δ表示一个4 ms采样区间内包含力矩保持、积分子阶段、历史插值与缓冲更新的完整映射。','此处F_Δ限定为给定固定子步数的RK4映射，包含一个4 ms区间内的力矩保持、积分、历史插值及缓冲更新。自适应执行还跨区间传递下一步长h；若描述其完整算法映射，须将h纳入状态（单起点至少205维）。本文未计算这一自适应扩展映射的雅可比。')
t=t.replace('本文据此将重复当前输入模型称为“重参数化对照”，不再以“容量增大”解释其结果。','重复当前输入模型由此构成函数类不变的重参数化对照。')
t=t.replace('M⁻¹rψ具有加速度量纲，不能把网络原始输出直接视为力矩。','经尺度还原后，M⁻¹rψ具有加速度量纲。')
t=t.replace('这里比较的是相同有效时刻、同一归一化尺度，差异不能解释为百分数单位不同。','')
t=t.replace('两条模型轨迹初值相同，Φ为A_k的有序乘积，C_q抽取位置分量。','两条模型轨迹初值相同，Φ(h,i+1)=A_(h−1)…A_(i+1)，空乘积Φ(h,h)=I，C_q抽取位置分量。')
t=t.replace('点态加速度误差及运动学基准比较表明，相对网络对照的改善不能替代绝对预测能力检验。','历史模型在33条轨迹上的整体位置误差均高于恒速外推，换向范围的平均误差较重复输入对照高1.71%。相对网络对照的改善不能替代绝对预测能力检验。')
t=t.replace('Pointwise acceleration errors and kinematic baselines show why improvement relative to a network control cannot replace an assessment of absolute prediction accuracy.','The history model has higher overall position errors than constant-velocity extrapolation on all 33 trajectories; its mean error near velocity reversals is 1.71% higher than that of the duplicated-input control. Improvement relative to a network control therefore does not establish absolute prediction accuracy.')
t=t.replace('换向范围中，H相对D的均值降幅为-1.71%','换向范围中，H的均值误差较D高1.71%')
t=t.replace('H与恒速外推在整体范围的共同有效轨迹为33条，H较低/持平/较高的数量为0/0/33。','H的整体位置误差在33条轨迹上均高于恒速外推。H与H0的整体均值仅相差0.036%，但有21条轨迹H较低、12条较高，且低速和换向均值方向相反；这些描述性结果不构成统计等价证明。')
t=t.replace('网络相对对照的改善、对朴素运动学基准的优势及真实物理机理辨识属于不同判断。','33条未见轨迹上，H的整体误差均高于恒速外推，换向范围的平均误差较D高1.71%，H/H0整体均值差仅0.036%。现有结果未建立普遍的历史预测优势，也不能解释为真实摩擦机理辨识。')
t=t.replace('重载机器人速度历史补偿的对照与数值敏感性分析','重载机器人速度历史补偿的对照与积分敏感性')
t=t.replace('官方原始数据归档（DOI：10.26204/data/5）','官方原始数据归档，其数字对象标识符（digital object identifier，DOI）为10.26204/data/5')
t=t.replace('Controlled comparisons and numerical sensitivity of dynamics augmentation using velocity history for a heavy-duty robot','Controlled comparisons and integration sensitivity of velocity-history compensation for a heavy-duty robot')
# Keep the implementation-level detail available while shortening repeated qualifications.
def replace_section(begin,end,replacement):
 global t
 a=t.index(begin);b=t.index(end,a);comp.append(t[a:b]);t=t[:a]+replacement+'\n\n'+t[b:]
replace_section('### 3.7 同轨迹重复采集的点态检查','### 3.8 ','''### 3.7 同轨迹重复采集的点态检查

固定物理参数、权重及训练尺度，对测试轨迹第二周期独立实施相同FFT处理。H、D、H0的加速度NMSE分别为21.880978、22.213529、23.176719，均高于训练均值基准1.544984。两周期平滑位置的逐关节相关系数均大于0.999999999，差异RMSE为4.52×10⁻⁷至4.74×10⁻⁶ rad。该结果支持近相同激励下的点态重复性，不增加独立工况，也不检验多步积分。''')
replace_section('### 4.2 与已有历史补偿研究的关系','### 4.3 ','''### 4.2 与已有历史补偿研究的关系

文献[7–10]已研究机器人时序动力学补偿，其中转动历史编码[10]面向局部往复运动，动态隐变量方法[12]则显式表示未观测状态。本文的贡献限于重参数化对照、冻结干预及积分核查，不以不同机器人、任务和预算下的数值作跨论文排名。

严文俊和蔡月日[23]分别讨论关节刚度与迟滞、摩擦及传动误差。本文未单独测量这些分量；短历史差分也可能携带局部加速度趋势，不能仅由预测器对其敏感判定摩擦记忆。残差适配[11]和物理/学习分量正交化[15]处理的是域变化及子模型竞争，同样不构成历史机制的直接证据。''')
replace_section('### 4.4 确认范围与工程适用性','## 5 结论','''### 4.4 确认范围与工程适用性

33条记录将证据扩展至同机同日的多种激励，逐轨迹和文件组结果揭示了平均收益的异质性。其载荷、温度元数据不完整，尚不支持跨载荷、温度或机器人推广。轨迹、重叠窗口和初始化对应不同层次，不能互作独立重复；每轨迹9个窗口也不代表全时段覆盖。

整段FFT的非因果性、周期延拓及已知未来力矩限定了离线预测用途。识别摩擦历史效应仍需相同当前速度、不同运动历史的受控工况，以及动态摩擦或循环状态模型的同条件比较。现有冻结候选未执行命题2所要求的匹配训练，因而本研究提供对照诊断案例，不建立普遍补偿优势或闭环稳定性。''')
t=t.replace('有效轨迹数（整体/低速/换向）：D为33/33/32；H为33/33/32；H0为33/33/32；恒速外推为33/33/32；位置保持为33/33/32。两容限一致性按轨迹、模型和初始化逐一检查，共297项，297项通过。各模型通过数为D 99/99、H 99/99、H0 99/99。记录到0个轨迹—模型—初始化—容限组合积分失败。按轨迹隔离重试与批量执行的模式另行记录，批规模变化可能带来浮点路径差异。','所有模型的整体、低速、换向有效轨迹数分别为33、33、32。D、H、H0各99项两容限检查全部通过，共297/297项；无积分失败。执行模式与逐案例状态保存在复现材料中。')
with (R/'external_validation/tolerance_checks.csv').open(encoding='utf-8-sig',newline='') as f: tc=list(csv.DictReader(f))
maxpos=max(float(v['max_normalized_position_difference']) for v in tc)
maxreg=max(float(v[k]) for v in tc for k in ['delta_all','delta_low_speed','delta_reversal'] if v[k] not in ['', 'NA', 'None'])
t=t.replace('共297/297项；无积分失败。',f'共297/297项；无积分失败。最大标准化位置差为{maxpos:.6e}，接近10⁻³判据，最大工况差NRMSE为{maxreg:.6e}；通过该检查不等同于已获得严格误差界。')
t=re.sub(r'\n{3,}','\n\n',t)
assert len(re.findall(r'^!\[图',t,re.M))==4
assert re.findall(r'^表(\d+) ',t,re.M)==[str(i) for i in range(1,9)]
assert t.count('$$')==22
(D/'实验分析与复现图表.md').write_text('\n\n'.join(comp),encoding='utf-8')
p.write_text(t,encoding='utf-8')
j=json.loads((D/'result_summary.json').read_text());j['manuscript_sha256']=hashlib.sha256(p.read_bytes()).hexdigest();j['main_displays']={'tables':8,'figures':4,'equations':11};(D/'result_summary.json').write_text(json.dumps(j,ensure_ascii=False,indent=2),encoding='utf-8')
print('Focused main paper: 8 tables, 4 figures, 11 equations; full analysis preserved')
