# I3 冻结方案综合一致性裁决候选 v0.2 验证回执

- 候选文件：`governance/frozen_plan_consistency_decision_candidate_I3_CVGR_v0.2.json`
- 候选 SHA-256：`0659DAF6D3918C400D5764F59D16A5FA87EE71C11EE9FBD9F8DB330F2D0662D6`
- 绑定全量合同审计：`governance/frozen_plan_full_contract_audit_I3_CVGR_v0.2.json`
- 审计 SHA-256：`80BA3F3592D10E82F93E1C1DAAA379B24BAC326FCEEC0D61F42078F1F207C29D`
- 原冻结方案候选 SHA-256：`79F23915AAE5853B01EFFB095AA6448CE1C7A5F7F0A3D0166DBE0A119AA684B3`
- 原冻结快照 ZIP SHA-256：`6AC43CB831B5965CC5EB408E45C6D790859A74A6E10DFBB1091C13E9DC5E8F45`
- 验证日期：`2026-08-31`

## 确定性检查

1. 两个 JSON 文件均可由 PowerShell `ConvertFrom-Json` 解析。
2. 候选绑定审计哈希与现场 `Get-FileHash -Algorithm SHA256` 一致。
3. 原冻结方案接受记录仍绑定 `79F23915...AA684B3`，原快照未编辑、未替换。
4. 全量复跑结果：实验矩阵 linter `exit 0`（11 行、结构齐全、1 项 multiplicity warning）；target-chain `exit 0/PASS`；failure-tree `exit 0/PASS`；research-package final `exit 1/FAIL`，原因是冻结前 handoff 授权字段仍为 false/空日期。
5. 审计确认三项作者级科学冲突：M 预算 `2,000D` 对 `10,000D`；H1 固定四检查点中位数对首次激活/时间加权；方法全称 `Co-Violation Graph Recombination SHADE` 对 `Constraint-Violation Graph Representation SHADE`。
6. 审计确认三项活跃一致性文件的当前哈希不等于冻结清单；差异为后冻结状态措辞更新。候选只允许新增版本化绑定，不允许回改冻结快照或把当前活跃副本冒充原冻结字节。
7. 本轮未创建 S6-E0 规格、夹具、红测或生产实现；未调用 optimizer/evaluator/benchmark；未创建正式运行包；正式 FFE 保持 `0`。

## 当前效力

该文件仅证明候选字节、绑定关系和静态审计结果可复核，不表示作者已经选择任何事实，不表示修订已形成或冻结，也不授权 S6-E0、optimizer/evaluator、M/C1/F/C2、公开发布或投稿。

## 建议的作者确认文本

`我确认I3冻结方案综合一致性裁决候选v0.2，SHA-256为0659DAF6D3918C400D5764F59D16A5FA87EE71C11EE9FBD9F8DB330F2D0662D6；B=SELECT_M_2000D；H=SELECT_H1_FIXED_CHECKPOINT_MEDIAN；N=SELECT_NAME_CO_VIOLATION_GRAPH_RECOMBINATION；S=AUTHORIZE_ADDITIVE_POST_FREEZE_PROVENANCE_BINDING；A=AUTHORIZE_VERSIONED_PLAN_AMENDMENT_PREPARATION_ONLY；R=HOLD_S6_E0_RED_PHASE_UNTIL_AMENDMENT_FROZEN；G=AUTHORIZE_LOCAL_GIT_COMMITS_NO_REMOTE；E=DO_NOT_AUTHORIZE_OPTIMIZER_OR_EVALUATOR_EXECUTION；F=KEEP_FORMAL_FFE_ZERO`
