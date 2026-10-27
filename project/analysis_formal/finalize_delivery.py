"""Record completion and build a new portable archive, preserving prior outputs."""
import json
import shutil
import zipfile
import hashlib
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parent

status = '''# 当前研究判断与状态

更新：2026-09-21。中科院分区；数值研究；结论限于模型预测。

**获准的 420 次正式实验与审计已完成。耳切与型号分层档案的组合尚无优于基础 MODE 的统计证据。英文稿已保留这一结果并修订，仍不是投稿候选。**

## 已实际完成

- 原 v2.4 解析枚举研究、原始资料、开发试算及旧稿保留。
- 19 个完整目录型号的周期动态模型、9 个假设情景及 10 项约束；27 组独立 ODE 核验、60 组有限前沿覆盖性质检查及开发阶段双模态敏感性检查。
- 正式实验：7 方法 × 3 周期上限 × 20 配对种子，N=64、500 代。420/420 次完成，共 13,466,880 FE，日志耗时 374.5 s；用户“继续实验”的授权已写入原生 ARIS 记录。
- 28 项冻结输入一致，420 MAT 和 840 CSV 完整。26,880 个最终设计复算的目标和约束违反量差为 0；独立 HV 最大差 9.99e-16。
- 27 项实际配对检验的原始 p 值经 SciPy 精确计算交叉核对，差为 0；未更换种子或追加优化。
- 正式中文报告、英文修订稿、四组 PNG/PDF 图、8 组带来源的工程候选及审计文件。四组 PNG 已目视检查。

## 主要结论

1. 组合与基础 MODE 三工况的 Holm 校正 p 均为 1.000；A、B 与交互项均未检出显著效应。不显著不等于已证明等效。
2. 保存大集合的事后压缩中，耳切优于一次性拥挤距离截断，但 HV 接近迭代拥挤距离，后者的覆盖半径在三个集合上均更小。这不是同预算优化比较。
3. 在 0.1 µm 残余振动阈值下，组合没有一致缩短周期。工程候选接近目录转速边界，仍只属于假设模型预测。
4. 下一阶段应定位宽可行域下的搜索与候选保留问题，并纳入迭代拥挤距离强对照，避免单纯堆叠机制。未启动新增正式批次。

## 未解决边界

- 最近前作全文与档案机制差异尚未全部补齐，全球新颖性未确定。
- 未保存每代绝对覆盖半径，仅保存调用、回退和最大覆盖超限诊断；不补造轨迹。
- 无实体、有限元、伺服或接触非线性验证；结果不能作为实物性能保证。
- 最新官方中科院分区记录尚缺。非 OA 3/4 区、OA 2/3 区是用户筛选条件，不是已满足的结论；不能保证录用。

## 交付入口

- `analysis_formal/RESULTS_zh.md`：完整结果、统计解释和研究调整建议。
- `manuscript/manuscript_en_formal_v02.md`：正式结果英文修订稿。
- `manuscript/CLAIM_LEDGER_formal_v02.md`：论断与证据对应。
- `formal_v01/`：正式原始结果；`analysis_formal/`：分析、图表与审计。
- `RUN_GUIDE_zh.md`：复核说明；`provenance/`：授权、冻结清单、日志和历史状态。
'''

handoff = '''# 当前研究交接：2026-09-21

用户目标：耳切思想融入 MODE，结合滚珠丝杠副撰写算法与应用文章。采用中科院分区，非 OA 3/4 区、OA 2/3 区；可复核数值研究，结论限于模型预测。原 v2.4 静态解析枚举论文与原数据保留。

本轮目录为 `10_dynamic_mode/`，权威记录为 `.aris/runs/ball-screw-earclip-dynamics-20260921.json`。用户最新“继续实验”已承接此前具体预算，该预算已授权并全部执行，不应再次询问相同授权。

## 实际完成

- 7 方法 × 3 周期上限 × 20 配对种子，64 个体、500 代，每次 32,064 FE；420/420 次，共 13,466,880 FE，单 MATLAB 进程日志耗时 374.5 s，低于 1,800 s 上限。
- 420 MAT、840 CSV 完整；28 项冻结输入一致；26,880 个最终设计同模型复算差为 0；独立 HV 与精确符号秩概率交叉核对通过。
- 中文报告、英文正式结果修订稿、论断证据表、统计与工程候选表、四组 PNG/PDF 图均完成。四组 PNG 已目视检查。
- 正式 FE 不含开发试算、后续 26,880 点复算及 8 点工程诊断；没有新增事后优化评价。

## 核心判断

组合 MODE-EAR-S 与基础 MODE-CD-G 三工况的校正 p 均为 1.000；耳切、分层档案与交互项均未检出显著作用。部分经典对照的优势不能归因于新增机制。不显著也不能解释为等效。

事后有限集合压缩中，耳切改善一次性拥挤距离的结果，但 HV 接近迭代拥挤距离，覆盖半径不如后者。应定位搜索/候选保留问题，将迭代拥挤距离纳入未来对照；不能堆叠机制或筛种子制造优势。未启动新增正式批次。

## 阅读顺序与剩余事项

1. `10_dynamic_mode/analysis_formal/RESULTS_zh.md`
2. `10_dynamic_mode/manuscript/manuscript_en_formal_v02.md`
3. `10_dynamic_mode/manuscript/CLAIM_LEDGER_formal_v02.md`
4. `10_dynamic_mode/analysis_formal/delivery_audit.json` 和 `10_dynamic_mode/RUN_GUIDE_zh.md`

执行日志为 `provenance/formal_execution_captured_20260921.log` 中原样保存的 MCP 输出；同日 diary 文件为空，不能作为完成证据。每代绝对覆盖半径未记录，不得假装重建。

稿件仍为研究草稿。最近前作全文、机制新颖性、当前官方 CAS 分区记录尚缺；没有实体/FEM 验证。开发双模态检查不能替代正式候选的物理验证。后续重点是强对照协议、研究定位、模型边界与选刊；新增优化批次需要相应具体协议与预算，原定 420 次已全部执行。用户未要求后台常驻或定时运行，未创建自动化。
'''

