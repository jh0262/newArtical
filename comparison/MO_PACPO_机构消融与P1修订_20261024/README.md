# MO-PACPO机构消融与P1单栏修订

本目录承接P2复审报告R1/R2，保持MO-PACPO主轴投影、超体积双锁、档案维护及2PPaPaR刚体3T1R四尺寸三目标范围。原文、原程序和历次结果均保留。

主文档：`MO_PACPO_机械工程学报_机构消融与P1修订稿_单栏.docx`。修改及实际结果见`P1修订与机制贡献记录.md`。

## 实验与入口

种子400001—400030，每配置30次，N=100、G=250、FE=25100。Full复用已存结果并完整评价带重放；新增Diagonal/noNoise共60次搜索，保持全部原参数。noLock作为既有配对参照。新运行和原Full均保存仪器化分量，60次新增搜索共1 506 000次评价。每个最终档案均在262144和1048576个共同积分点下重算、筛选与评价。

```matlab
cd('F:\暑假原始资料\论文总项目_20261013\MO_PACPO_机构消融与P1修订_20261024')
reproduce_mechanism_revision
```

已有同源码结果复用；缺失项才运行。全部运行完成后再生成统计。依赖MATLAB R2025b、Statistics and Machine Learning Toolbox、Parallel Computing Toolbox。单次方法调用可使用：

```matlab
addpath('code','code/reference')
p=P3Core.problem('PPAR');
c=P3Variants.config('Diagonal',400001);
result=P3Core.solve(p,'PACPO',c);
```

上例会真实执行一次完整搜索；批量复现入口另含冻结核对、缓存、失败状态和档案复核。性能报告使用批量记录，不以日志重放增加重复数。

## 文件组织

- `PROTOCOL.md`：运行前确定的配对、统计族、积分设置及分析范围。
- `code/`：原程序另存的仪器化实现；搜索公式、参数、随机抽样顺序保持，新增13列分量日志。`P3Tape`用于逐点断言的已存评价重放，普通搜索默认关闭。
- `freeze.mat`：源程序、协议及软件版本快照。
- `results/runs/`：90个结果及成功/失败状态，其中60个新搜索、30个Full精确重放。
- `validation/`：90组最终档案共同积分结果；noLock复用相邻P1目录。
- `data/`：逐次指标、配对统计、bootstrap索引、完整收敛与算子轨迹、论文数据。
- `analyze_mechanisms.m`、`verify_analysis.py`：MATLAB分析及NumPy独立复核。
- `verify_mask_covariance.m`：64种掩码事件的确定性协方差验证。
- `make_mechanism_figure.m`：由真实数据生成科学图。
- `build_revision.py`：保留原生公式、文献和原图的Word修订脚本。
- `audit/`：源哈希、提案契约、重放验证、文字变更、表达检查、内容保全和原生渲染。

依赖相邻保留目录`MO_PACPO_P1修正版_20261024`、`MO_PACPO_P2单栏修订_20261024`和`MO_PACPO_搜索机制改进_20261024`。不要将本目录单独搬走后假定既有结果和单栏源稿仍可用。

## 论文复现

MATLAB全部完成后，使用包含numpy、python-docx、lxml、pypdfium2及Pillow的Python：

本机也可直接执行`rebuild_paper.ps1`，它使用已经验证的绝对Python路径，按以下顺序重建论文：

```powershell
python -X utf8 .\verify_analysis.py
python -X utf8 .\build_revision.py
.\render_word.ps1
python -X utf8 .\render_preview.py
python -X utf8 .\final_check.py
python -X utf8 .\finish_revision.py
```

Word原生渲染需要本机Microsoft Word。渲染只读打开新稿，不改源稿。`setup_revision.py`记录最初生成仪器化副本的过程，已冻结版本无需重新执行。
