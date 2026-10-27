from pathlib import Path
import hashlib,json,shutil,difflib
R=Path(__file__).resolve().parent;O=R.parent/'jme_review_20260930_round5';F=R/'review/frozen';F.mkdir(exist_ok=True,parents=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
src=R/'delivery/论文重构修订稿.md';dest=F/'论文重构送审稿.md'
assert not dest.exists(),'Keep first submitted version frozen'
shutil.copy2(src,dest)
before=(O/'delivery/论文第五轮修订稿.md').read_text(encoding='utf-8').splitlines(True);after=src.read_text(encoding='utf-8').splitlines(True)
(F/'正文差异.patch').write_text(''.join(difflib.unified_diff(before,after,fromfile='第五轮原稿',tofile='新题名重构稿')),encoding='utf-8')
paths=[src,dest,R/'修订说明与证据对应.md',R/'研究主线与实验协议.md',R/'run_metric_experiment.py',R/'analysis/independent_audit.json',R/'metric_experiment/completion.json']
(F/'hashes.json').write_text(json.dumps({str(p):sha(p) for p in paths},ensure_ascii=False,indent=2),encoding='utf-8')
print(sha(dest))
