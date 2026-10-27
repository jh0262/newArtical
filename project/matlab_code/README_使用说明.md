# MATLAB 程序使用说明

## 主程序

运行：

```matlab
electric_cylinder_surrogate_optimization
```

程序会自动完成：

1. 读取样本数据，或在没有样本数据时用解析模型生成演示数据；
2. 训练响应面模型（RSM）、Kriging 模型和随机森林模型；
3. 计算 R2、RMSE、MAE、MAPE；
4. 生成代理模型对比图、预测值-真实值图、残差图、响应面图；
5. 调用代理模型进行多目标优化，默认采用加权多目标差分进化算法；
6. 输出 Pareto 解、折中最优解和优化前后对比图。

## 数据文件格式

如果已有有限元或试验样本，请在本目录放置以下任一文件：

- `electric_cylinder_samples.xlsx`
- `electric_cylinder_samples.csv`

列名必须包含：

| 列名 | 含义 |
|---|---|
| d_s | 滚珠丝杠直径 / mm |
| P_h | 丝杠导程 / mm |
| L_n | 螺母长度 / mm |
| F_p | 预紧力 / N |
| d_r | 输出杆直径 / mm |
| L_g | 导向套长度 / mm |
| t_c | 缸体壁厚 / mm |
| k_total | 等效轴向刚度 / N/mm |
| delta | 最大变形 / mm |
| sigma | 最大等效应力 / MPa |
| eta | 总传动效率 |
| mass | 总质量 / kg |
| life_h | 寿命 / h |

## 论文图片输出

运行后会自动生成 `figures` 文件夹，主要输出包括：

- `fig_metric_R2.png`：不同代理模型 R2 对比图；
- `fig_metric_RMSE.png`：不同代理模型 RMSE 对比图；
- `fig_pred_true_*.png`：预测值与真实值对比图；
- `fig_residual_box.png`：残差箱线图；
- `fig_response_surface_*.png`：响应面图；
- `fig_pareto_3d.png`：Pareto 解集三维图；
- `fig_pareto_mass_delta.png`：Pareto 投影图；
- `fig_before_after.png`：优化前后对比图；
- `fig_de_convergence.png`：差分进化算法收敛曲线。

## 工具箱需求

建议安装：

- Statistics and Machine Learning Toolbox：用于 `fitlm`、`fitrgp`、`TreeBagger`；
- Global Optimization Toolbox：可选，仅在主程序中将 `optimizerMethod` 改为 `"GA_MULTI"` 时用于 `gamultiobj`。

默认算法为自编写的加权多目标差分进化算法，不依赖 `gamultiobj`。

## 当前版本关于寿命指标的处理

程序仍会训练并评价 `life_h` 的代理模型，但如果该指标的 `R²` 为负或明显偏低，不建议将其纳入优化目标或硬约束。当前主程序已经将多目标优化限定为：

```text
mass, delta, sigma, k_total, eta
```

`life_h` 仅作为后验参考指标输出。若后续需要把寿命作为正式优化目标，应增加样本数量、改进寿命计算模型，或对寿命响应进行对数变换后重新训练代理模型。

## 写入论文时的建议

程序自带的解析样本仅用于跑通流程和绘图示例。正式论文中，建议将有限元仿真或试验结果整理为 `electric_cylinder_samples.xlsx`，再运行程序获得代理模型精度对比和优化结果。
