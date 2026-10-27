param(
    [string]$ResearchPython = 'F:\暑假原始资料\.venv-v3\Scripts\python.exe',
    [string]$OfficePython = 'C:\Users\hp\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe',
    [switch]$RenderPdf
)
$ErrorActionPreference = 'Stop'
$researchRoot = $PSScriptRoot
$resultLogs = Join-Path $researchRoot 'reproduction_logs'
New-Item -ItemType Directory -Force -Path $resultLogs | Out-Null
foreach ($runtime in @($ResearchPython,$OfficePython)) {
    if (-not (Test-Path -LiteralPath $runtime -PathType Leaf)) { throw "Missing Python: $runtime" }
}
$stages = [System.Collections.Generic.List[object]]::new()
function Invoke-ResearchStage([string]$Label,[string]$Runtime,[string]$Script,[string[]]$ExtraArgs=@()) {
    $fullScript = Join-Path $researchRoot $Script
    $logFile = Join-Path $resultLogs ($Label+'.log')
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    & $Runtime -X utf8 $fullScript @ExtraArgs *> $logFile
    $stageCode=$LASTEXITCODE
    $timer.Stop()
    $stages.Add([ordered]@{stage=$Label;exit_code=$stageCode;seconds=$timer.Elapsed.TotalSeconds;log=$logFile})
    if ($stageCode -ne 0) { throw "Stage failed: $Label; see $logFile" }
    Write-Output "$Label : passed"
}
# Recompute saved evidence. No optimizer updates and no dynamics integration.
Invoke-ResearchStage '01_saved_result_audit' $ResearchPython 'analyze_metric_experiment.py'
Invoke-ResearchStage '02_manuscript' $ResearchPython 'build_manuscript.py'
Invoke-ResearchStage '03_metric_figure' $ResearchPython 'render_metric_figure.py'
Invoke-ResearchStage '04_document_tools' $ResearchPython 'prepare_document_tools.py'
Invoke-ResearchStage '05_editable_docx' $OfficePython 'delivery/build_docx.py'
Invoke-ResearchStage '06_docx_structure' $OfficePython 'support/check_docx.py'
Invoke-ResearchStage '07_references' $ResearchPython 'support/build_reference_inheritance.py'
$manuscript = Join-Path $researchRoot 'delivery/论文重构修订稿.md'
Invoke-ResearchStage '08_paperpolice_raw' $ResearchPython 'support/police_audit.py' @('final_check',$manuscript)
Invoke-ResearchStage '09_paperpolice_adjudication' $ResearchPython 'support/finalize_police.py'
$acceptedText=Join-Path $researchRoot 'review/frozen/论文重构终核稿.md'
if ((Get-FileHash -LiteralPath $manuscript -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $acceptedText -Algorithm SHA256).Hash) {
    throw 'Regenerated manuscript differs from the frozen review version'
}
if ($RenderPdf) {
    $title='基于梯度度量匹配的重载机器人速度历史补偿模型优化'
    $docx=Join-Path $researchRoot ('delivery/'+$title+'.docx')
    $pdf=Join-Path $researchRoot 'delivery/render_qa/manuscript.pdf'
    $preHash=(Get-FileHash -LiteralPath $docx -Algorithm SHA256).Hash
    $renderer=Join-Path (Split-Path $researchRoot -Parent) 'manuscript_step5/render_word.ps1'
    & $renderer -DocumentPath $docx -PdfPath $pdf
    if ((Get-FileHash -LiteralPath $docx -Algorithm SHA256).Hash -ne $preHash) { throw 'Word export changed source DOCX' }
    Invoke-ResearchStage '10_pdf_pages' $OfficePython 'support/render_pdf_pages.py'
    Copy-Item -LiteralPath $pdf -Destination (Join-Path $researchRoot ('delivery/'+$title+'.pdf'))
}
[ordered]@{
    completed_utc=[DateTime]::UtcNow.ToString('o')
    scope='saved-result recomputation and artifact rebuild; no training or integration'
    native_pdf_export=[bool]$RenderPdf
    manuscript_sha256=(Get-FileHash -LiteralPath $manuscript -Algorithm SHA256).Hash.ToLower()
    stages=$stages.ToArray()
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $resultLogs 'last_run.json') -Encoding utf8
Write-Output 'Saved-result reproduction completed. Visual inspection and final delivery manifest are separate.'
