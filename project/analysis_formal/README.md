# 正式结果复核

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
