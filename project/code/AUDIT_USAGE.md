# 独立运行审计使用说明

本程序独立读取正式运行文件，不调用优化器、不更改raw。正式实验全部结束后运行：

```matlab
addpath(fullfile(root,'code'));
clear pade_audit_runs
report = pade_audit_runs(root);
assert(report.passed)
```

默认输出目录为`root/qa/run_audit`：

- `audit_summary.json`：机器可读结论及计数。
- `audit_runs.csv`：每项预期运行的身份、FE、数值复算、配对初值、通过状态和SHA-256。
- `audit_issues.csv`：逐项错误/警告，未通过时以此定位。
- `raw_manifest.csv`：正式raw文件逐份SHA-256及字节数。
- `frozen_file_manifest.csv`：8项冻结源码/协议及4项原始输入的独立文件哈希。
- `AUDIT_README.md`：本次审计口径。

JSON主要字段：`schema_version`、`status`、`passed`、`complete`、`expected_runs`、`loaded_runs`、`valid_runs`、`missing_runs`、`expected_search_FE`、`successful_total_FE`、`audited_valid_total_FE`、`sum_successful_run_seconds`、`paired_initialization_checks`、`paired_initialization_failures`、`deterministic_best_reevaluations`、`stochastic_F07_reevaluations_skipped`、`error_count`、`warning_count`及三类冻结hash。

正式计划应覆盖5640项运行、26项问题、30个种子，搜索FE总和194577300；应完成4860项跨变体配对初值检查、5430项确定性best_x复算，F07共210项跳过随机目标重算。这些是预期审计计数，不是本说明写入时已经完成的审计结果。

初始群体、初始f和CV按double底层uint64逐位比较。确定性复算及边界/网格采用64*eps乘数值尺度的机器精度容差；CV的零/非零可行性身份严格核对，不将容差改为求解器可行性容差。Deb历史按严格CV==0检查，不要求不可行阶段目标值单调。

Windows默认使用原生.NET SHA256流式哈希，已在本机MATLAB验证，不依赖JVM、Python或逐文件shell进程；其他平台使用Java MessageDigest。该审计工具不属于冻结优化器核心，不改变正式运行所附冻结code_hash。

可先运行独立的小型审计器自检：

```matlab
clear pade_audit_runs test_pade_audit_runs
fixture = test_pade_audit_runs(root);
assert(fixture.passed)
```

自检仅在qa/audit_fixture_时间戳中创建两份明确标注synthetic的8FE记录；不执行优化器、不读取正式raw。覆盖干净样本通过以及8项错误注入：初值位差异、目标复算差异、严格可行性身份变化、FE差异、冻结hash差异、越界、计数不闭合、Deb历史恶化。夹具结果不能作为正式实验数据。

`AllowPartial=true`仅适合故障排查；缺少预期运行的状态为partial，不可作为正式完成依据。`StrictPlan=false`和`CheckFrozenFiles=false`仅用于明确标注的夹具或诊断，不应用于最终论文审计。
