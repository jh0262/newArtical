# Retzler机器人历史补偿：第4步受控重跑

本项目执行前两步所选的两项迁移：过去速度作为关节补偿输入、低速和换向分层评价。原论文模型作为方法来源，不将本次运行称为原表4严格数值复现。

主入口：[结果报告](results/第4步_重跑分析报告.md)。实验前定义：[实验协议](实验协议.md)、[固定配置](config.json)。

## 文件

- `preflight/prepared.npz`：三个原始轨迹经过独立滤波后的位置、速度、加速度和力矩，及原位置/力矩；不使用合成数据替代实机记录。
- `physics_run/`：共同物理拟合的参数、缓存、损失、源码快照及预算状态。
- `runs/`：每模型/种子/尝试的参数、尺度、预测与参考、metrics、manifest、日志、失败与恢复记录。
- `results/`：逐运行/逐关节CSV、配对比较、覆盖、变量字典、来源核查、报告及PNG/SVG/PDF图。
- `config.json`：运行前固定的预算、种子、掩码、网络和评价口径。
- `test_contracts.py`、`test_networks.py`、`test_export.py`：数学和实现检查；初次失败及修改原因见`tdd_red_record.md`和`amendments.md`。

## 环境与复跑

计算采用现有`F:/暑假原始资料/.venv-v3/Scripts/python.exe`（Python 3.12.14），`bootstrap.py`只读加载根目录`.v3deps`。计算依赖为NumPy 2.5.2、SciPy 1.18.1、PyTorch 2.13.0+cpu。绘图依赖隔离于本项目`plot_deps`，不修改计算环境。版本见两个requirements锁定文件。

同一工作区的一条完整复跑命令，自动创建新的同级目录，不覆盖本次运行：

```powershell
& 'F:/暑假原始资料/06_projects/Retzler_History_Step4_20260928/reproduce.ps1'
```

复跑包括预处理、数学测试、物理拟合、14个运行、汇总、作图和文档核查。需要保留工作区中原始数据及源代码资源目录；它不是无需输入资料的独立安装包。既有结果不能在原目录直接重跑覆盖，脚本会拒绝已存在的运行目录。

核验范围：各计算阶段已实际执行；同种子独立预测复跑逐位一致。上述整套打包入口只做语法和文件检查，未再运行一遍完整训练。交付清单见`delivery_check.json`，不能把脚本存在视为跨环境复现已经通过。

仅从已存在预测重算结果，不训练、不积分：

```powershell
Set-Location 'F:/暑假原始资料/06_projects/Retzler_History_Step4_20260928'
& 'F:/暑假原始资料/.venv-v3/Scripts/python.exe' -X utf8 analyze.py
& 'F:/暑假原始资料/.venv-v3/Scripts/python.exe' -X utf8 render_results.py
& 'F:/暑假原始资料/.venv-v3/Scripts/python.exe' -X utf8 write_report.py
```

首次物理拟合5000次批更新，网络最多3000次批更新。达到预算保存结果并标记budget_exhausted，不代表收敛。本次比较固定三个初始化种子，不能替代独立轨迹或实机重复。未使用GPU、云计算或机器人控制器。

## 来源与许可

方法来源：Retzler等（2024），*Learning-based augmentation of physics-based models: an industrial robot use case*，DOI [10.1017/dce.2024.8](https://doi.org/10.1017/dce.2024.8)。源代码固定为[roblue提交9dd1dcb](https://github.com/ha7ilm/roblue/tree/9dd1dcbcd97bb90b3cf705250d1c2df18f8a1fe2)。

原始资源位于`../../05_evidence/20260928_robot_paper_selection/resources/`。`core.load_physics`保留原作者的机械模型，只隔离加载经检查的数学定义，不运行原大脚本的训练/绘图入口。物理函数和生成模型来自GPLv3源代码，许可副本见`SOURCE_LICENSE`；发布或再分发派生代码时遵守相应许可。公开数据来源与hash见preflight报告。

原图表用于前期阅读；本目录`results/figures`均由本次保存的计算结果生成。没有把这些图声称为真实MPC实验、摩擦机理验证或原论文复现成功。
