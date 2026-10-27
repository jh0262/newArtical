"""Integrate the actually completed conditional friction check, preserving base results."""
from pathlib import Path
import json,hashlib
R=Path(__file__).resolve().parent;D=R/'delivery';p=D/'论文第四轮修订稿.md'
t=p.read_text(encoding='utf-8');d=json.loads((R/'r5_diagnostic/results.json').read_text())
def val(model,split):return next(r['acc_nmse'] for r in d['metrics'] if r['model']==model and r['split']==split)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert all(sha(Path(k))==v for k,v in d['input_hashes'].items())
assert '### 2.6 ' not in t and '### 3.9 ' not in t
method='''### 2.6 固定惯性下的摩擦参数诊断

针对物理基底误差，固定惯性、液压参数及原数据分割，单独检查源模型的速度摩擦形式。每关节摩擦由速度、双曲正切和常数三项线性组合，分别对应黏性、平滑库仑及偏置系数；双曲正切的速度尺度为1 rad/s。将18个系数通过M⁻¹映射为加速度，按原训练加速度标准差加权，仅用训练轨迹排除32点后的样本作有界线性最小二乘。两组约束分别沿用原参数界限，以及保留黏性和库仑系数非负、取消有限上界并令偏置自由。后者仅作约束敏感性诊断，不代表真实摩擦辨识。原验证及测试仅评价固定系数；该事后分析仅在单独诊断中估计18个摩擦系数，原候选及主评价使用的参数保持不变，也不视为新的独立确认。

'''
t=t.replace('## 3 结果',method+'## 3 结果',1)
reduction=100*(1-val('same_bounds','train')/val('original','train'))
qmax=max(x['inverse_motor_torque_max'] for x in d['checks'].values())
paragraph=(f'### 3.9 物理基底失配的条件排查\n\n'
 f'三个原始分割共45000个采样点的分量组装与动力学函数一致，正逆动力学还原的最大电机力矩差为{qmax:.3e} N·m，摩擦重构的最大加速度差小于5×10⁻¹⁵ rad/s²；缓存惯性矩阵与无摩擦基底加速度逐元素一致。这些结果排除了所检实现之间的不一致，不验证真实机器人的坐标、参数或测量正确性。\n\n'
 f'固定惯性后，原摩擦参数与相同界限条件解的训练加速度NMSE分别为{val("original","train"):.6f}和{val("same_bounds","train"):.6f}，降幅仅{reduction:.4f}%；放宽界限后为{val("nonnegative_relaxed","train"):.6f}。两次有界求解的约束最小二乘最优性残差均小于4×10⁻¹¹；该值为互补条件处理后的梯度无穷范数，依赖目标与参数尺度，不是预测误差容限。对应原测试NMSE依次为{val("original","test"):.6f}、{val("same_bounds","test"):.6f}和{val("nonnegative_relaxed","test"):.6f}，仍远高于训练均值预测的{val("training_mean","test"):.6f}。验证集NMSE依次为{val("original","validation"):.6f}、{val("same_bounds","validation"):.6f}和{val("nonnegative_relaxed","validation"):.6f}，不存在一致的验证改善。因而，在固定惯性与这类静态摩擦形式下，仅继续优化18个摩擦系数或放宽其幅值边界不足以消除大部分误差；该结论不排除惯性—摩擦联合拟合不足或遗漏结构。\n\n')
t=t.replace('## 4 讨论',paragraph+'## 4 讨论',1)
old='共同物理模型及补偿网络的加速度NMSE远高于常值预测基准，且训练收敛尚未验证，神经补偿可能主要用于修正宽泛的物理失配。这一条件有利于固定比较背景，却削弱了把补偿解释为特定摩擦现象的可信度。下一阶段应先检查坐标、传动、参照加速度处理与参数可辨识性，再在独立记录上评估重新校准的物理基底；不能把减小训练损失直接等同于获得真实惯性参数。'
new='共同物理参数冻结统一了比较背景，但其加速度失配削弱了把神经补偿解释为特定摩擦现象的可信度。第3.9节已检查实现一致性，并将摩擦子问题的优化不足及有限幅值边界限定为不能单独解释大误差的因素。惯性参数中多个分量达到约束边界，原结构又不含动态摩擦与柔性状态；现有结果尚不能区分惯性—摩擦联合拟合、遗漏物理过程和参照信号处理各自的作用。重新校准仍需物理一致性约束及独立记录验证，训练损失降低不等于获得真实惯性参数。'
assert old in t;t=t.replace(old,new)
t=t.replace('现有试验不能进一步确定三者各自的责任。','第3.9节对其中的物理基底作有限的条件排查，仍未识别三者各自的责任。')
p.write_text(t,encoding='utf-8')
summary=json.loads((D/'result_summary.json').read_text());summary['manuscript_sha256']=sha(p);summary['conditional_friction_diagnostic']=d['metrics'];(D/'result_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print('Integrated conditional friction diagnosis; original predictions and main tables unchanged.')
