param([switch]$Retrain)
$ErrorActionPreference='Stop'
$revisionRoot=$PSScriptRoot
$studyRoot=Split-Path -Parent $revisionRoot
$workspaceRoot=Split-Path -Parent (Split-Path -Parent $studyRoot)
$computePython=Join-Path $workspaceRoot '.venv-v3\Scripts\python.exe'
if (!(Test-Path -LiteralPath $computePython)) { throw 'Missing recorded compute environment. See README.md.' }
if ($Retrain) {
    $replayRoot=Join-Path $studyRoot ('revision_v2_replay_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
    if (Test-Path -LiteralPath $replayRoot) { throw 'Refusing to overwrite existing replay directory.' }
    New-Item -ItemType Directory -Path $replayRoot | Out-Null
    foreach ($file in @('run_revision.py','diagnose_dependence.py','refine_further.py','render_figures.py','补充实验协议.md','数值核验追加说明.md')) {
        Copy-Item -LiteralPath (Join-Path $revisionRoot $file) -Destination (Join-Path $replayRoot $file)
    }
    & $computePython -X utf8 (Join-Path $replayRoot 'run_revision.py')
    if ($LASTEXITCODE -ne 0) { throw 'Candidate training or evaluation failed; preserve logs and outputs.' }
    & $computePython -X utf8 (Join-Path $replayRoot 'diagnose_dependence.py')
    if ($LASTEXITCODE -ne 0) { throw 'Dependence diagnostics failed.' }
    & $computePython -X utf8 (Join-Path $replayRoot 'refine_further.py')
    if ($LASTEXITCODE -ne 0) { throw 'Integration refinement failed.' }
    & $computePython -X utf8 (Join-Path $replayRoot 'render_figures.py')
    if ($LASTEXITCODE -ne 0) { throw 'Plot generation failed.' }
    Write-Output ('New training and results retained at '+$replayRoot)
} else {
    & $computePython -X utf8 (Join-Path $revisionRoot 'run_revision.py') --stage summarize
    if ($LASTEXITCODE -ne 0) { throw 'Metric reconstruction failed.' }
    & $computePython -X utf8 (Join-Path $revisionRoot 'render_figures.py')
    if ($LASTEXITCODE -ne 0) { throw 'Plot reconstruction failed.' }
    Write-Output 'Rebuilt CSV summaries and figures from retained predictions; no fitting or integration.'
}
