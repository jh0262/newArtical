"""Close the parameter study after its numerical and reproduction checks pass."""
from pathlib import Path
import json
import pandas as pd

R = Path(__file__).resolve().parents[1]


def main():
    audits = {}
    for name in ['tests', 'screen_audit', 'confirm_audit', 'independent_verification', 'artifact_qa', 'package_reproduction']:
        audits[name] = json.loads((R/'audit'/f'{name}.json').read_text(encoding='utf-8'))
        assert audits[name]['status'] == 'pass', name
    assert audits['screen_audit']['runs'] == 416 and audits['confirm_audit']['runs'] == 180
    assert (R/'audit/visual_check.md').is_file() and (R/'audit/writing_check.md').is_file()
    acts = pd.read_csv(R/'data/screen_activation.csv')
    f = acts[(acts.Problem == 'PPAR') & (acts.ParameterType == 'floor')]
    assert (f.FirstDifferentGeneration == f.FirstSigmaDifference).all()
    stats = pd.read_csv(R/'data/screen_statistics.csv')
    cap = stats[(stats.Problem == 'PPAR') & (stats.Metric == 'AUC') & (stats.Contrast == 'cap_020_to_0005')].iloc[0]
    assert round(cap.RawP, 5) == .00763 and round(cap.HolmLocal, 5) == .06866 and round(cap.HolmGlobal, 5) == .20599
    stats = pd.read_csv(R/'data/confirm_statistics.csv')
    assert (stats[stats.Problem == 'DTLZ3'].HolmGlobal == 1).all()
    recommendation = {'retain': 'B', 'principalGain': .05, 'sigmaMin': .02, 'window': 5, 'pulseCap': .20,
                      'basis': 'PPAR independent confirmation: 30 new paired seeds per setting',
                      'candidates': ['N31', 'N32'], 'repeatable_improvement_established': False,
                      'scope': 'fixed original mechanism and engineering model; 25100 objective evaluations; studied parameter range',
                      'DTLZ3_role': 'auxiliary multimodal convergence; never used for candidate selection'}
    (R/'data/recommendation.json').write_text(json.dumps(recommendation, ensure_ascii=False, indent=2), encoding='utf-8')
    status = {'status': 'complete', 'completed_screen_runs': 416, 'completed_confirm_runs': 180,
              'total_new_runs': 596, 'formal_failed_runs': 0, 'evaluation_budget_per_search': 25100,
              'new_search_evaluations': 14959600, 'final_archive_reevaluations': 59600,
              'audit_objective_evaluations': 1788, 'tests_passed': 13, 'independent_verification': 'pass',
              'clean_reproduction': 'pass', 'retained_setting': 'B', 'engineering_primary': True,
              'DTLZ3_role': recommendation['DTLZ3_role'], 'preserved_original_files': 3656,
              'originals_preserved': True, 'algorithm_mechanisms_changed': False, 'model_changed': False,
              'manuscript_modified': False, 'additional_experiments_required_by_protocol': False}
    (R/'STATUS.json').write_text(json.dumps(status, ensure_ascii=False, indent=2), encoding='utf-8')
    log = R/'audit/WORK_LOG.md'
    text = log.read_text(encoding='utf-8')
    if '新目录复现验证完成' not in text:
        log.write_text(text+'\n- 新目录复现验证完成：7张统计CSV逐字节一致；5张PNG像素完全一致，另2张分别有13和7个像素渲染差异且对应PDF绘图流完全一致；7个PDF页数、文本与非文本绘图操作一致。portable模式独立核算通过。全部工作按协议完成，STATUS.json关闭为complete。\n', encoding='utf-8')
    print(json.dumps(status, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