analysis_readme = '''# 正式结果复核

阅读入口为 `RESULTS_zh.md`，原始数据在 `../formal_v01/`。全部 420 次正式运行进入统计；探索种子不进入正式统计。

## 复现顺序

在扩展目录 `10_dynamic_mode` 下：

1. `python -X utf8 freeze_manifest.py --check` 检查 28 项冻结输入。
2. `python -X utf8 analysis_formal/analyze_formal.py` 重建 HV、配对检验、消融、工程阈值及收敛数据。
3. `python -X utf8 analysis_formal/diagnose_nested_cases.py` 从保存结果建立嵌套有限候选集合。
4. MATLAB 加入 `matlab`、`matlab/vendor`、`analysis_formal` 路径后，`audit_model_results` 复算 26,880 点；`diagnose_saved_fronts` 比较有限集合压缩；`select_engineering_designs` 选择和复核 8 个保存候选并绘制一组轨迹；`plot_formal` 绘制三组统计图。
5. `python -X utf8 analysis_formal/build_formal_draft.py` 根据统计表重建英文稿（会覆盖同名正式结果草稿）；`python -X utf8 analysis_formal/verify_delivery.py` 交叉检查执行记录、原始结果哈希、27 项实际检验概率及稿件表值。

这些步骤更新派生文件，不重新运行优化器。第 4 步的同模型复算和工程评价是额外审计计算，不能算入正式优化 FE。生成交付包的维护脚本 `finalize_delivery.py` 使用独占新建方式保留旧 ZIP，无需为阅读或统计复核再次运行。

## 图表解释

- `formal_hv_distribution`：每点是一粒种子的最终可行 HV，竖线为四分位范围，黑横线为中位数。
- `formal_convergence`：20 次运行的逐代中位数；阴影为 25%–75% 分位区间，不是置信区间。三个面板纵轴范围不同，不宜按视觉距离跨面板比较。
- `formal_factorial`：A、B 和交互的配对均值效应及逐项 95% bootstrap 区间，不是同时区间；显著性以 Holm 校正检验表为准。
- `selected_trajectory`：保存候选在最坏残余情景的一次上行与停留响应；相对位移以重力平衡位置为基准，预测载荷含重力项。不是实测波形。

四组图均有 PNG 和矢量 PDF，PNG 已目视检查，无文字裁切或图例遮挡。图形检查不代表物理有效性。

各审计 JSON 的 PASS 仅覆盖明示的计算和一致性检查，不表示创新性、算法优越性、实体验证或可录用性通过。
'''

