from pathlib import Path
import hashlib, json, difflib, shutil
R=Path(__file__).resolve().parent
F=R/'review/frozen'
src=R/'delivery/论文重构修订稿.md'
dst=F/'论文重构小修稿.md'
assert not dst.exists(), 'Do not replace frozen reviewer version'
shutil.copy2(src,dst)
old=F/'论文重构送审稿.md'
patch=''.join(difflib.unified_diff(old.read_text(encoding='utf-8').splitlines(True),src.read_text(encoding='utf-8').splitlines(True),fromfile='08f4送审稿',tofile='小修稿'))
(F/'小修差异.patch').write_text(patch,encoding='utf-8')
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
(F/'minor_hashes.json').write_text(json.dumps({p.name:sha(p) for p in [old,dst,F/'小修差异.patch']},ensure_ascii=False,indent=2),encoding='utf-8')
(R/'review/小修答复.md').write_text(f"""# 重构稿小修答复

日期：2026-10-11。旧冻结稿08f4保留；本次冻结稿为 frozen/论文重构小修稿.md，SHA256：{sha(dst)}。局部变更见 frozen/小修差异.patch。

|意见|实际处理|位置|
|---|---|---|
|N1|删除“常用”的普遍性概括，改为“为比较速度历史模型，本文设置当前速度的等维复制输入对照。”|前言第三段|
|N2|在式5前定义w合并输入层与跳跃支路的有效参数、ϑ为其余参数，J_data为式3的数据项|1.2节式5前|
|E1|英文题名采用Optimization … based on gradient metric matching结构|英文题名|
|编辑核对|补充I为相应维数的单位矩阵、1 KiB=1024 B；英文摘要两处用语改写为factorial design和fixed set of training samples|1.3节、3.2节、英文摘要|

未修改中文题名、公式、实验设计、结果数值、图表或参考文献。未因上述编辑性小修重复训练或积分。请针对本版核查N1/N2关闭状态及是否引入新的科学主张；最终Word/PDF仍由主任务实际渲染验收。
""",encoding='utf-8')
print(sha(dst))
print(patch)
