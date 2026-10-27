# I3/CVGR 正式实验资源可行性审计 v0.1

状态：`STATIC RESOURCE AUDIT / NO INSTALL / NO EXECUTION / ZERO FORMAL FFE`

## 结论

内部实验的 run 数与 FFE 可以精确核算，但当前尚不能证明这台工作站能在可接受时间、内存和磁盘边界内完成论文级全实验：

> `INTERNAL_RUN_COUNTS_ARE_ARITHMETICALLY_KNOWN_BUT_EXECUTION_RESOURCE_FEASIBILITY_IS_UNVERIFIED`

当前没有完整 optimizer/evaluator、没有真实 aggregate FFE/s、没有 run-package 大小分布，也没有现代基准依赖。S6-E0、依赖安装和正式执行继续 HOLD。

## 本机只读快照

- CPU：Intel Core i7-13700；24 个逻辑处理器；物理核心数与总内存因权限限制标为 `UNAVAILABLE`，不从型号推断。
- F 盘：约 945.45 GiB 可用，但尚无项目 quota。
- Python 3.14.7；NumPy 2.5.2；SciPy 1.18.0；pytest 9.1.1。
- NumPy 使用 OpenBLAS 0.3.34，单进程最多 24 threads；`OMP_NUM_THREADS`、`OPENBLAS_NUM_THREADS` 等均未锁定。
- `coco-experiment`、`cma/pycma`、pandas、statsmodels、PyGMO 均未安装；本轮没有安装或下载。

## 内部实验精确包数

若 Ray-style 控制进入 M 与 C1 主比较：

| 阶段 | 运行包 | 正式 FFE |
|---|---:|---:|
| M：12题×8变体×30 seeds | 2,880 | 60,480,000 |
| C1：16题×5变体×30 seeds | 2,400 | 238,500,000 |
| F：8题×2变体×30 seeds | 480 | 26,400,000 |
| 核心合计 | 5,760 | 325,380,000 |
| 可选 C2 | 1,440 | 143,100,000 |
| 含 C2 合计 | 7,200 | 468,480,000 |

Ray 的具体放置尚未获授权，上表是支撑窄化主张时的推荐情景，不是已冻结矩阵。

## 现代 COCO 的规模风险

已知候选套件为每维 54 functions、6 个维度 `{2,3,5,10,20,40}`、默认 15 instances。未冻结的是 dimensions、instances、算法 seed、单次预算、restart、Ray 是否加入以及统计单位。

如果仅作规模演示，假设全部官方维度和 instances、5 个算法、每 instance 一次随机实现、`10,000D`：已有 **24,300 runs / 3.24×10^9 FFE**。若再机械复制 30 seeds，则变成 **729,000 runs / 9.72×10^10 FFE**；加入 Ray 第六算法会继续上升。这些数值说明必须先定义 instance 与 stochastic seed 的统计角色，不能把内部 30-seed 规则无判断地复制到 COCO。

## 假设吞吐量下的时间量级

下表只做容量敏感性，不是本机测速：

| 范围 | 100 aggregate FFE/s | 1,000 aggregate FFE/s | 10,000 aggregate FFE/s |
|---|---:|---:|---:|
| 内部核心 325.38M | 37.66 d | 3.77 d | 9.04 h |
| 内部含 C2 468.48M | 54.22 d | 5.42 d | 13.01 h |
| COCO 演示 3.24B | 375 d | 37.5 d | 3.75 d |
| COCO 30-seed 演示 97.2B | 30.82 y | 3.08 y | 112.5 d |

真实预测必须等完整实现冻结后，通过单独授权的 evaluator-bearing 校准获得 aggregate FFE/s。所有真实 evaluator call 必须计入 FFE，不能把校准改名成“零 FFE 测试”。

## 存储边界

若仅作 30% 余量演示，可用于项目的空间约 661.82 GiB：

- 7,200 个内部包平均上限约 94.12 MiB/包；
- 24,300 个 COCO 包约 27.89 MiB/包；
- 729,000 个 COCO 包只剩约 0.93 MiB/包。

但当前 S6-I4 刻意生成 0 个正式包，所以 package size 没有实测证据。未来校准必须测 median/p95 包大小、日志、checkpoints、failure artifact、hash/close/resume 开销，再由作者批准资源额度。

## 后续资源门

在七门整合包确认、所有修订冻结、完整实现/依赖环境绿相之后，另行准备 `S6-E0-X0` 校准授权。它至少测：

- 单 worker 与受限多 worker 的 aggregate valid FFE/s；
- CVGR 相对 parent 的图开销；
- 每 worker 峰值内存；
- closed-package median/p95 bytes；
- hash、close、resume 和失败恢复时间；
- 相同 seed 重复运行的确定性一致性。

正式 M 的资源放行应满足：`planned FFE / measured aggregate throughput × contingency` 与 `run keys × p95 package bytes × contingency` 均在作者明确接受的时间/磁盘范围内，而且全部完整性门通过。

## 证据边界

本轮没有安装依赖、调用 optimizer/evaluator、产生正式运行包、读取结果或测量算法性能。所有时间行都是吞吐量假设，不是实测预测；正式 FFE 仍为 0。
