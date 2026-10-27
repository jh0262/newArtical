"""Complete archival scope notices without running or changing experiments."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
record_path = root / 'SCOPE_CORRECTION_MANIFEST.json'
record = json.loads(record_path.read_text('utf-8'))
backup = root / 'qa/scope_correction'
report = root.parent / '论文修订_20261015/评审范围纠正与原稿修订依据.md'
notice = ('> **范围纠正（2026-10-15）：** 本文件仅记录独立重实现的PADE-FE v4及其固定协议，'
          '不替代作者原始PADE–DE及文献比较结果，也不据此重判原论文的创新性或发表潜力。'
          '其中将v4用于替换v3、迁出原结果表或下调原稿评价的计划与推论已撤回。'
          '当前以保留原实验的v3为文字修订底稿，详见[纠正报告](' + report.as_posix() + ')。\n\n')
changes = []
for relative in ['package/必改项落实与更新评审.md', 'analysis/V4修订映射.md', 'analysis/V4方法与设置替换稿.md']:
    path = root / relative
    old = path.read_bytes()
    saved = backup / relative.replace('/', '__')
    if not saved.exists():
        saved.write_bytes(old)
    content = old.decode('utf-8')
    content = content.replace('相较上一轮“中等创新、大修后投稿”的判断，当前这一投稿主张的证据应下调，而不是继续用对经典DE的优势掩盖父对照结果。',
                              '该分析只适用于独立v4分支；撤回据此下调原始PADE论文评价的推论。')
    path.write_text(notice + content, encoding='utf-8')
    changes.append({'path': relative, 'before_sha256': hashlib.sha256(old).hexdigest(),
                    'after_sha256': digest(path), 'backup': saved.relative_to(root).as_posix()})

sidecar = root / 'manuscript/版本适用范围说明.md'
sidecar.write_text('# 此目录为独立v4实验稿归档\n\n' + notice +
                   '本目录既有Word、PDF及其生成源保留为历史记录；不作为原始PADE论文的当前修订稿。'
                   '其数值仅属于该重实现版本及实验条件。本次未改写历史Word或PDF，未运行生成脚本。\n', encoding='utf-8')

delivery_path = root / 'DELIVERY_MANIFEST.json'
delivery = json.loads(delivery_path.read_text('utf-8'))
for entry in delivery['files']:
    if any(change['path'] == entry['path'] for change in changes):
        path = root / entry['path']
        entry.update(bytes=path.stat().st_size, sha256=digest(path))
delivery_path.write_text(json.dumps(delivery, ensure_ascii=False, indent=2), encoding='utf-8')
for entry in record['changed_metadata']:
    if entry['path'] == 'DELIVERY_MANIFEST.json':
        entry['after_sha256'] = digest(delivery_path)
record['changed_metadata'].extend(changes)
record['archival_scope_sidecar'] = {'path': sidecar.relative_to(root).as_posix(), 'sha256': digest(sidecar)}
assert all(digest(Path(entry['path'])) == entry['sha256'] for entry in record['original_inputs'])
assert digest(Path(record['primary_manuscript'])) == record['primary_sha256']
record_path.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'additional_scope_notices': len(changes), 'original_files_and_v3_unchanged': True,
                  'optimization_runs_started': 0}, ensure_ascii=False))
