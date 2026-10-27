from pathlib import Path
import json,re,shutil,hashlib
R=Path(__file__).resolve().parent;OLD=R.parent/'jme_review_20260929';D=R/'delivery'
D.mkdir(exist_ok=True);(R/'input').mkdir(exist_ok=True)
src=OLD/'delivery/论文三轮修订稿.md';frozen=R/'input/manuscript.md'
if frozen.exists():assert frozen.read_bytes()==src.read_bytes()
else:shutil.copy2(src,frozen)
t=src.read_text(encoding='utf-8')
# Insert two equations after original (4); update every original reference first.
t=re.sub(r'\\tag\{([5-9])\}',lambda m:r'\tag{'+str(int(m[1])+2)+'}',t)
t=re.sub(r'式\(([5-9])\)',lambda m:'式('+str(int(m[1])+2)+')',t)
anchor='### 1.4 历史输入的可区分变化'
proof=r'''命题2：对于重复输入网络，在各重复列对称初始化、各列Adam一阶和二阶矩初态相同的条件下，可以构造单输入网络，使两者在精确算术下保持相同的输出函数序列。该命题要求相同小批量及其顺序、Adam矩衰减系数、偏差修正时刻和分母常数，并采用耦合L2形式的权重衰减；裁剪施加于数据梯度，再加入L2项。

把第一层和跳跃层的有效列和合并记为参数块w，其余参数记为θ，数据梯度分别为g_w和g_θ。重复网络的每列数据梯度为g_w，其全局范数可在单输入网络中写为

$$
G=\sqrt{K\|g_w\|_2^2+\|g_\theta\|_2^2},\qquad c=\min\{1,\gamma/(G+\varepsilon_c)\}. \tag{5}
$$

其中γ为裁剪阈值，ε_c为实现中的正分母常数；对矩阵参数采用向量化后的二范数。两网络均将数据梯度乘以同一个c。单输入网络对w设置学习率Kη、L2系数λ/K，对θ维持η和λ。令经偏差修正的一阶、二阶矩为m̂、v̂，则每一重复列与有效参数的递推满足

$$
w_l=w/K,\quad \widetilde g_l=cg_w+\lambda w/K=\widetilde g_w,\qquad
w^+=w-K\eta\frac{\widehat m}{\sqrt{\widehat v}+\varepsilon_A}. \tag{6}
$$

式(6)中的平方、开方和除法按元素进行，ε_A为Adam分母常数。由各列相同的梯度及矩初态，可得各列矩递推相同；它们的更新量相加等于单输入块采用Kη的更新。其余参数的数据梯度、L2项及更新规则相同。对迭代次数归纳，即得到输出函数序列相同。若使用单输入网络未经加权的普通全局梯度范数，则裁剪系数一般不同，等价性不再由上述证明保证。

本命题给出一个可执行的优化对照条件，不把当前D/V训练自动视为等价。本文原训练仅首列随机、其余列为零，且使用共同学习率而非上述参数块映射，不满足命题条件。耦合L2下非对称列还会产生不同的一阶和二阶矩。该分析也不直接适用于解耦权重衰减、改变裁剪顺序或额外随机层的训练。

'''
assert anchor in t;t=t.replace(anchor,proof+anchor)
anchor='128 ms历史矩阵的第一主成分解释比'
pos=t.index(anchor)
results='''命题2使用训练轨迹上的同一组200个小批量进行成对实现核验，批量256、K=7、η=10⁻⁴、λ=10⁻⁵、γ=100；Adam矩衰减系数为(0.9,0.999)，ε_A=10⁻⁸、ε_c=10⁻⁶，矩状态从零开始。在列对称、参数块映射和加权裁剪均匹配时，归一化网络输出的最大绝对差为2.66×10⁻¹⁵，有效参数最大差为2.44×10⁻¹⁵，59步实际触发裁剪。把参数块学习率改为统一η后，最大输出差为0.2699；仅将单输入裁剪范数改为普通范数后为0.1045；仅改为首列随机、其余零的非对称初始化后为1.43×10⁻⁸。最后一项只说明当前数值实现不再保持精确等价，其幅度不足以推断有工程意义的性能变化。这些核验使用单独初始化的网络副本，不修改表2中的检查点，也不使用验证或测试结果进行更新及选择；它们验证优化递推，不构成新的预测性能比较。

'''
t=t[:pos]+results+t[pos:]
t=t.replace('式(3)与式(4)提供了优化混杂的具体解释，但没有识别各因素对最终误差的贡献比例。','式(3)至式(6)分别说明参数冗余、普通梯度更新及Adam路径匹配的条件，但没有识别各因素对最终预测误差的贡献比例。命题2使瞬时网络的优化对照可以执行核验；原候选训练不满足其条件，因此不能用理论核验替代重新设计的公平性能比较。')
t=t.replace('新增参数不扩大其函数类，却改变输入层的正则化和优化几何。','新增参数不扩大其函数类，却改变输入层的正则化和优化几何。对于列对称初始化的特例，按参数块匹配Adam学习率、耦合L2系数及加权梯度裁剪，可恢复单输入与重复输入网络的输出函数序列等价；训练批次上的200步核验符合该递推关系。')
t=t.replace('推导重复输入的函数折叠与正则化关系，','推导重复输入的函数折叠、正则化及特定条件下的Adam路径等价关系，')
t=t.replace('An exact folding relation and the associated regularization effects are derived.','An exact folding relation, regularization effects, and sufficient conditions for equivalent Adam updates are derived.')
t=t.replace('表1给出核心对照。','表1给出核心对照。命题2的优化递推核验采用独立网络副本，仅检验理论实现；下述预测性能实验仍使用既有候选及原选择规则。')
(D/'论文第四轮修订稿_理论更新.md').write_text(t,encoding='utf-8')
shutil.copytree(OLD/'delivery/figures',D/'figures',dirs_exist_ok=True)
print('Prepared theory revision; equations=',len(re.findall(r'\\tag\{\d+\}',t)))
