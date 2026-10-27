# I3/CVGR 冻结 TDD 覆盖审计 v0.1

状态：`FAIL_PREIMPLEMENTATION_COVERAGE`  
审计方式：静态逐条映射；未执行 pytest、优化器或任何 FFE。

## 结论

冻结方法规范第 12 节的 10 项 TDD 要求中，8 项已有直接或固定夹具证据，1 项只覆盖单一回退原因，1 项未完整覆盖。阻断项是规范明确要求的四类回退中，`COMPLETE_GRAPH` 没有测试，`UNSTABLE_GRAPH` 只验证了 weighted Jaccard 算术，没有验证实际 `fallback_reason`。

此外，规范共声明 9 个回退原因，目前只有 `TOO_FEW_CONSTRAINTS`、`INSUFFICIENT_ACTIVE_CONSTRAINTS` 和 `EMPTY_GRAPH` 的结果被断言。`NO_VALID_PAIR` 等路径没有验证是否保持父 SHADE 的 `base_rng` 与供体完全等价。

因此，实现授权候选 v0.1（SHA-256 `DA8FD2A9CCE6B72BF52D6B0D9EC3480B9247749B6A541BF445311DD2686C57A6`）应保持原字节作为审计记录，但当前处置为 `HOLD_DO_NOT_AUTHORIZE_AS_WRITTEN`。

## 必须先补的红测契约

1. `COMPLETE_GRAPH` 实际回退原因；
2. `UNSTABLE_GRAPH` 实际回退原因；
3. `HISTORY_TOO_SHORT`；
4. `SINGLE_COMMUNITY`；
5. `NO_STABILITY_REFERENCE`；
6. `NO_VALID_PAIR` 且与父 SHADE 的供体和 `base_rng` 状态完全一致；
7. 对所有能进入供体选择的未激活原因参数化检查精确父算法回退。

这些是对冻结 TDD 合同的加法修订，不改变方法方程、阈值、种子、实验矩阵、预算、统计终点或 kill criteria。修订前不得创建新测试、生产实现或运行测试。

完整机读映射见 `governance/tdd_coverage_audit_I3_CVGR_v0.1.json`。
