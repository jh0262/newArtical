# I3/CVGR Stage 6 实现授权候选 v0.1 核验回执

- 生成时间：2026-08-30T21:40:18+08:00
- 候选状态：`PROPOSED_NOT_AUTHORIZED`
- 候选文件：`governance/implementation_authorization_candidate_I3_CVGR_v0.1.json`
- 候选 SHA-256：`DA8FD2A9CCE6B72BF52D6B0D9EC3480B9247749B6A541BF445311DD2686C57A6`
- 只读预检 SHA-256：`BBFE88C8B6F86CC7B480E20FC59C072022AD89944262BF51AA5D295A02C7B8AB`

## 绑定核验

- 冻结候选：`79F23915AAE5853B01EFFB095AA6448CE1C7A5F7F0A3D0166DBE0A119AA684B3`，匹配。
- 冻结接受记录：`803123E861A6E0C7ADCDBCB56A9345E9E1D3AB6ADD809A6C40BB8AEBC1F2B5B8`，匹配。
- 不可变快照归档：`6AC43CB831B5965CC5EB408E45C6D790859A74A6E10DFBB1091C13E9DC5E8F45`，匹配。
- 13 项实现输入和 TDD 红测文件：13/13 哈希匹配，0 项不一致。
- 当前生产包 `src/alg1_replan`：不存在。
- 当前 `pyproject.toml`：0 字节，尚未配置实现环境。
- 项目根 Git provenance：不可用；候选将其列为独立作者决策，不会静默初始化。
- 正式优化器运行：0；正式 FFE：0。

## 候选授权边界

若作者接受全部推荐决策，只允许建立冻结确定性核心、运行四份冻结单元契约测试、生成代码哈希和 TDD 绿灯回执，并可在明确接受 `G` 时初始化无远程的本地 Git。仍不允许任何优化器循环、pilot/smoke benchmark、M/C1/F/C2、Stage B、完整 TCAC、正式 FFE、网络安装、远程/付费执行、公开发布或投稿。

单元测试中的合成算术和账本 mock 不属于正式算法 FFE，不得被报告为优化器实验。任何冻结测试/夹具/方案字节变化，或任何需要调用目标/约束评价器的需求，都会触发硬停止并返回作者重新决策。

Light 通用决策门当前因安装包缺少 `_shared.decision_contract` 而不可用；该状态记为 `UNAVAILABLE`，不是 `PASS`。本候选依靠项目内 SHA-256 绑定供作者审阅。

## 可复制确认语句

```text
我确认I3实现授权候选v0.1，SHA-256为DA8FD2A9CCE6B72BF52D6B0D9EC3480B9247749B6A541BF445311DD2686C57A6；I=AUTHORIZE_IMPLEMENTATION_ONLY；T=AUTHORIZE_DETERMINISTIC_UNIT_TESTS_ONLY；G=AUTHORIZE_LOCAL_GIT_INIT_NO_REMOTE；E=DO_NOT_AUTHORIZE_OPTIMIZER_EXECUTION；F=KEEP_FORMAL_FFE_ZERO
```

该语句只有在作者主动发送后才构成新授权；本回执本身不改变当前“不授权实现、不授权执行”的状态。
