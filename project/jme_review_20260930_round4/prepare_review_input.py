from pathlib import Path
import json,shutil,hashlib
R=Path(__file__).resolve().parent;D=R/'delivery';I=R/'review/frozen_input';I.mkdir(exist_ok=True)
s=json.loads((D/'result_summary.json').read_text());a=json.loads((D/'result_audit.json').read_text());assert a['status']=='pass'
src=D/'论文第四轮修订稿.md';dest=I/'manuscript.md';shutil.copy2(src,dest)
h=hashlib.sha256(src.read_bytes()).hexdigest();assert a['source_sha256']==h
st=next(v for v in s['adaptive_summary'] if v['tolerance']=='tight' and v['regime']=='all')
ex=s['external_summary'];comp=next(v for v in ex['comparisons'] if v['control']=='capacity_control' and v['regime']=='all')
t=f'''# 第四轮作者逐项响应

冻结稿：review/frozen_input/manuscript.md，SHA256：`{h}`。

本响应陈述实际改动，不要求审稿人接受作者对“已解决”的判断。继续使用上一轮R1–R10编号。上轮主编认为R2/R3/R4/R5为未闭合优先级1问题。

|问题|本轮改动和证据|作者所承认的剩余问题|
|---|---|---|
|R1 尺度与朴素基准|保留全部负结果，表5合并原建模记录与未见轨迹的加速度基准；3.7节报告同轨迹第二次采集，完整表保存在配套分析文档|披露已修复不等于模型失配已解决；正文未作伪独立显著性宣称|
|R2 数值可靠性|3个D模型0.25 ms真实完成但不冒充完整细网格；采用预先记录的Dormand–Prince5(4)两容限协议，完成9模型×2容限×593起点×150步；两容限有{s['passed_cases']}/9个模型与初始化组合通过操作性一致性判据|固定4 ms历史网格；没有严格全局误差界或完整系统稳定性保证；独立Radau只核验D/H的3起点8 ms|
|R3 优化公平/归因|命题2明确对称列、矩状态和其他参数匹配，推导参数组学习率、耦合L2及加权裁剪条件；实际执行4组×2网络×200步核验，原候选不变|原D初始化与V参数组不满足条件；H/D仍未分离信息、优化和反馈斜率；不能把条件命题回填成原性能比较等价|
|R4 独立确认|官方原始包实际下载且MD5/SHA256核验，10字段及6周期逐元素映射；排除已用文件后33条同机同日未见轨迹，冻结候选与汇总方案，完成462点态指标、297预测窗口×9模型/初始化×2容限流程，{ex['tolerance_passes']}/297一致性检查通过|求解失败组合{len(ex['failures'])}；共同范围与方向计数逐项披露；不是跨设备/载荷验证，9窗口不是全时段覆盖，更早物理初始参数来源未重新审计|
|R5 贡献及工程意义|将优化路径条件、两个实际失配对照、数值误差控制及未见轨迹确认纳入统一研究；保留对历史优势不利的结果|条件命题未完成优先权系统检索，同一机器人诊断案例不自动达到本刊贡献门槛；不以增加轨迹数掩盖绝对预测能力问题|
|R6 数学对象及边界|网络其他参数改记ϑ，与物理θ区分；显式复制单输入网络参数/矩初态、步数；保留12维局部Jacobian与204维完整历史系统区别|不将局部模式诊断写成稳定性证明|
|R7 文献|继承未修改20项的逐条题名/作者/载体记录，新增Dormand–Prince与Zhu/Westny数值学习原始文献，共23项；最终编号见映射表|出版社全文403；方法元数据由出版社题名检索及SciPy官方引文核对，不声称全部23篇全文精读|
|R8 图表|表4与图2区分RK4及两容限；图3按每个失败初始化最大位置差选择诊断窗口；表5合并点态原记录及未见轨迹，表8/图4报告未见轨迹多步分布；正文收缩为8表4图，原粗网格对照/消融/时长/阈值及周期完整表图保留于配套文档|诊断图不代表平均性能；粗网格表3/6保留明确4 ms标签；全部图采用黑白可辨线型和标记|
|R9 复现|新增协议、输入/权重/代码哈希、完成状态、逐起点步数、NPZ；保存结果的一命令重建及主文数值检查通过|同机保存结果复算不等于独立环境重训练和重新积分；尚无公开归档DOI|
|R10 期刊适配|取得官网投稿须知及Word模板，按实际页边距、字号、公式居中/编号右齐、黑白线型与中文参考文献双语要求调整；23项文献及详尽说明|作者单位/基金等未提供，实际篇幅与视觉结果见最终渲染记录；不伪称已达到投稿或录用条件|

较严容限下整体D/H/H0 NRMSE为{st['capacity_control']:.9f}/{st['history']:.9f}/{st['history_removed']:.9f}，H对D相对降幅{st['reduction_percent']:.5f}%。请独立核对原始数组而非只接受此汇总。

未见轨迹整体H/D降幅为{comp['reduction_percent']}%，共同有效轨迹{comp['common_records']}，方向计数{comp['trajectory_direction']}；这是三初始化先平均后轨迹等权的描述统计，不是独立样本p值。附加持平口径的时间明确为点态结果后、多步结果前，不倒签。

## 可复核证据

- `adaptive/implementation_checks.json`、`implementation_check_source.py`及`inputs_seed*.json`：检查版本、算法签名与输入哈希。实现检查后仅新增来源守卫，计算核心AST核对一致；原检查源码仍保留。
- `adaptive/completion_seed*.json`、两容限18个NPZ及54条指标行。
- `optimizer_verification/per_step.csv`、`verification.json`；理论独立核验报告。
- `repeat_check/verification.json`及数组；明确其为同一激励的重复周期。
- `external_validation/`全部33轨迹点态输出、D六个多步输出及汇总；`external_validation_compiled/`H/H0十二个多步输出；completion、stats模式/失败记录、1782行多步指标、198行基准指标、297项两容限检查。执行版本按冻结清单选择，不按结果挑选。请对原始数组独立抽查逐轨迹及全体汇总，并核来源和尺度冻结。
- `adaptive/local_sensitivity_summary.json`及`delivery/figures/selection.json`明确8个起点—初始化组合/7个不同起点和正文图3诊断选择；内部图文件仍名fig7_trace，不以代表性之名选最差或最佳图。
- `compiled_execution/verification.json`与`external_execution_modes.json`：D保留eager，H/H0使用已核验冻结图，单案例不混用版本；有限实现核验不等于全状态数学等价证明。
- `delivery/result_audit.json`：{a['numeric_cell_checks']}个数字单元格核对，不等同原始数组独立复算。
- `参考文献核验第四轮.md`及前一轮完整来源表；全部文献元数据可按编号追溯。

请按re-review模式对冻结全文、问题回应、数值原始输出与正文图2/3/4审查；允许并应当保留未闭合问题和Major Revision。不得由修订次数推定接收。
'''
t=t.replace('H仍显著高于训练均值预测误差','H误差仍远高于训练均值预测误差').replace('披露已修复不等于模型失配已解决；不用“显著”表示统计检验，仅指数量级/绝对值关系，正文未作显著性宣称','披露已修复不等于模型失配已解决；正文未作伪独立显著性宣称')
t=t.replace('独立Radau只核验D/H的3起点8 ms','全部8个原失败窗口组合均完成tight→fine局部细化，8/8满足原位置判据；H9唯一失败窗口完成全0.6 s Radau，fine DP最大标准化位置差1.183094×10⁻⁷。局部结果不回填替换主表或删除原失败标签')
t=t.replace('保留12维局部Jacobian与204维完整历史系统区别','区分12维瞬时Jacobian、204维模型状态及至少205维自适应数值状态；式(10)明确限定固定子步数RK4映射')
t=t.replace('- `repeat_check/verification.json`及数组；明确其为同一激励的重复周期。','- `repeat_check/verification.json`及数组；明确其为同一激励的重复周期。\n- `failed_window_refinement/tight_fine_check_9.json`及`tight_fine_check_19.json`、两个fine NPZ及输入清单：全部8个原失败窗口组合细化完成。依事先记录的停止条件终止finer阶段，没有冒充finer完成。\n- `failed_origin_check_compiled/verification.json`、完整Radau数组、end sidecar及`review/H9完整Radau核验.json`：单困难窗口全150步独立积分方法检查，共享物理方程。')
(I/'作者逐项响应.md').write_text(t,encoding='utf-8');(I/'manifest.json').write_text(json.dumps(dict(manuscript_sha256=h,source=str(src),source_numeric_audit=a['source_sha256']),indent=2),encoding='utf-8')
print(h)
