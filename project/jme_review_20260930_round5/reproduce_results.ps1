param([switch]$BuildWord)
$ErrorActionPreference = 'Stop'
$researchPython = 'F:\暑假原始资料\.venv-v3\Scripts\python.exe'
$documentPython = 'C:\Users\hp\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$taskRoot = $PSScriptRoot
foreach ($name in @('check_active_evaluation.py','summarize_results.py','build_manuscript.py','render_figures.py','prepare_builder.py','prepare_audit_tools.py')) {
    if ($name -eq 'check_active_evaluation.py') { & $researchPython -X utf8 (Join-Path $taskRoot $name) --stage before_reproduction }
    elseif ($name -eq 'render_figures.py') { & $documentPython -X utf8 (Join-Path $taskRoot $name) }
    else { & $researchPython -X utf8 (Join-Path $taskRoot $name) }
    if ($LASTEXITCODE -ne 0) { throw "Result reconstruction failed: $name" }
}
if ($BuildWord) {
    & $documentPython -X utf8 (Join-Path $taskRoot 'delivery\build_docx.py')
    if ($LASTEXITCODE -ne 0) { throw 'Word generation failed' }
    & $documentPython -X utf8 (Join-Path $taskRoot 'support\check_docx.py')
    if ($LASTEXITCODE -ne 0) { throw 'Word structure check failed' }
}
Write-Output 'Saved-result reconstruction complete. No training or integration was repeated. Native rendering and scientific review are separate checks.'
