from pathlib import Path
import hashlib, json, shutil, difflib
R=Path(__file__).resolve().parent
F=R/'review/frozen'
src=R/'delivery/论文重构修订稿.md';dest=F/'论文重构终核稿.md'
assert not dest.exists()
shutil.copy2(src,dest)
prev=F/'论文重构小修稿.md'
diff=''.join(difflib.unified_diff(prev.read_text(encoding='utf-8').splitlines(True),src.read_text(encoding='utf-8').splitlines(True),fromfile='305403小修稿',tofile='终核稿'))
(F/'终核差异.patch').write_text(diff,encoding='utf-8')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(F/'final_hashes.json').write_text(json.dumps({p.name:sha(p) for p in [prev,dest,F/'终核差异.patch']},ensure_ascii=False,indent=2),encoding='utf-8')
(R/'review/终核答复.md').write_text(f"""# 最终增量核查答复

终核稿SHA256：{sha(dest)}。

相较305403小修稿，仅将NRMSE的英文全称及缩写定义移至2.3节首次使用处，2.4节重复定义改为已定义缩写。完整差分存于frozen/终核差异.patch。其余科学内容、公式、图表、书目及结果均不变。PaperPolice原始七项提示逐项裁定，保留原始记录及人工理由；未新增训练或积分。
""",encoding='utf-8')
print(sha(dest));print(diff)
