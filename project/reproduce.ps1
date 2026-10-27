param([switch]$Full)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $projectRoot

python -m unittest discover -s '05_experiments' -p 'test_*.py' -v
foreach ($resultDir in @(
  'main_30x800_v3_physics',
  'budget_30x400_v3_physics',
  'budget_30x1600_v3_physics',
  'ablation_30x800_v3_physics'
)) {
  python '05_experiments/reanalyze_results.py' $resultDir | Out-Null
}
python '05_experiments/run_sensitivity.py'

$bundledPython = 'C:\Users\hp\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if (Test-Path -LiteralPath $bundledPython) {
  & $bundledPython '07_figures/make_figures.py'
  & $bundledPython '08_manuscript/build_manuscript.py'
  $manuscriptDocx = Join-Path $projectRoot '08_manuscript\BallScrew_SolverHierarchy_anonymized.docx'
  if (Get-Command officecli -ErrorAction SilentlyContinue) {
    officecli open $manuscriptDocx | Out-Null
    officecli set $manuscriptDocx / --prop recalcFields=seq | Out-Null
    officecli set $manuscriptDocx / --prop author='Anonymous' --prop lastModifiedBy='OfficeCLI' --prop title='Problem structure governs solver choice in catalogue-constrained ball-screw multiobjective design' --prop subject='Anonymized structure-conditioned solver-eligibility study, revision v2.1' --prop keywords='ball screw; solver eligibility; analytical enumeration; mixed-variable optimization; differential evolution; catalogue design' --prop description='Scientific-question-focused revision based only on completed analytical and computational experiments; no physical validation claimed' | Out-Null
    officecli set $manuscriptDocx /settings --prop updateFields=true --prop removePersonalInformation=true --prop removeDateAndTime=true | Out-Null
    $referenceParagraphs = officecli query $manuscriptDocx 'paragraph[style=Reference]' --json | ConvertFrom-Json
    foreach ($entry in $referenceParagraphs.data.results) {
      officecli set $manuscriptDocx $entry.path --prop indent=0.65cm --prop hangingIndent=0.65cm | Out-Null
    }
    $equations = (officecli query $manuscriptDocx 'equation' --json | ConvertFrom-Json).data.results
    $formulas = @(
      'x = (m, t_a, v), m \in \{1,\ldots,19\}, 0.08 \leq t_a \leq 0.30 s, 0.25 \leq v \leq 1.20 m s^{-1}',
      't_c = 2(s/v + t_a) + 2t_d',
      'F = M_t(g + a_s)',
      'T = \frac{F P_h}{2\pi\eta} + J_s \frac{2\pi}{P_h} a_s',
      'P_m = [\frac{\sum_k P_k^3 n_k t_k}{\sum_k n_k t_k}]^{1/3}',
      'L_h = \frac{10^6}{60 n_m}[\frac{C_a}{f_w P_m}]^3',
      '\frac{1}{K_{tot}} = \frac{1}{K_n} + \frac{1}{K_s} + \frac{1}{K_b}, K_s = \frac{E\pi d_c^2}{4L_s}',
      '\delta = \frac{F_{max}}{K_{tot}}',
      'P_{cr} = \frac{\pi^2 E I}{(K_e L_s)^2}, n_{cr} = \frac{60}{2\pi}(\beta L)^2\sqrt{\frac{E I}{\rho_A L_s^4}}',
      '\min f(x) = [m_n + \rho_L L_s, \delta]',
      'z_i = norm[d, P_h, C_a, C_{0a}, K_n, m_n, \rho_L, n_{max}]',
      'z^* = z_{r1} + F(z_{r2} - z_{r3}), m^* = argmin_j ||z_j - z^*||_2',
      'p_N = 0.20 + 0.65(1-r_f)',
      'v = \frac{s}{A-t_a}, a = \frac{s}{t_a(A-t_a)}',
      't_{a,i}^* = min[t_{a,max}, A-s/v_{lim,i}], v_i^* = \frac{s}{A-t_{a,i}^*}'
    )
    if ($equations.Count -ne $formulas.Count) {
      throw "Equation count mismatch: $($equations.Count) document equations vs $($formulas.Count) frozen formulas."
    }
    for ($i = 0; $i -lt $equations.Count; $i++) {
      officecli set $manuscriptDocx $equations[$i].path --prop mode=inline --prop "formula=$($formulas[$i])" | Out-Null
    }
    officecli save $manuscriptDocx | Out-Null
    officecli close $manuscriptDocx | Out-Null
    officecli validate $manuscriptDocx
  } else {
    Write-Warning 'OfficeCLI not found; DOCX was rebuilt but field/reference post-processing was not applied.'
  }
} else {
  Write-Warning 'Bundled document Python not found; numerical reproduction passed but figures/DOCX were not rebuilt.'
}

if ($Full) {
  Write-Warning 'Full stochastic reruns are intentionally not launched by this script. Use the frozen commands in refine-logs/EXPERIMENT_PLAN.md after confirming compute scope.'
}
