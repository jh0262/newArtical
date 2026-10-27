# H14 复现清单

- [x] MATLAB `RandStream('mt19937ar',Seed,...)` 隔离景观与算法随机流；生成器不得改变全局 RNG。
- [x] 记录 MATLAB 版本、操作系统、CPU、源码 SHA-256、设计与 seed manifest SHA-256。
- [x] 冻结景观 seed 814001–814016、算法 seed 815001–815010、N=100、budget=10000。
- [x] 每个 run bundle 保存初始种群、schedule seeds、NFE、trace、final population/archive、truth-use audit 和恢复状态。
- [x] oracle 与 algorithm-facing benchmark 分离；仅 observer 可读取 allowed states/centers/component labels。
- [x] B5R 与 B5S 的注入次数、注入代数、selected rows 和 schedule seeds 契约测试通过；证据见 `tests/test_mdt_h14_b5r.m`。
- [ ] 从空目录按 manifest 恢复 H14 源与配置，并复跑单元测试。
- [x] 已生成6720行 run matrix、分析代码 hash 和预检环境报告；当前为 freeze candidate，仍需独立空目录恢复验证后才能成为正式冻结。
- [x] PYTHONHASHSEED：MATLAB 正式 runner 不调用 Python，标记 N/A；若后处理使用 Python，则固定并记录该值。
- [x] cuDNN：本研究为 CPU MATLAB 解析评估，无 GPU/cuDNN，标记 N/A。
- [x] DataLoader：无 Python DataLoader；若未来引入，必须固定 worker 数和 worker seeds。
