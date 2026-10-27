$ErrorActionPreference = 'Stop'
$researchPython = 'F:\暑假原始资料\.venv-v3\Scripts\python.exe'
$researchRoot = $PSScriptRoot
foreach ($researchScript in @('analyze_external.py', 'analyze_joint_acceleration.py', 'summarize_local_sensitivity.py', 'assemble_adaptive_results.py', 'extend_manuscript_external.py', 'apply_journal_format.py', 'condense_manuscript.py', 'integrate_diagnostic.py', 'render_first_five.py', 'render_adaptive_figures.py', 'support\audit_results.py')) {
    & $researchPython -X utf8 (Join-Path $researchRoot $researchScript)
    if ($LASTEXITCODE -ne 0) { throw "Result reconstruction failed: $researchScript" }
}
Write-Output 'Saved-result reconstruction and numerical-table audit completed. No training or integration was run.'