def main():
    package = PROJECT/'10_dynamic_mode_formal_v01_20260921.zip'
    if package.exists():
        raise FileExistsError('Preserve existing formal delivery archive; choose a new version explicitly.')
    audit = json.loads((ROOT/'analysis_formal/delivery_audit.json').read_text(encoding='utf-8'))
    assert audit['status']=='PASS' and audit['formal_optimizer_FE']==13466880
    for name in ['STATUS','RUN_GUIDE','README','HANDOFF']:
        assert (ROOT/f'provenance/{name}_before_formal_completion.md').exists()
    (ROOT/'STATUS.md').write_text(status, encoding='utf-8')
    (PROJECT/'HANDOFF.md').write_text(handoff, encoding='utf-8')
    (ROOT/'analysis_formal/README.md').write_text(analysis_readme, encoding='utf-8')
    guide=(ROOT/'RUN_GUIDE_zh.md').read_text(encoding='utf-8')
    guide=guide.split('## 正式实验入口')[0]+'''## 正式实验（已获准并完成）

用户“继续实验”已授权原定单进程、最多 30 分钟、420 次/13,466,880 FE 的预算；原生 ARIS 和 `provenance/FORMAL_AUTHORIZATION.md` 已记录。420 次全部完成，日志耗时 374.5 s。冻结协议中的待答复句子是历史状态，保留原文以维持哈希；当前授权与完成状态以原生记录为准。

原执行入口为 `bs_run_study(1800)`。已有完整结果，无需为查看结果重新优化。脚本不覆盖正式文件；独立复现须保留本包并明确新的输出位置与预算，不应删除现有结果重来。时限按运行间检查。

## 只复核已保存结果

在本目录运行以下命令，不产生新优化评价。派生分析文件将更新，原始 MAT/CSV 不变。

```powershell
python -X utf8 .\\freeze_manifest.py --check
python -X utf8 .\\analysis_formal\\analyze_formal.py
python -X utf8 .\\analysis_formal\\diagnose_nested_cases.py
python -X utf8 .\\analysis_formal\\verify_delivery.py
```

其他诊断、工程选点、绘图与稿件重建见 `analysis_formal/README.md`。ODE 校核是模型实现 verification，最终点同模型复算是结果一致性检查，均不构成实体 validation。
'''
    (ROOT/'RUN_GUIDE_zh.md').write_text(guide, encoding='utf-8')
    readme=(ROOT/'README.md').read_text(encoding='utf-8')
    readme=readme.replace('当前定位：模型与算法的研究开发版本，不能直接投稿。各项实际完成情况见 `STATUS.md`；计划不等于结果。', '当前定位：420 次正式比较与审计已完成，新增机制尚未显著优于基础 MODE。结果见 `analysis_formal/RESULTS_zh.md`，英文修订稿见 `manuscript/manuscript_en_formal_v02.md`。研究仍不能直接投稿，详见 `STATUS.md`。')
    readme=readme.replace('原稿与旧算法实验目录均只读引用。新文件的生成不得被解释为完成了实体实验、有限元验证、正式算法优越性比较或投稿。', '原稿与旧算法实验目录均只读引用。正式算法比较已完成，但未证明新增机制优越性；尚未完成实体实验、有限元验证或投稿。')
    (ROOT/'README.md').write_text(readme, encoding='utf-8')
    state_path=PROJECT/'.aris/runs/ball-screw-earclip-dynamics-20260921.json'
    state=json.loads(state_path.read_text(encoding='utf-8'))
    state['updated']=datetime.now(timezone.utc).isoformat()
    for phase in state['phases']:
        if phase['phase']=='formal-comparison':
            phase.update(status='checked', artifact='10_dynamic_mode/analysis_formal/delivery_audit.json', runs_completed=420, design_evaluations=13466880, wall_seconds=374.5, review='Complete raw records, frozen inputs, objective and CV reevaluation, independent HV and statistical crosschecks; no physical validation or superiority claim.')
        if phase['phase']=='paper-writing':
            phase.update(artifact='10_dynamic_mode/manuscript/manuscript_en_formal_v02.md', note='Formal results incorporated, including null ablation and superiority findings. Not a submission candidate.')
    state['formal_results']={'candidate_vs_baseline_holm_p':[1.0,1.0,1.0], 'significant_factorial_effects':0, 'model_reevaluation_designs':26880, 'selected_design_checks':8, 'new_posthoc_optimizer_FE':0, 'saved_set_compression':'Ear truncation improves one-pass CD, but approximates iterative CD in HV and has larger covering radii; posthoc only.'}
    state['next_action']='Review closest archive methods and diagnose broad-feasible-set search/retention; define a strong iterative-CD control before any newly authorized optimizer campaign. Retain formal null results.'
    state_path.write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    shutil.copy2(state_path,ROOT/'provenance/aris_formal_completion_snapshot.json')
    shutil.copy2(PROJECT/'HANDOFF.md',ROOT/'provenance/HANDOFF_formal_completion.md')
    (ROOT/'provenance/formal_figure_QA.md').write_text('# 正式图形检查\n\n四组 PNG 均已打开目视检查：formal_hv_distribution、formal_factorial、formal_convergence、selected_trajectory。轴标签、图例和曲线可读，无明显文字裁切。PDF 已生成但未独立逐页渲染；不将 PNG 检查外推为 PDF 渲染检查。\n',encoding='utf-8')
    files=sorted(p for p in ROOT.rglob('*') if p.is_file() and '__pycache__' not in p.parts)
    with zipfile.ZipFile(package,'x',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in files: z.write(p,p.relative_to(PROJECT))
    with zipfile.ZipFile(package) as z:
        assert z.testzip() is None
        assert len(z.namelist())==len(files)
    result={'archive':str(package),'files':len(files),'bytes':package.stat().st_size,'sha256':hashlib.sha256(package.read_bytes()).hexdigest(),'crc_check':'PASS','original_pilot_zip_preserved':(PROJECT/'10_dynamic_mode_delivery_20260921.zip').exists()}
    package.with_suffix('.manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__': main()
