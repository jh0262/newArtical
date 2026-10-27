$ErrorActionPreference = 'Stop'
$researchPython = 'F:\暑假原始资料\.venv-v3\Scripts\python.exe'
$reviewRoot = $PSScriptRoot
foreach ($scriptName in @('analyze_integration.py','render_revision_figures.py','audit_results.py')) {
    & $researchPython -X utf8 (Join-Path $reviewRoot ('support\' + $scriptName))
    if ($LASTEXITCODE -ne 0) { throw ('Result reproduction failed at ' + $scriptName) }
}
Write-Output 'Saved-result tables and figures rebuilt and checked. No training or integration was run.'
