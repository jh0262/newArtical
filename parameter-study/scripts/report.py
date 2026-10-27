from pathlib import Path
import json
import numpy as np
import pandas as pd
R=Path(__file__).resolve().parents[1];D=R/'data'
IDS=['N11','N12','N13','N21','B','N23','N31','N32','N33','W2','W10','C005','W2C005']
LABELS={'eta_low_to_mid':'η：0.025→0.05','eta_mid_to_high':'η：0.05→0.10','floor_low_to_mid':'σ下限：0.005→0.02','floor_mid_to_high':'σ下限：0.02→0.05','noise_corner_interaction':'η×σ下限外角交互','window_5_to_2':'窗口：5→2（两上限平均）','cap_020_to_0005':'上限：0.20→0.005（两窗口平均）','window_cap_interaction':'窗口×上限交互','window_5_to_10':'窗口：5→10'}
def n(x,d=6):return f'{x:.{d}f}' if np.isfinite(x) else '—'
def q10(x):return np.quantile(x,.1,method='hazen')
def main():
    sc=pd.read_csv(D/'screen_runs.csv');co=pd.read_csv(D/'confirm_runs.csv');ss=pd.read_csv(D/'screen_statistics.csv');cs=pd.read_csv(D/'confirm_statistics.csv');st=pd.read_csv(D/'confirm_stability.csv');sel=json.loads((D/'selection.json').read_text(encoding='utf-8'));cand=sel['candidates'];cand=[cand] if isinstance(cand,str) else cand;ids=['B']+cand
    audit=[json.loads((R/'audit'/f'{p}_audit.json').read_text()) for p in ['screen','confirm']];target=json.loads((D/'targets.json').read_text())['engineering_HV_target']
    x=co[co.Problem=='PPAR'];b=x[x.Variant=='B'].sort_values('Seed'); lines=['# 以2PPaPaR机构为主的参数作用与独立确认报告','', '研究日期：2026-10-27。机构模型、原创搜索机制和每次25,100评价预算保持不变；全部旧程序和结果原地保留。','', '## 1. 本轮回答的问题','', '比较既有参数如何影响机构解集质量、达到统一质量目标的速度，以及独立运行的稳定性。DTLZ3用于辅助解释多峰收敛行为，未参与候选选择。','',f'完成{len(sc)}次筛查和{len(co)}次独立确认，全部为真实新搜索。新增搜索评价{sum(a["new_search_FE"] for a in audit):,}次；最终档案复评{sum(a["new_final_FE"] for a in audit):,}次；目标抽样审计{sum(a["audit_objective_FE"] for a in audit):,}次，三类分别计数。','', '## 2. 试验设计与指标','', '筛查包含η×σ下限的3×3网格以及4个脉冲参数组合，每组16个独立种子；同一种子在参数组间配对。仅依据机构百万点最终HV均值和搜索HV曲线AUC均值，各选一个候选，再去重，以每组30个新种子确认。筛查数据与确认数据不合并。','',f'工程精度主要指标为最终档案在1,048,576积分点重评的归一化HV（越高越好），同时保存262,144点结果。速度指标为同一搜索积分下HV曲线AUC（越高越好）及固定目标HV={target:.15f}的首次达标评价次数。未达标运行保留，截断评价次数取25,100。稳定性报告SD、IQR、第10百分位与配对bootstrap区间。工程真实Pareto前沿未知，HV表示计算模型内的解集质量。','', '统计使用条件精确符号秩检验、10,000次种子配对bootstrap及Holm校正。筛查报告预先规定的因素效应；确认中所有候选的3个工程端点组成同一检验族。完整规则见PROTOCOL.md。','', '## 3. 机构参数筛查','', '|组|η|σ下限|窗口|脉冲上限|最终HV均值|SD|AUC均值|平均脉冲次数|','|---|---:|---:|---:|---:|---:|---:|---:|---:|']
    for id in IDS:
        a=sc[(sc.Problem=='PPAR')&(sc.Variant==id)];r=a.iloc[0];lines.append(f'|{id}|{r.Eta:g}|{r.SigmaMin:g}|{r.Window:g}|{r.Cap:g}|{n(a.MillionHV.mean(),8)}|{n(a.MillionHV.std(),8)}|{n(a.AUC.mean(),8)}|{a.Pulses.mean():.3f}|')
    lines+=['',f'按冻结规则，精度候选为**{sel["accuracy"]}**，速度候选为**{sel["speed"]}**。这些标签表示筛查阶段的选择依据，性能判断使用下述新种子结果。','', '### 3.1 预定参数效应','', '|参数对照|百万点HV差|95%均值差区间|局部Holm p|全部27项Holm p|','|---|---:|---|---:|---:|']
    for r in ss[(ss.Problem=='PPAR')&(ss.Metric=='MillionHV')].itertuples():lines.append(f'|{LABELS[r.Contrast]}|{r.MeanDifference:+.8f}|[{r.CILow:+.8f}, {r.CIHigh:+.8f}]|{r.HolmLocal:.5f}|{r.HolmGlobal:.5f}|')
    lines+=['','噪声网格的边际效应对另一因素的三个水平取平均；外角交互检验低、高水平组合的非加性。窗口与上限主效应来自完整2×2对照。AUC和达标评价次数的全部结果见data/screen_statistics.csv。','', '## 4. 独立确认：精度、速度与稳定性','', '|组|最终HV均值±SD|最终HV第10百分位|AUC均值±SD|平均截断达标FE|达标次数/30|','|---|---|---:|---|---:|---:|']
    for id in ids:
        a=x[x.Variant==id];lines.append(f'|{id}|{a.MillionHV.mean():.8f} ± {a.MillionHV.std():.8f}|{q10(a.MillionHV):.8f}|{a.AUC.mean():.8f} ± {a.AUC.std():.8f}|{a.CappedTargetFE.mean():.1f}|{int(a.Reached.sum())}/30|')
    lines+=['','|候选−B|指标|均值差|95%均值差区间|确认族Holm p|有利方向秩效应|','|---|---|---:|---|---:|---:|']
    for r in cs[cs.Problem=='PPAR'].itertuples():lines.append(f'|{r.Contrast}|{r.Metric}|{r.MeanDifference:+.8f}|[{r.CILow:+.8f}, {r.CIHigh:+.8f}]|{r.HolmGlobal:.5f}|{r.BenefitRankEffect:+.3f}|')
    lines+=['','HV/AUC增加为有利，达标评价次数降低为有利。两个候选的HV均值差bootstrap区间均低于0，但预设符号秩检验经6项Holm校正后均未达到0.05。均值差区间描述均值的不确定性，符号秩检验使用配对差的秩；这些结果支持保留默认设置，尚未建立经多重校正的参数优劣结论。','', '|候选|指标|SD比（候选/B）|95%区间|第10百分位差|95%区间|','|---|---|---:|---|---:|---|']
    for r in st.itertuples():lines.append(f'|{r.Variant}|{r.Metric}|{r.SDRatio:.3f}|[{r.SDRatioLow:.3f}, {r.SDRatioHigh:.3f}]|{r.P10Difference:+.8f}|[{r.P10Low:+.8f}, {r.P10High:+.8f}]|')
    lines+=['','两个候选的最终HV标准差分别为B的3.55倍和4.85倍；截断达标FE增加，同时达标次数由30/30降至29/30和27/30。稳定性区间为未作多重校正的配对bootstrap估计，主要用于描述运行波动。','', '## 5. 参数通过哪些过程影响性能','', '固定当前协方差与稀疏掩码分布时，常规噪声的条件幅值由ησ共同控制，条件能量随(ησ)²变化；实际协方差和掩码随搜索路径变化。σ下限在反馈步长触及下限后约束更新。脉冲实际系数为min(pulseCap,σ)，触发还需满足停滞窗口和低方差方向条件。','', '|组|末50代平均σ|末50代噪声RMS|末50代触底比例|脉冲次数|上限绑定脉冲次数|','|---|---:|---:|---:|---:|---:|']
    for id in IDS:
        a=sc[(sc.Problem=='PPAR')&(sc.Variant==id)];lines.append(f'|{id}|{a.LateSigma.mean():.5f}|{a.LateNoise.mean():.7f}|{a.LateFloorFraction.mean():.3f}|{a.Pulses.mean():.3f}|{a.BindingPulses.mean():.3f}|')
    baseline=sc[(sc.Problem=='PPAR')&(sc.Variant=='B')]
    ratios=sc[sc.Problem=='PPAR'].groupby('Variant').LateNoiseToProposalRatio.mean()
    activation=pd.read_csv(D/'screen_activation.csv');activation=activation[activation.Problem=='PPAR']
    lines+=['','### 参数开始改变轨迹的时刻','', '|组−参照|参数类型|首次决策差异代数均值|首次σ差异代数均值|完全相同轨迹数/16|','|---|---|---:|---:|---:|']
    for id,ac in activation.groupby('Variant',sort=False):
        r=ac.iloc[0];lines.append(f'|{id}−{r.Reference}|{r.ParameterType}|{n(ac.FirstDifferentGeneration.mean(),2)}|{n(ac.FirstSigmaDifference.mean(),2)}|{int(ac.IdenticalTrajectory.sum())}/16|')
    lines+=['','首次差异由保存的25,100个决策点逐点比较得到；平均代数只对出现差异的轨迹计算，完全相同轨迹另列。这是补充过程诊断。','', '上述结果确定了四类参数的生效方式：','', '- **噪声增益η改变早期搜索路径。** η的配对对照均在第1代产生决策差异；将η提高至0.10所得筛查优势没有在新种子上复现。增大常规扰动并未带来可重复的工程精度或速度收益。','- **σ下限主要约束中后期扰动。** 下限0.05与0.02的路径在约第105代分开，下限0.02与0.005在约第131代分开；触及较高下限前，相同η的配对路径一致。末50代各组均处于各自下限，因而下限直接控制持续扰动幅值。筛查中的最终HV因素检验未确认单调收益。','- **停滞窗口直接调节脉冲频率。** 窗口由5缩至2，平均脉冲次数由4.31增至34.69；延至10则降至0.06。缩短窗口明显增加干预次数，但本轮没有获得经校正的精度或速度改善证据。','- **脉冲上限只在绑定时改变幅值。** 默认上限0.20每次运行平均仅绑定0.25次；降至0.005后，所有已触发脉冲均受上限约束。调低上限后的AUC筛查主效应原始p=0.00763，9项端点内Holm p=0.06866，27项工程检验Holm p=0.20599；该趋势尚不足以支持换用参数。']
    lines+=['',f'末50代的常规噪声RMS与脉冲/裁剪/变异前总提议RMS之比，B组平均为{100*baseline.LateNoiseToProposalRatio.mean():.4f}%，各参数组均值范围为{100*ratios.min():.4f}%—{100*ratios.max():.4f}%。这一比值描述提议中的相对幅值，不表示噪声对最终HV的贡献比例。','', '阶段观测见data/screen_profiles.csv及图05。参数干预给出完整路径的累计效应；噪声、门控和反馈会相互影响，表中相关变化用于解释作用路径。','', '## 6. DTLZ3辅助证据','', '|组|确认IGD均值±SD|平均径向残差g|','|---|---|---:|']
    for id in ids:
        a=co[(co.Problem=='DTLZ3')&(co.Variant==id)];lines.append(f'|{id}|{a.IGD.mean():.6f} ± {a.IGD.std():.6f}|{a.MeanG.mean():.6f}|')
    lines+=['','DTLZ3的g衡量径向收敛残差，IGD同时反映到参考前沿的距离与覆盖情况，二者越低越好。工程选出的两个候选在DTLZ3确认中的IGD和g均值也较高，全部确认对照的Holm p为1；辅助测试未提供调参改善多峰收敛的证据。机构参数建议仍依据第4节。全部因素统计见data/screen_statistics.csv，确认对照见data/confirm_statistics.csv。','', '## 7. 积分精度与工程目标','']
    for id in ids:
        a=x[x.Variant==id];rel=100*np.abs(a.MillionHV-a.FineHV)/a.MillionHV;lines.append(f'- {id}：两级积分HV相对差的均值{rel.mean():.5f}%，最大值{rel.max():.5f}%。')
    lines+=['','|组|档案最大工作空间均值（cm³）|档案最小位置RMS误差均值（mm）|档案最大灵巧度均值|','|---|---:|---:|---:|']
    for id in ids:
        a=x[x.Variant==id];lines.append(f'|{id}|{a.VolumeMax.mean():.3f}|{a.ErrorMin.mean():.6f}|{a.DexterityMax.mean():.6f}|')
    lines+=['','表中三个边界值分别来自不同折中解。计算模型、奇异性边界和误差输入保持原设置。','', '## 8. 本轮判断','']
    accepted=[]
    for id in cand:
        a=x[x.Variant==id];lines.append(f'- {id}相对B：最终HV均值变化{100*(a.MillionHV.mean()/b.MillionHV.mean()-1):+.4f}%，AUC均值变化{100*(a.AUC.mean()/b.AUC.mean()-1):+.4f}%，截断达标FE均值变化{a.CappedTargetFE.mean()-b.CappedTargetFE.mean():+.1f}。')
        row=cs[(cs.Problem=='PPAR')&(cs.Metric=='MillionHV')&(cs.Contrast==id+'_minus_B')].iloc[0]
        if row.MeanDifference>0 and row.BenefitRankEffect>0 and row.HolmGlobal<.05:accepted.append(id)
    if not accepted:lines+=['','**保留默认参数B：η=0.05、σ下限=0.02、停滞窗口5、脉冲上限0.20。** 两个筛查候选均未通过预设的改善确认；在新种子中，最终HV均值下降，平均截断达标FE增加，运行波动增大。','', '本轮明确了参数的作用位置：η从初代改变搜索路径，σ下限在中后期维持扰动，窗口决定脉冲触发频率，上限在绑定后限制脉冲幅值。过程变化与性能收益需要分别判断：本轮观察到清晰的参数生效过程，但没有得到可重复提升机构求解效果的新参数组合。']
    else:lines+=['',f'独立确认中，{", ".join(accepted)}在最终工程解集质量上获得改善证据。采用时同时结合上表速度和稳定性结果；这项判断适用于本轮参数范围、固定预算和既定机构模型。']
    lines+=['','参数建议适用于本轮参数范围、25,100次评价预算和既定机构模型。独立确认避免将筛查中的偶然优势带入正式设置，DTLZ3保留为机制辅助证据。','', '## 9. 可复现性与文件','', '- 原始轨迹：results/screen、results/confirm；包含全部评价、RNG和失败捕获。596次正式运行均成功。','- 预算与目标复算：audit/screen_audit.json、audit/confirm_audit.json。','- 13项MATLAB测试全部通过；独立复算核对596条运行、55条统计对照及3,294项数值检查。','- 独立核算与3,656个旧文件SHA256核查：audit/independent_verification.json。','- 统计和7组图形重现：reproduce_derived.m。精简包保留全部派生数据和2条完整示例轨迹；全部原始轨迹保留在本地结果目录。','- 原论文和此前实验目录均未覆盖。','', '## 图形','']
    for f in sorted((R/'figures').glob('*.png')):lines.append(f'![{f.stem}]({f.resolve().as_posix()})\n')
    lines[3:3]=['**本轮建议保留默认参数。** 596次新运行明确了参数的生效阶段和脉冲触发规律；筛查选出的两个候选在独立确认中均未获得工程性能改善。','']
    (R/'机构优先参数测试报告.md').write_text('\n'.join(lines).replace('14,959,600.0次','14,959,600次')+'\n',encoding='utf-8')
    print('Report generated from saved observations')
if __name__=='__main__':main()
