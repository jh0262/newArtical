# I3-CVGR 增量 TDD v0.2 冻结接受核验回执

- 授权标识：`AUTH-I3-FREEZE-ADDITIVE-TDD-20260831T065459+0800`
- 作者决策：`P=FREEZE_ADDITIVE_TDD_V0_2`；`C=DO_NOT_AUTHORIZE_PRODUCTION_IMPLEMENTATION`；`E=DO_NOT_AUTHORIZE_OPTIMIZER_EXECUTION`；`F=KEEP_FORMAL_FFE_ZERO`
- 冻结接受记录：`governance/freeze_acceptance_I3_CVGR_v0.2.json`
- 冻结接受记录 SHA-256：`21CE295D9BD6CFEAF209D787E178B72B6E71E43B5B238D37BBC3822CA94AB563`

## 冻结对象

- 候选：`governance/freeze_candidate_I3_CVGR_v0.2.json`
- 候选 SHA-256：`345AFBA8F403A6240977DE2B2EB8B11E09FDF7B29C4C5B54CFA4A19B9CFF5988`
- 用户声明哈希与本地实算哈希：一致
- 增量工件：5 项，冻结前哈希不匹配 0 项
- v0.1 基线归档 SHA-256：`6AC43CB831B5965CC5EB408E45C6D790859A74A6E10DFBB1091C13E9DC5E8F45`
- v0.1 基线归档与现场目录：38/38 文件一致

## 不可变快照

- 快照目录：`governance/frozen/I3_CVGR_tdd_v0.2_345AFBA8_snapshot`
- 清单 SHA-256：`68687981517461111996122B86A2257600DF6F5C5CB6859EF035E5053280139A`
- ZIP：`governance/frozen/I3_CVGR_tdd_v0.2_345AFBA8_snapshot.zip`
- ZIP SHA-256：`CBFBC21E2CD664B870D81C826858853372A2918BFD8137FB4EBE941EF986C98F`
- ZIP 大小：107,144 字节
- 文件：54 项（53 项清单绑定文件及清单本身）

## 空目录恢复

独立空目录恢复后，54/54 文件的路径、字节数与 SHA-256 全部匹配，缺失/多余文件为 0；`src/alg1_replan` 仍不存在。恢复后的 6 个测试文件全部因预期的 `ModuleNotFoundError: No module named 'alg1_replan'` 在收集阶段停止，无意外通过。未运行优化器，未调用目标或约束函数，正式 FFE 保持 0。

恢复核验记录：`governance/freeze_restore_verification_I3_CVGR_v0.2.md`，SHA-256 `6D212529270E8177E1E1EAD4CF24361091FE98623B45C80D26E56EA7130E3D0E`。

## 已披露的记录差异

冻结候选及红相回执记载 pytest 退出码为 `1`；本轮在现场目录与独立恢复目录直接读取 pytest 进程退出码均为 `2`。六个收集错误的数量、类型、缺失模块和红相语义完全一致。为保持作者按哈希冻结的字节不被改写，本差异作为 provenance warning 保留，冻结核验结论为：

`STRUCTURAL_PASS / EXPECTED_RED_SEMANTICS_MATCH / PROVENANCE_WARN_EXIT_CODE`

这不是算法正确性或性能证据，也不授权修绿。

## 当前边界

状态已变更为 `FROZEN_ADDITIVE_TDD_v0.2`。生产实现、绿相测试、优化器/基准/M/C1/F/C2、任何正式 FFE、依赖安装、Git 初始化、公开发布和投稿均仍未授权。下一步只能生成并等待作者确认新的、单独哈希绑定的生产实现授权候选。
