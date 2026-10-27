# I3外部基线与现代约束基准许可审计 v0.1

状态：`STATIC AUDIT COMPLETE / MATRIX PROPOSED NOT AUTHORIZED / 0 OPTIMIZER / 0 EVALUATOR / 0 FORMAL FFE`

## 结论

现有“CEC2006主层 + CEC2020-M4迁移候选”仍不能单独闭合完整论文实验。当前最稳妥的补强路线是：

- 现代主套件采用 COCO `bbob-constrained`，固定 `coco-experiment 2.8.2`。它包含54个单目标约束函数、6档约束规模和6个维度；每个维度有45个函数满足`m>=3`，另9个`m=1`函数可作回退边界。COCO代码和文档主许可证为BSD-3-Clause，API可单独返回逐约束向量。
- 主要外部DE基线采用“按论文独立实现的LSHADE44-IEpsilon”候选，但必须先完成版本化数学规格、干净室实现边界和预期红测试；不得复制CEC压缩包或无许可证第三方源码。
- 跨算法族随机基线采用`cma 4.4.4`的`ConstrainedFitnessAL`（BSD-3-Clause）；确定性局部控制采用当前环境的SciPy 1.18.0 COBYLA（BSD-3-Clause/PRIMA）。二者都必须经过统一评价缓存和精确FFE适配。
- CEC2020-M4继续只作为独立授权的benchmark-level工程迁移补充，不替代现代套件，也不构成物理验证。

这只是静态候选，不是已冻结实验矩阵，更不是性能结论。

## 关键许可证和身份事实

| 对象 | 身份/许可 | 当前裁定 |
|---|---|---|
| COCO `bbob-constrained` | `coco-experiment 2.8.2`；PyPI与仓库声明BSD-3-Clause；54函数、默认15实例、逐约束接口 | `FIT_WITH_PROTOCOL_AMENDMENT` |
| CEC2020官方仓 | 官方问题定义与代码可访问，但仓库页面未见许可证 | 不复制、不再分发；只保留来源定位 |
| ENOPPY 0.1.1 | GPLv3；前序项目只对RC15/16/19完成外部交叉核验，RC24不可用 | 可作受限核验依赖，不能把局部身份外推为57题全套闭合 |
| LSHADE44-IEpsilon | 2018主论文给出核心伪代码、参数和20,000D预算；未选到许可闭合源码 | 只允许独立规格/红测候选 |
| pycma AL-CMA-ES | `cma 4.4.4`，BSD-3-Clause；官方`ConstrainedFitnessAL` | 许可清楚，仍需FFE/等式/边界适配测试 |
| SciPy COBYLA | SciPy 1.18.0，BSD-3-Clause；PRIMA纯Python实现；`maxiter`为函数评价上限 | 作为非headline局部控制 |
| Pagmo self-adaptive + SADE | 许可清楚，但官方文档说明内部缓存使最终评价数“somewhat unpredictable” | 不建议进入严格等FFE主矩阵 |

## 与I3机制的适配

COCO是当前最匹配的现代许可闭合候选：它既提供逐约束残差，也系统改变约束数和活跃约束数。按其函数结构，每个目标族有6档约束规模；排除`m=1`档后得到45个`m>=3`函数，可以直接检验CVGR的适用域。`m=1`档应保留为回退控制，不能因机制不激活而删除。

但它引入两项必须先冻结的合同差异：

1. COCO分别记录目标与约束评价，而本项目把同一点的“目标 + 全约束向量”计为1 FFE。适配器必须缓存同一点结果，并强制`objective_calls == constraint_calls == formal_ffe`；任何隐藏的可行性探测或最终推荐评价都必须进入台账。
2. COCO提供可行初始解。是否把它放入初始种群会直接改变不可行历史和CVGR激活率，必须在看结果前统一冻结，不能事后调节。

## 建议矩阵层级

建议后续修订把比较器分成三层：

1. 内部归因控制：项目父算法、度保持重连、多样性匹配、标量总违反、去稳定门。
2. 同族外部基线：干净室LSHADE44-IEpsilon。
3. 跨族稳健性控制：pycma AL-CMA-ES；SciPy COBYLA只作局部确定性校准，不承担“强随机全局基线”角色。

COCO主套件、CEC2006历史套件和CEC2020-M4迁移补充必须分开形成分析族。任何新增均不得回写成原预注册已包含内容。

## 阻断门

- `EXT-MATRIX-01`：现代套件和外部基线尚未进入冻结方案；作者未选择、未授权修订。
- `COCO-FFE-02`：合并FFE与COCO双计数尚未冻结并测试。
- `COCO-INIT-03`：可行初始解政策尚未冻结。
- `LS44-ID-04`：LSHADE44-IEpsilon干净室身份和红测尚未形成。
- `BASELINE-FAIR-05`：原生种群/重启/等式/边界语义与统一预算尚未绑定。
- `CEC20-LICENSE-06`：CEC2020官方代码再分发依据仍未知。

因此下一安全动作只能是：由作者选择路线并授权“版本化方案修订准备 + 规格/红测准备”。即使获授权，也不包含安装依赖、生产实现、评价器调用、优化器运行、正式FFE、完整TCAC、Stage B、公开发布或投稿。

## 原始来源

- COCO套件与函数定义：`https://coco-platform.org/testsuites/bbob-constrained`；`https://numbbo.github.io/coco-doc/bbob-constrained/functions.pdf`
- COCO许可：`https://raw.githubusercontent.com/numbbo/coco/master/LICENSE`
- COCO 2.8.2：`https://pypi.org/project/coco-experiment/2.8.2/`
- COCO官方结果档案：`https://coco-platform.org/testsuites/bbob-constrained/data-archive.html`
- CEC2020官方页面/仓：`https://sites.google.com/view/suganthan-p-n/cec-benchmark/cec20-special-session`；`https://github.com/P-N-Suganthan/2020-RW-Constrained-Optimisation`
- CEC2020测试套件论文：DOI `10.1016/j.swevo.2020.100693`
- LSHADE44-IEpsilon主论文：`https://eng.stu.edu.cn/__local/0/FB/F0/5755E58C67310A57BF27F773376_2DF9DC24_44AEA.pdf?e=.pdf`
- pycma约束接口与许可：`https://cma-es.github.io/apidocs-pycma/cma.constraints_handler.ConstrainedFitnessAL.html`；`https://github.com/CMA-ES/pycma/blob/development/LICENSE`
- SciPy COBYLA：`https://docs.scipy.org/doc/scipy/reference/optimize.minimize-cobyla.html`
- Pagmo约束元算法说明：`https://esa.github.io/pygmo2/algorithms.html#pygmo.cstrs_self_adaptive`

机读细节见同名JSON。该审计不是法律意见。
